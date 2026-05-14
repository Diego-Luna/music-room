# Music Room — Backend

NestJS 11 + Fastify + Prisma 6 + PostgreSQL 16 + Redis 7. Collaborative
music platform for the 42 school subject, including the three room
kinds (VOTE / PLAYLIST / DELEGATE), Spotify integration, realtime
fan-out via Socket.IO, OAuth (Google + Facebook), email verification,
push notifications, and k6 load tests.

## Quick start

```sh
make install          # npm install
cp .env.example .env  # see below; then edit JWT secrets & Spotify creds
make docker-up        # postgres + redis + mailhog
make db-generate
make db-migrate       # applies every migration in prisma/migrations/
make dev              # start:dev on :3000
```

- Swagger UI: http://localhost:3000/api/docs
- MailHog UI (dev emails): http://localhost:8025

## Test suite

```sh
make test       # 264 unit tests
make test-e2e   # 36 end-to-end tests (HTTP + WebSocket)
make test-cov   # coverage report under coverage/
```

All tests run against light-my-request (in-memory HTTP) and a real
Prisma PostgreSQL connection; no network access is required beyond the
local Docker services.

## Structure

```
src/
 ├─ auth/              JWT issuance, refresh rotation, OAuth strategies
 ├─ users/             Profile & preferences
 ├─ rooms/             Rooms + members + tracks + playlist + delegation + playback
 ├─ realtime/          Socket.IO gateway + Redis adapter
 ├─ spotify/           Spotify Web API client (via native fetch)
 ├─ notifications/     Device-token registration + push transport
 ├─ mail/              Nodemailer wrapper (MailHog in dev)
 ├─ health/            /health/live, /health/ready
 ├─ common/            Guards, decorators, interceptors, middleware
 └─ prisma/            PrismaService wrapper

prisma/migrations/     Every schema change tracked chronologically
dev_reports/           One report per development phase
loadtest/              k6 scripts for the four major load shapes
```

## Phase-by-phase dev log

| Phase | Topic                                              | Report                                        |
|-------|----------------------------------------------------|-----------------------------------------------|
| 0     | Project audit                                      | `dev_reports/00_audit.md`                     |
| 1     | Tech stack justification                           | `dev_reports/01_stack_justification.md`       |
| 2     | Authentication                                     | `dev_reports/02_auth.md`                      |
| 3     | Users & sessions                                   | `dev_reports/03_users_sessions.md`            |
| 4     | Rooms                                              | `dev_reports/04_rooms.md`                     |
| 5     | Security hardening (Helmet, throttling, logging)   | `dev_reports/05_hardening.md`                 |
| 6     | Realtime (Socket.IO + Redis adapter)               | `dev_reports/06_realtime.md`                  |
| 7     | VOTE rooms                                         | `dev_reports/07_vote_rooms.md`                |
| 8     | PLAYLIST rooms (fractional indexing)               | `dev_reports/08_playlists.md`                 |
| 9     | Spotify integration                                | `dev_reports/09_spotify.md`                   |
| 10    | Music Control Delegation                           | `dev_reports/10_delegation.md`                |
| 11    | k6 load testing                                    | `dev_reports/11_loadtest.md`                  |
| 12    | Push notifications                                 | `dev_reports/12_notifications.md`             |
| 13    | Final wrap-up                                      | `dev_reports/13_final.md`                     |

Every report starts with "Scope" and ends with a "Soutenance defense
points" section answering the obvious "why did you pick this?"
questions for that phase.

## Environment

Expected variables (see `.env.example` if present, or `src/config/env.validation.ts`
for the authoritative Joi schema):

```
DATABASE_URL=postgresql://musicroom:musicroom@localhost:5432/musicroom
REDIS_HOST=localhost
REDIS_PORT=6379
JWT_SECRET=<32+ chars>
JWT_REFRESH_SECRET=<32+ chars>
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=
SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=
SPOTIFY_REDIRECT_URI=http://localhost:3000/auth/spotify/callback
APP_BASE_URL=http://localhost:3000
APP_FRONTEND_URL=http://localhost:8080
```

Missing optional OAuth creds simply disable that login path; the core
app boots and runs on local credentials + Spotify-less operation.
