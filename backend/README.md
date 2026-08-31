# Music Room — Backend

NestJS 11 + Fastify + Prisma 7 + PostgreSQL 18 + Redis 7. Rooms `VOTE` / `PLAYLIST`, délégation **par device**, search **Deezer**, Socket.IO, OAuth Google / Facebook, Mailpit, k6.

Pas de kind `DELEGATE`, pas de Spotify. Justification : [`docs/sujet/01-stack.md`](../docs/sujet/01-stack.md). API : `http://localhost:3000/api/docs`.

## Quick start

Depuis la **racine** du repo :

```sh
cp backend/.env.example backend/.env
make install
make up                 # docker compose
# ou, back en watch sur la machine :
make -C backend dev     # lève postgres/redis/mailpit puis nest --watch
```

- Swagger : http://localhost:3000/api/docs
- Mailpit : http://localhost:8025
- Variables : `.env.example` + schéma Joi `src/config/env.validation.ts`

## Tests / charge

Depuis `backend/` :

```sh
make test               # unit (vitest)
make test-e2e           # HTTP + WebSocket, Postgres + Redis
make loadtest           # k6, backend déjà up — voir docs/sujet/05-loadtest.md
```

## Structure

```
src/
  auth/           JWT, refresh, OAuth, vérif mail
  users/          Profil, amis, devices
  rooms/          Rooms, membres, tracks vote, playlist
  delegation/     Grant / revoke / playback commands
  deezer/         Search
  realtime/       Socket.IO + Redis adapter
  subscription/   Free / Premium
  sync/           Snapshot offline
  notifications/  Push tokens
  mail/           Nodemailer (Mailpit en dev)
  health/         /health
  common/         Guards, pipes, middleware logs
prisma/           Schéma + migrations
loadtest/         Scripts k6 + results/
```
