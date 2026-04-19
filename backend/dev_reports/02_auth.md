# Phase 1 — Authentication (email + social scaffold)

Phase 1 covers the full mandatory authentication surface defined in the 42 Music Room
subject (V.4, V.5, V.6): email+password registration with verification, email-based
password reset, access/refresh token pair with rotation, rate-limited auth endpoints,
device context on every session, and a mailer capturing all transactional messages in
dev. The social-login contract is wired end-to-end (DTO, provider routing,
persistence) with a stub token verifier that Phase 2 will swap for real Google and
Facebook flows.

## 1. Scope

| Sujet                                                                 | Where                                                                                 |
|-----------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| V.4 sign up (email + password)                                        | `AuthController.register` → `AuthService.register`                                    |
| V.4 email verification                                                | `EmailVerification` table + `MailService.sendVerificationEmail`                       |
| V.4 password reset                                                    | `PasswordReset` table + `MailService.sendPasswordResetEmail`                          |
| V.4 sign in with email                                                | `AuthController.login` → `AuthService.login`                                          |
| V.4 social sign in (Google, Facebook)                                 | `AuthController.socialLogin` → `AuthService.socialLogin` (provider verifier stubbed)  |
| V.4 link social to existing account                                   | `AuthController.linkSocial` → `AuthService.linkSocial`                                |
| V.5 collect user info (display name, avatar, music prefs, visibility) | `User` model fields, surfaced via DTOs, hydrated at `register` + `socialLogin`        |
| V.6 platform / device / version on every request                      | `RequestLoggerMiddleware` + `DeviceContext` persisted on every `RefreshToken`         |

## 2. Data model (Prisma)

Three dedicated tables replaced the ad-hoc columns that previously lived on `User`:

- **`RefreshToken`** — one row per issued refresh JWT. Stores `tokenHash` (SHA-256 of
  the raw JWT, never the JWT itself), `deviceId`, `userAgent`, `ip`, `expiresAt`,
  `revokedAt`, `replacedBy`. Unique on `tokenHash`; indexed on `userId` and
  `expiresAt` for cheap cleanup. The `replacedBy` pointer turns the set of refreshes
  issued to a user into a linked list (a token "family"), which is what makes theft
  detection tractable (§5).
- **`EmailVerification`** — one row per verification link. `tokenHash` SHA-256,
  `expiresAt = now + 24h`, `consumedAt` nullable. A single token is valid only if
  unused and non-expired; redemption sets `consumedAt` and flips `user.emailVerified`
  in the same transaction.
- **`PasswordReset`** — same shape, `expiresAt = now + 1h`. Redemption rewrites
  `passwordHash`, marks `consumedAt`, and immediately revokes every active refresh
  token for the user (every existing session is invalidated).

Migration: `20260418132305_phase1_auth_tables`. No data loss (no rows existed).

The old `User.emailVerifyToken`, `resetPasswordToken`, `resetPasswordExpires` columns
were dropped. Reason: storing a bare token on the owning entity makes revocation and
rotation impossible (one token slot per user), forbids tracking usage, and leaks the
secret on every `SELECT * FROM users`. The dedicated tables store only the hash, so
a DB leak cannot be replayed as a password reset.

## 3. Token security

Access tokens: JWT signed with `JWT_SECRET`, 15-minute TTL (`JWT_EXPIRES_IN_SECONDS`,
default 900). Stateless — validated by `JwtStrategy` + Redis blacklist check.

Refresh tokens: JWT signed with `JWT_REFRESH_SECRET`, 7-day TTL
(`JWT_REFRESH_EXPIRES_IN_SECONDS`, default 604800). The raw JWT is sent to the client
once; the DB only keeps `sha256(jwt)`. Every refresh mints a new pair AND marks the
old `RefreshToken` row as `revokedAt = now, replacedBy = <new id>`.

Passwords: bcrypt cost 12. The cost is a deliberate balance — cheap enough that a
laptop handles ~10 logins/s, expensive enough that a leaked `passwordHash` takes
years to brute-force offline.

