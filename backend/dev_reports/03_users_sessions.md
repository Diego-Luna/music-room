# Phase 2 — Users & Sessions

Phase 2 makes the state introduced in Phase 1 visible and controllable from the
client: a `/users/me` surface for profile reads and updates, a `/auth/sessions`
surface so a user can list and revoke their own active refresh tokens, plus a
Google audience check on the social-login verifier.

## 1. Scope

| Sujet                                                                 | Where                                                             |
|-----------------------------------------------------------------------|-------------------------------------------------------------------|
| V.5 expose user info (display name, avatar, music prefs, visibility)  | `GET /users/me`                                                   |
| V.5 allow the user to edit their info                                 | `PATCH /users/me`                                                 |
| V.6 give the user visibility on platform/device/version of sessions   | `GET /auth/sessions` returns each active session with device info |
| V.6 allow the user to revoke a session they don't recognise           | `DELETE /auth/sessions/:id`                                       |
| V.4 harden social login against token-mixup                           | `AuthService.verifyGoogleAudience`                                |

## 2. `UsersModule`

Flat module: `UsersController`, `UsersService`, `UpdateUserDto`.

- **`GET /users/me`** — JWT-protected, returns the caller's profile with sensitive
  fields stripped (`passwordHash` never leaves the service layer; the `scrub`
  helper is the single exit point for `User` rows).
- **`PATCH /users/me`** — JWT-protected, accepts only `displayName`, `avatarUrl`,
  `visibility`, `musicPreferences`. `class-validator` rejects unknown fields
  (`ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`), and the
  service also hand-picks keys before building the update payload — defense in
  depth. No route ever trusts `email`, `emailVerified`, `passwordHash` from the
  body.
- **Visibility** is modeled as a Prisma enum (`PUBLIC`, `FRIENDS`, `PRIVATE`) on
  the `User` row. It is read-only for other users (Phase 3 will introduce the
  `/users/:id` route that applies the visibility rule).

## 3. Sessions

Session = row in `RefreshToken`. Two new endpoints on `AuthController`:

- **`GET /auth/sessions`** returns only the currently active sessions of the
  caller (`revokedAt IS NULL AND expiresAt > now`), newest first, with
  `deviceId`, `userAgent`, `ip`, `expiresAt`, `createdAt`. The `tokenHash` is
  **never** returned — the client cannot rebuild a refresh token from the list,
  and neither can an attacker who captures the response.
- **`DELETE /auth/sessions/:id`** revokes one session. The service always loads
  the row by id and verifies `row.userId === caller.sub` before writing — a
  session id leaked in logs is useless to anyone but its owner. Returns 404 both
  for "doesn't exist" and "belongs to another user" to avoid leaking the
  existence of session ids.

Idempotency: deleting an already-revoked session is a no-op (returns 200, no
write). The client doesn't need to distinguish "first delete" from "replay" — the
UX of a cancel button works even if the request is retried.

## 4. Social login audience check

`AuthService.verifyGoogleAudience` is called before the Google userinfo fetch
whenever `GOOGLE_CLIENT_ID` is configured. It hits
`https://oauth2.googleapis.com/tokeninfo?access_token=…` and rejects if
`aud !== GOOGLE_CLIENT_ID`.

Why this matters: without the audience check, a malicious app can take a Google
access token it legitimately obtained for *its* app and present it to our
backend. Google's userinfo endpoint will happily return the user's profile (the
token is valid), and we'd mint our session for an identity we never
authenticated. This is the canonical OAuth token-mixup attack. The audience
check forces the token to have been issued for *our* `client_id`, which the
attacker cannot forge without our client secret.

In dev, leave `GOOGLE_CLIENT_ID` empty — the check is skipped and the tests run
without having to stub a second `fetch`.

Facebook is not trivially susceptible to the same attack because Facebook
access tokens are opaque, tied to the app that minted them at Graph API level,
and `/me` rejects tokens issued for other apps. Adding `appsecret_proof` is
planned but not done in Phase 2 (low marginal value; tracked in Phase 4
hardening).

## 5. Tests

```
Unit: 17 files, 132 tests, 99.59% stmts, 97.81% branches
E2E :  2 files,  23 tests (auth + users/me + sessions on the same app)
Total: 155 tests, all green
```

New specs:

- `src/users/users.service.spec.ts` — 5 tests: findOne hit + miss (404), update
  happy path, disallowed-fields stripping, avatarUrl forwarded, `?? []` default
  on `musicPreferences`.
- `src/users/users.controller.spec.ts` — 2 tests: GET /me, PATCH /me.
- `src/auth/auth.service.spec.ts` (sessions) — 4 tests: list active sessions
  ordered by createdAt desc, revoke owned session, revoke unowned → 404,
  revoke missing → 404, revoke already-revoked (idempotent).
- `src/auth/auth.service.spec.ts` (verifySocialToken) — 2 new tests: Google
  audience check with matching aud, audience mismatch.
- `src/auth/auth.controller.spec.ts` (sessions) — 2 tests.
- `test/e2e/auth.e2e-spec.ts` (sessions + users) — 4 tests covering the full
  Fastify round-trip: GET /users/me, PATCH /users/me, GET /auth/sessions +
  DELETE round-trip, 404 on unknown session id.

## 6. Soutenance defense points

- **Why return 404 (not 403) when revoking someone else's session?** Returning
  403 confirms that the id exists and belongs to another user. An attacker who
  wants to map the session-id space can use the 403 responses to find valid ids.
  404 keeps id space opaque.
- **Why strip `passwordHash` in the service layer instead of relying on
  `class-transformer` on the response?** Redundancy: if someone later adds a
  route that returns a `User` row without going through `UserProfile`, the hash
  doesn't leak. The `scrub` helper is the single exit. This is the same logic as
  never trusting input from one place only.
- **Why is `GET /users/me` JWT-protected but `PATCH /users/me` not rate-limited
  beyond the default bucket?** Read routes are cheap and identity-scoped (no
  enumeration risk — you can only ever read your own profile). Write routes
  could in principle be abused to churn the DB, but the surface is the caller's
  own profile — the blast radius is their own row. The 100/min global bucket is
  sufficient; adding a specific bucket would be cargo-culting.
- **Why keep sessions in `RefreshToken` instead of a dedicated `Session`
  table?** One refresh token ≡ one session by construction. A dedicated table
  would duplicate the same rows and create drift risk (revoke in one, not the
  other). The `RefreshToken` row already has `deviceId`, `userAgent`, `ip`,
  `expiresAt`, `createdAt`, `revokedAt` — everything a "session" needs.

## 7. Phase exit

- [x] `UsersModule` wired into `AppModule`
- [x] `GET /users/me` + `PATCH /users/me` end-to-end green
- [x] `GET /auth/sessions` + `DELETE /auth/sessions/:id` end-to-end green
- [x] Google audience check enabled when `GOOGLE_CLIENT_ID` set
- [x] 155/155 tests green, 99.59% stmts / 97.81% branches
- [x] No regression on Phase 1 tests

Phase 3 picks up the Rooms domain — the core business model (Music Track Vote
rooms, Music Playlist Editor rooms, Music Control Delegation), membership,
visibility rules, and the REST skeleton that Phase 5 will hang the realtime
layer off.
