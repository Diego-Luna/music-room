# V.4 — API

Le sujet demande une API comme point d’accès, documentée (méthodes / inputs / outputs), REST (ou justifiable), JSON (ou justifiable).

## Contrat = Swagger, pas un markdown

UI générée depuis les controllers Nest : **`http://localhost:3000/api/docs`**.

Annoté : `@ApiOperation`, DTOs `@ApiProperty`, codes de réponse. Premier client : Flutter (Dio).

Ne pas prendre d’anciens brouillons (`/events/{id}/vote`, `DEVICE_LICENSE`, Spotify ID) pour la défense. Si le markdown et Swagger divergent, **Swagger gagne**.

## REST + JSON

Ressources `/auth`, `/users`, `/rooms`, `/search`, … Verbes GET / POST / PATCH / PUT / DELETE. Bodies JSON. `ValidationPipe` (`whitelist` + `forbidNonWhitelisted`). Pas de GraphQL / XML / protobuf.

Hors `Auth` et `Health` : Bearer JWT.

Tags `DocumentBuilder` (liste du groupe) : Auth, Users, Rooms, Search, Notifications, Health. Delegation, Subscription et Sync existent via `@ApiTags` sur les controllers — ils apparaissent dans le document même s’ils ne sont pas tous listés dans le builder.

## Carte des ressources (orientation)

| Tag | Rôle |
|---|---|
| Auth | Register, login, refresh, logout, social, link, verify, forgot / reset |
| Users | `GET/PATCH /users/me`, profils, amis, devices |
| Rooms | CRUD rooms, membres, invitations, tracks vote, playlist add/move/remove |
| Delegation | Grant / revoke / liste ; commandes playback |
| Search | Recherche Deezer |
| Subscription | Free / Premium (bonus VI.3) |
| Sync | Snapshot `GET /sync` (offline) |
| Notifications | Tokens push |
| Health | `/health` |

Socket.IO n’est **pas** dans Swagger (normal). Justification : REST = vérité CRUD ; WS = fan-out ([02-architecture.md](02-architecture.md)).
