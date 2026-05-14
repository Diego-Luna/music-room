# Phase 0 — Project audit

## Scope

Initial inventory of the 42 Music Room subject against an empty repo:
identify the surface area, fix the language/framework family, decide
the team split (backend vs frontend), and lock down the parts that
must be in the mandatory deliverable.

## Findings

### Subject requirements that drive the backend
- **V.1 Authentication**: email/password, social (Google + Facebook),
  email verification, password reset, link-social.
- **V.2 Services (≥ 2 of 3)**: Music Track Vote, Music Playlist
  Editor, Music Control Delegation. We elected to implement **all
  three** to maximize jury defense surface.
- **V.4 API documentation**: Swagger required.
- **V.6 Securing**: bruteforce protection, session theft, **mandatory
  log of `X-Platform` / `X-Device` / `X-App-Version` on every route**.
- **V.7 Ramp-up**: load testing with documented server characteristics.
- **V.8**: `.env` MUST NOT be committed (subject explicitly says
  "Publicly stored credentials = automatic failure").

### Subject items that are **frontend** concerns (out of scope here)
- V.5 (mobile app implementation, social login UI flow)
- VI.1 (web responsive)
- VI.4 (offline mode + sync)

### Bonus features in scope **if** mandatory is perfect
- VI.2 IoT (iBeacon)
- VI.3 Free/Paid subscription tiers

### Ambiguities flagged for later
- **V.2.2 "license must be specific for each device"** — 3 sentences,
  several valid interpretations. Discussed in `10_delegation.md`.
- **V.1 "informations only available to their friends"** — implies a
  Friendship concept. Implemented in `03_users_sessions.md`.

## Decisions taken

| Topic                | Choice                                  | Why                                                                  |
|----------------------|------------------------------------------|----------------------------------------------------------------------|
| Backend split        | One repo, `backend/` subfolder           | Monorepo with `frontend/` Flutter, single CI                          |
| Language             | TypeScript                               | Strong typing for a complex domain; team familiarity                  |
| HTTP framework       | NestJS + Fastify adapter                 | Modular architecture, DI, decorator-driven controllers (see Phase 1) |
| DB                   | PostgreSQL                               | ACID needed for vote race conditions (Phase 7)                       |
| ORM                  | Prisma                                   | Single source of truth schema, typed client                           |
| Cache + realtime     | Redis                                    | JWT blacklist, Socket.IO Pub/Sub adapter                              |
| Test runner          | Vitest                                   | Fast ESM-native; Nest ecosystem support                              |
| Realtime             | Socket.IO + `@socket.io/redis-adapter`   | Native rooms abstraction; horizontal scale via Redis                  |

## Soutenance defense points

- *Why did you read the subject end-to-end before writing code?* —
  Because the subject explicitly fails the project for missing the
  mandatory part, and "bonuses only evaluated if mandatory is
  PERFECT". The audit prevents writing bonus code while a mandatory
  is still incomplete.
- *Why three services instead of the minimum two?* — The mandatory
  bar is 2/3 and we elected to implement 3/3 so that even if one
  service is judged imperfect, the other two cover the bar. (See
  `10_delegation.md` for the remaining limitation on delegation.)
- *Where did you record the ambiguities of the subject?* — Here. Each
  ambiguity has a follow-up report that documents the interpretation
  chosen and the rationale.
