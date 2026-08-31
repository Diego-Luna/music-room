# IV.1 — Stack et justification

Le sujet laisse le choix des technos **à condition de justifier** bénéfices / inconvénients, de ne pas committer de libs non écrites, et d’avoir un clone → deps automatique.

## Versions réelles (2026)

| Couche | Choix | Pas |
|---|---|---|
| API | NestJS 11 + Fastify | Express seul, GraphQL |
| ORM / DB | Prisma 7 + **PostgreSQL 18** | SQLite, Mongo, rooms `DELEGATE` |
| Cache / pub-sub | Redis 7 | Sticky sessions |
| Live | Socket.IO (`@socket.io/redis-adapter`) | `web_socket_channel` seul |
| Auth | JWT + refresh rotation, Google / Facebook OAuth | Firebase Auth |
| Catalogue / preview | **Deezer** (previews 30 s, pas d’OAuth user) | Spotify Web API |
| Mail dev | **Mailpit** `:8025` | MailHog |
| Client | Flutter (iOS, Android, web) + Provider + Dio | Swift/Kotlin natifs, Stripe |
| Player in-app | `just_audio` (preview Deezer) | `audioplayers` |

Infra locale : `docker-compose.yml` à la racine (Postgres, Redis, Mailpit, backend).

## Pourquoi ce stack / pourquoi pas l’autre

| Choix | Bénéfice | Inconvénient / alternative écartée |
|---|---|---|
| NestJS | Modules = domaines (auth, rooms, users), guards, Swagger auto | Plus lourd qu’Express ; on gagne la structure à 2 |
| Fastify | Adapter Nest plus léger qu’Express | Moins de middleware « tout fait » |
| Prisma + PostgreSQL | Schéma typé, migrations, ACID (votes / playlist concurrent) | SQLite trop léger en multi-users ; Mongo mal adapté aux relations rooms/votes |
| Redis | Adapter Socket.IO + blacklist JWT ; scale horizontal sans sticky sessions | Un service de plus à opérer |
| Flutter | iOS + Android + web (bonus VI.1) un seul client | Pas de UI 100 % native Swift/Kotlin |
| Provider + Dio + Socket.IO | REST = vérité CRUD ; WS = fan-out live | Deux canaux à expliquer (V.4) — volontaire |
| Deezer | Previews sans OAuth utilisateur pour la lecture in-app | Pas le catalogue Spotify |

Pivot visible dans le code : rooms `kind` = `VOTE` \| `PLAYLIST` seulement. La délégation (V.2.2) est **par device** (`x-device-id` / RefreshToken), pas un 3ᵉ kind `DELEGATE`.

## Pas de libs commitées que nous n’avons pas écrites

Pas de `node_modules`, Pods, `.dart_tool`, vendor. Dépendances via `npm` / `pub`. Lockfiles : `backend/package-lock.json`, `frontend/music_room_app/pubspec.lock`, `Podfile.lock`.

Les `.glb` (Daft Punk, Marshall…) sont des **assets** Sketchfab, pas des bibliothèques.

## Clone → deps

```sh
make install    # backend: npm install + prisma generate ; front: flutter pub get
make up         # docker compose : postgres + redis + mailpit + backend
```

`make install` n’installe **pas** Node, Flutter ni Docker : toolchain de la machine (comme `npm ci` en CI). `make build-frontend` produit un APK **debug**, pas iOS / web.
