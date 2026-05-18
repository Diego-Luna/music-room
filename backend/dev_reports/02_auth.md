# Phase 2 — Authentication

## Scope

Cover **V.1 User** of the subject end-to-end on the backend:
mail/password registration, email validation, password reset, social
login (Google + Facebook), link social to an existing account, JWT
issuance with refresh rotation, logout/revocation, session listing.

## Architecture

```
POST /auth/register ─┬─▶  AuthService.register
POST /auth/login    ─┤        ├─ bcrypt verify
POST /auth/social   ─┤        ├─ Passport strategy (`local`, `google`, `facebook`)
POST /auth/link-social ─┤     └─ issue { accessToken, refreshToken }
                       │
POST /auth/refresh   ──┤  AuthService.refresh
POST /auth/logout    ──┤        └─ JwtBlacklistService.revoke (Redis SET with TTL)
                       │
POST /auth/forgot-password ─┤  AuthService.forgotPassword → MailService
POST /auth/reset-password  ─┤  AuthService.resetPassword (consume token + bcrypt update)
POST /auth/verify-email     ─┘  AuthService.verifyEmail (consume token)

GET /auth/sessions        ──▶  AuthService.listSessions (RefreshToken rows for user)
DELETE /auth/sessions/:id ──▶  AuthService.revokeSession
```

## Key design choices

### Password hashing

`bcrypt` with cost **12**. Hard-coded in `auth.service.ts` (not
configurable) so the cost can't be lowered by accident in
prod. Cost 12 is the modern OWASP recommendation as of 2024–2026 and
is the lowest cost that takes >250 ms on modern hardware.

### JWT structure

Two tokens issued on every successful auth:
- **Access token** — 15 min TTL (`JWT_EXPIRES_IN_SECONDS=900`),
  signed with `JWT_SECRET`. Sent on every request as
  `Authorization: Bearer …`.
- **Refresh token** — 7 day TTL (`JWT_REFRESH_EXPIRES_IN_SECONDS=604800`),
  signed with a **different secret** `JWT_REFRESH_SECRET`. The hash
  is stored server-side (`RefreshToken` table) so we can list and
  revoke.

The dual-secret design means that if one secret leaks
(e.g. front-end bundle accidentally embeds the access secret),
the refresh path is still safe.

### Refresh rotation

Every `POST /auth/refresh` consumes the old refresh token and emits
a new pair. The old `RefreshToken` row is marked `revokedAt` and the
new one's `replacedBy` column points back — gives us a clear audit
trail and protects against replay (a stolen refresh token works once,
then both client and attacker race for the next rotation).

### JWT blacklist (Redis)

`JwtBlacklistService` writes to Redis with `SET <jti> 1 EX
<remainingSeconds>`. The TTL matches the token's natural expiry, so
the blacklist self-cleans without a cron. The JWT strategy queries
`EXISTS <jti>` on every authenticated request — sub-millisecond.

Triggers for blacklisting:
- Explicit logout (the access token's jti is blacklisted)
- Password change / reset (all of the user's tokens are revoked
  server-side via the `RefreshToken` table; the access tokens can
  also be blacklisted)

### Social login (Google + Facebook)

Implemented via Passport custom strategies. The mobile client
performs the OAuth dance itself (because the subject explicitly
points to `developers.facebook.com` / `developers.google.com`) and
hands us the **provider access token**. The backend verifies that
token by calling the provider's `/me`-like endpoint, then:
- If a `SocialAccount` row exists for `(provider, providerId)` →
  log the user in
- Else → look up by email; if found, link; else create a new user

`POST /auth/link-social` is the explicit version for an already
authenticated user who wants to add Google or Facebook to their
existing account.

### Email verification & password reset

Both use the same pattern: generate a 32-byte random token, hash it
with sha256, store the hash in `EmailVerification` / `PasswordReset`
with a 24-hour expiry, send the **raw** token to the user's mailbox.
On consume: hash the incoming token, find the row, check
`consumedAt is null` and `expiresAt > now`, mark consumed, apply
the side-effect (set `emailVerified = true` or update password hash).

Storing only the hash means a DB leak does not let an attacker
impersonate verification tokens.

In dev, mails are captured by **Mailpit** (`docker-compose.yml`),
viewable at http://localhost:8025.

## Mandatory log headers (V.6)

The `RequestLoggerMiddleware` (Phase 5) captures `X-Platform`,
`X-Device`, `X-App-Version` on every request, **including** the
`/auth/*` routes. So every register/login/refresh action is logged
with platform context as the subject demands.

## Soutenance defense points

- *Why bcrypt cost 12 and not 10 or 14?* — 10 is too low against
  modern GPU attacks; 14 takes ~1 second on our hardware which
  would block the auth path under load. 12 is the OWASP sweet spot.
- *Why two JWT secrets?* — Defense in depth. A leak of the access
  secret (small surface, lots of places it travels) doesn't break
  the refresh flow.
- *Why refresh rotation?* — Lets us revoke a stolen refresh token
  the moment its rightful owner refreshes again (the rotation
  detects double-use). Industry standard since OAuth 2.0 best
  practices.
- *Why Redis blacklist instead of just deleting the access token
  in DB?* — Access tokens are JWTs, by design self-contained — there
  is no DB row to delete. Redis is the right tool: TTL'd K/V store
  with sub-ms reads, exactly matching the lifecycle of an access
  token.
- *How do you protect against bruteforce?* — Stricter rate limit on
  `/auth/*` (10 req/min/IP), documented in `05_hardening.md`. The
  Throttler returns 429 well before bcrypt becomes a CPU bottleneck.
- *Why are tokens hashed before storage?* — For password reset and
  email verification, the user receives the raw token in their
  inbox; if our DB leaks, the attacker only sees hashes, useless to
  replay. Same idea as password hashing applied to short-lived
  tokens.