Email-verification / password-reset tokens: 32 random bytes
(`crypto.randomBytes(32).toString('hex')`), SHA-256 before storage. URLs are built
against `APP_FRONTEND_URL`, so the mobile app owns the UX and the backend only
validates the token.

## 4. Refresh rotation

`AuthService.refresh(rawToken, deviceContext)`:

1. Verify JWT signature and expiry (rejects forged / expired tokens outright).
2. Look up `RefreshToken` by `tokenHash`. If missing → 401 (token never issued or
   already garbage-collected).
3. If the row is already revoked → 401 **and** revoke the entire family (§5).
4. If expired by `expiresAt` → 401.
5. Issue a new `(access, refresh)` pair, insert the new `RefreshToken` row, update
   the old row (`revokedAt = now`, `replacedBy = newId`).
6. Return the new pair.

Every step runs inside the AuthService transactional helpers so a crash between
"issue new" and "revoke old" cannot leave two live refreshes on the same chain.

## 5. Refresh token theft detection

Reuse of a revoked refresh token is the canonical stolen-token signal: the rightful
client has already rotated it, so anyone else using it is an attacker. On detection,
`AuthService.refresh` calls `prisma.refreshToken.updateMany({ where: { userId,
revokedAt: null }, data: { revokedAt: now } })` — every active session for that user
is killed. The attacker and the victim both have to re-authenticate with a primary
credential (password or social login), which the attacker does not have.

