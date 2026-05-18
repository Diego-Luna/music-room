# Phase 13 — Final wrap-up

## Scope

Snapshot of the backend at the time of soutenance: what's in, what's
out, what the numbers look like, and what we'd argue for in the
defense session.

## Mandatory part — coverage of the subject

| Subject section | Status | Where to look |
|---|---|---|
| **V.1** Email/password register | ✅ | `02_auth.md`, `src/auth/auth.controller.ts:register` |
| **V.1** Social register (Google, Facebook) | ✅ | `02_auth.md`, `src/auth/strategies/` |
| **V.1** Link social to existing account | ✅ | `POST /auth/link-social` |
| **V.1** Email validation | ✅ | `EmailVerification` model + `MailService` + Mailpit |
| **V.1** Password reset | ✅ | `PasswordReset` model + `forgotPassword/resetPassword` |
| **V.1** Profile: public/friends-only/private + music preferences | ✅ | `03_users_sessions.md` (profile-level visibility chosen over per-field) |
| **V.1** Friends concept (required to enforce FRIENDS_ONLY) | ✅ | `Friendship` model, `/users/me/friends` endpoints |
| **V.2** ≥ 2 of 3 services | ✅ 3 of 3 implemented | `07_vote_rooms.md`, `08_playlists.md`, `10_delegation.md` |
| **V.2.1** Vote: visibility + time + location license | ✅ | `enforceVoteWindow`, `enforceGeoGate` in `tracks.service.ts` |
| **V.2.1** Vote race conditions | ✅ | `prisma.$transaction` + atomic `score increment` |
| **V.2.2** Delegation per-device | ⚠️ Single-delegate model; documented limitation | `10_delegation.md` |
| **V.2.3** Playlist: visibility + invited-only-edit | ✅ | `allowMembersEdit` + role check |
| **V.2.3** Playlist concurrency | ✅ | Fractional indexing |
| **V.3** Backend is source of truth | ✅ | All state in Postgres, frontend has no authoritative store |
| **V.4** REST API + Swagger | ✅ | `/api/docs` |
| **V.4** JSON | ✅ | Fastify default, controllers return objects |
| **V.6** Bruteforce protection | ✅ | Two-tier throttler |
| **V.6** Session theft mitigation | ✅ | Refresh rotation + JWT blacklist + session listing |
| **V.6** Auth user → own data only | ✅ | Global `JwtAuthGuard`, per-resource ownership checks |
| **V.6** Mandatory log of X-Platform/X-Device/X-App-Version | ✅ | `RequestLoggerMiddleware` applied to `*` |
| **V.7** Load testing + server specs | ✅ | `loadtest/README.md` + 4 k6 scripts |
| **V.8** `.env` not in repo | ✅ | `.gitignore` covers; only `.env.example` committed |

## Bonus part

> "The bonus part will only be assessed if the mandatory part is
> PERFECT."

Status of mandatory: **complete with one known limitation**
(V.2.2 per-device delegation). Whether the jury considers the
mandatory PERFECT or not determines whether bonuses are even looked
at.

Bonus surface in this repo:
- VI.1 Multi-platform: handled by the Flutter frontend (separate
  scope)
- VI.2 IoT: not implemented
- VI.3 Free/Paid: not implemented (the `LicenseTier` enum that
  used to live in the schema was removed as dead code)
- VI.4 Offline: frontend-side concern

## Numbers

```
src/ TypeScript files:           ~110
prisma/ migrations:                ~10 (incl. add_friendship,
                                       drop_license_tier)
Unit tests:                        342 (in 38 spec files)
End-to-end tests:                   36 (in 5 spec files, hitting
                                        the dockerized stack)
Coverage (unit only):              statements 96.73 %
                                   branches    90.61 %
                                   functions   96.66 %
                                   lines       98.05 %
Docker stack components:           4 (backend + postgres + redis +
                                      mailpit)
```

## Known limitations and how we'd close them

1. **Per-device delegation (V.2.2)** — single `Room.delegateUserId`
   instead of one delegation per `(room, owner, device)`. Fix
   estimated 2–3 h: new `DelegationGrant` model + refactor
   `DelegationService` + thread `ownerDeviceId` through
   `PlaybackService`. Detailed in `10_delegation.md`.
2. **5 npm advisories** — 3 moderate + 2 high, all in the Fastify
   chain (`fastify`, `@nestjs/platform-fastify`) and the Prisma
   dev tooling. They're awaiting upstream patches; we monitor with
   `npm audit` but don't `--force` to avoid breaking the build.
3. **Mutation testing score not measured** — line coverage of 98 %
   says "lines executed", not "bugs caught". A Stryker run would
   give a real number. Out of scope for the deadline.
4. **No e2e coverage measurement** — current `npm run test:cov`
   only includes unit tests. The 36 e2e tests cover the HTTP +
   Socket.IO + Postgres pipeline but don't bump the coverage
   number. Could be added with a merged JSON report; documented
   as "future work" in the loadtest README.

## What we'd push back on, in defense

- *"Why only 2 of the 3 services completely conform to per-device
  license?"* — Subject V.2 minimum is **2 of 3 functions**. We
  pass with margin (Vote and Playlist are full; Delegation is the
  third one, with a documented simplification). The "license per
  device" sentence is itself ambiguous (3 readings, see Phase 10).
- *"Why TypeScript + Nest instead of Go / Rust / Python?"* —
  Team familiarity + ecosystem (Passport, Prisma, Swagger). The
  load-test numbers prove the stack is fast enough for the
  subject's "thousands of users on a low-end server" expectation.
- *"How do you prove you didn't let an SDK do your work?"* —
  Spotify is used for **catalog and playback**; every business
  rule (room rules, vote logic, ordering, role checks, license
  enforcement) is in `src/rooms/*.service.ts`, hand-written, with
  342 unit tests. The Spotify module is ~300 lines, the rooms
  domain is ~1,500.

## What to bring to the soutenance

1. The repo with the stack running (`docker compose up -d` from
   root).
2. Swagger at http://localhost:3000/api/docs to demo the API
   surface in 30 seconds.
3. Mailpit at http://localhost:8025 to show the email verification
   flow live.
4. `make test` to show 342 tests passing in <5 s.
5. `make test-e2e` to show 36 e2e tests passing in <10 s against
   the real stack.
6. The 13 reports in `dev_reports/` for the jury to skim — the
   defense answers are pre-written, indexed by phase.

## Soutenance defense points

- *Why these reports?* — The subject (IV.1, V.4) demands that
  decisions be justified. These reports are the written record,
  one per phase, with a "Soutenance defense points" section
  answering the predictable questions before the jury asks.
- *Why is `10_delegation.md` the most honest report?* — Because
  the V.2.2 sentence is genuinely ambiguous and the easy thing
  would have been to claim full compliance. Documenting the
  limitation in advance is what lets us defend "2 of 3 services
  fully, plus a partial third" instead of being caught off-guard.
- *Anything you wish you'd done differently?* — Started the
  `dev_reports/` from day 0 instead of bulk-writing them at the
  end. Decision rationale evaporates fast; capturing it on the
  same day reduces noise.