This is tested in `auth.service.spec.ts` and end-to-end in
`test/e2e/auth.e2e-spec.ts` ("should detect refresh token reuse and revoke all
sessions").

## 6. Password reset invalidates sessions

When `AuthService.resetPassword` succeeds, it revokes every live refresh token for
the user. Rationale: the most common reason users reset a password is that they
suspect account compromise. If we kept sessions alive, a reset would be decorative —
the attacker's refresh token would still work.

## 7. Anti-enumeration on `/auth/forgot-password`

`forgotPassword` returns 200 with the same message whether or not the email exists:
`"If an account with that email exists, a reset link has been sent"`. No timing
difference is introduced; the DB is still queried so the path takes approximately
the same time in both cases. This blocks attackers from harvesting valid emails via
differential responses.

## 8. Device context (V.6)

`AuthController.deviceContext(req)` extracts `x-device`, `user-agent`, and
`x-forwarded-for` (falling back to `req.ip`) and forwards them to every
`AuthService` entry point that creates a refresh token (`register`, `login`,
`socialLogin`, `refresh`). The resulting `DeviceContext` is persisted on the
`RefreshToken` row. Combined with `RequestLoggerMiddleware` (which reads
`x-platform`, `x-device`, `x-app-version`, `user-agent` on every request), this gives
us the "platform / device / version" trail required by V.6 both in structured logs
(Pino) and in queryable database state (refresh token rows). The subject asks for
detection of abnormal access; having device + IP on every session gives us the raw
material.

## 9. Rate limiting

Two named throttler buckets (`app.module.ts`):

- `default` — 100 req / minute for the rest of the API
- `auth` — 10 req / minute for every `/auth/*` route

`AuthController` is decorated with `@SkipThrottle({ default: true })` and
`@Throttle({ auth: {} })` so bursts against `/auth/login` do not count toward the
global bucket, and global traffic cannot push auth over its dedicated limit. Values
come from `AUTH_THROTTLE_TTL` / `AUTH_THROTTLE_LIMIT` in `.env`, validated by the
Joi schema.

## 10. Mail pipeline

`MailService` wraps a nodemailer SMTP transport and is used only from the auth
flow. In dev, SMTP points at Mailpit (`localhost:1025`); the UI at
`http://localhost:8025` captures every verification and reset email sent by the API,
which is how the e2e tests verify content (they grep the spy calls, not the SMTP
server, but the developer verifies visually).

Switching from MailHog to Mailpit was forced by arm64 compatibility: MailHog is
amd64-only and QEMU-emulated on Apple Silicon, which made CI and local dev unstable.
Mailpit is multi-arch and API-compatible.

In production, the same service points at the real SMTP (configured via
`SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_SECURE`). No code changes — only
env.

## 11. Logout

`AuthController.logout` blacklists the current access JWT in Redis (TTL = remaining
lifetime of the JWT, so the key self-expires) and revokes the supplied refresh
token row in Postgres. Next request from the same access token is rejected by
`JwtAuthGuard`, and no refresh can mint a new pair from the revoked refresh.

Blacklist storage is Redis because an access-token blacklist is inherently
high-cardinality, low-TTL state — Postgres would be the wrong tool (write
amplification, vacuum pressure). Redis' native TTL on keys removes the need for a
cleanup job.

## 12. Tests

```
Unit:  15 files, 115 tests, 99.76% stmts, 98.06% branches
E2E :   2 files,  19 tests (health + auth)
Total: 134 tests, all green
```

Spec coverage highlights:

- `auth.service.spec.ts` — 37 tests: register/login happy paths, email + social
  linking, verification expiry/consumption, password reset expiry/consumption,
  refresh rotation, refresh reuse → family revocation, password reset → session
  revocation, logout blacklist+DB revoke, `verifySocialToken` Google + Facebook
  HTTP shapes.
- `auth.controller.spec.ts` — 12 tests: every route, device-context array-header
  branches, missing-authorization logout fallback.
- `auth.e2e-spec.ts` — 17 tests: full Fastify app booted with in-memory Prisma mock
  and SMTP spy, including the two attack scenarios (refresh-token reuse,
  password-reset-then-old-password) and the anti-enumeration response on
  `/forgot-password`.
- `mail.service.spec.ts` — 7 tests against a mocked `nodemailer.createTransport`.
- `env.validation.spec.ts` — 8 tests: required vars, defaults, NODE_ENV enum,
  APP_BASE_URL URI shape, string coercion of numeric env vars, empty social
  credentials accepted.

The three remaining branch gaps (`redis.service.ts` lines 28-29,
`mail.service.ts` line 32, `request-logger.middleware.ts` line 52) are
error-path defensive code; they will be covered by the integration tests added in
Phase 4 (hardening).

## 13. Soutenance defense points

- **Why SHA-256 hashes for reset/verification tokens, not bcrypt?** These tokens
  live 1–24h, carry no reuse risk (one-shot, `consumedAt`), and must be looked up by
  equality. SHA-256 is 20 000× faster than bcrypt per verify (matters under
  brute-force of random 32-byte tokens, which is infeasible anyway), and the
  lookup-by-hash index works on deterministic output. Bcrypt would force a full
  table scan.
- **Why revoke every refresh on password reset / refresh reuse?** Those are the two
  strongest compromise signals the backend has. Keeping live sessions after either
  event defeats the point of the action. The cost to the user (re-login on N
  devices) is acceptable; the cost to an attacker (needs a primary credential
  again) is total.
- **Why a Postgres `RefreshToken` table instead of Redis?** Refresh tokens are
  long-lived (days) and must survive restarts. Redis is configured for caching,
  not durable state. The `RefreshToken` table also gives us auditability (join on
  `userId` for "list my sessions" in Phase 2) and makes the family-revocation
  query a single `updateMany`.
- **Why 100 req/min global + 10 req/min on /auth?** The 42 subject requires
  resistance to brute-force (V.4, V.7). 10/min on `/auth/login` bounds password
  guessing to 14 400/day per IP — against bcrypt cost 12, that is effectively
  zero. The 100/min default on the rest keeps the API usable for real clients.

## 14. Phase exit

- [x] Schema + migration applied
- [x] Registration → verification email → verify endpoint end-to-end green
- [x] Login returns token pair with device context stored
- [x] Social login path compiles, DTO validated, provider verifier stubbed
- [x] Refresh rotates and revokes family on reuse
- [x] Password reset invalidates sessions
- [x] `/auth/*` on dedicated throttler bucket
- [x] Mailpit receiving all transactional mail in dev
- [x] 134/134 tests green, 99.76% stmts / 98.06% branches

Phase 2 picks up the real Google and Facebook verifiers (passport strategies +
undici-backed provider probes) and adds the `/users/me` + session-listing endpoints
that make the `RefreshToken` table user-visible.
