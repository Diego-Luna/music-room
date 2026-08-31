# V.6 — Sécurité

Trois exigences : un user authentifié ne voit **que ses** données ; des protections (bruteforce, vol de session…) ; **identifier** d’autres hazards et expliquer les contre-mesures. Toute action mobile doit laisser des **logs** back (platform, device, version).

## Isolation des données

JWT global (`sub`). `GET /users/:id` filtré (pas d’email ; `privateInfo` soi seul ; `friendsInfo` si ami). Rooms / votes / playlists / sessions / amis scopés sur `sub`. Pas de `PATCH /users/:id`. Rooms privées : 404 si non membre / non invité.

## Protections en place

| Mécanisme | Détail |
|---|---|
| Bruteforce login | Throttle **auth** 10 req / 60 s / IP (`AUTH_THROTTLE_*`) |
| Mots de passe | bcrypt cost 12 |
| Refresh volé | Rotation + révocation de **toute la famille** si reuse |
| Access JWT volé | TTL 15 min + blacklist Redis au logout |
| Injection / champs en trop | `ValidationPipe` whitelist + `forbidNonWhitelisted` |
| Headers HTTP | Helmet, CORS allowlist |
| Tokens client | Flutter Secure Storage |
| Sync | `GET /sync` passe par `scrubUser()` (pas de `passwordHash`) |
| API globale | Throttle 100 / 60 s (`THROTTLE_LIMIT`) |

## Hazards identifiés

| Hazard | Protection | Trou éventuel (assumer) |
|---|---|---|
| Bruteforce login | Throttle auth 10/60s/IP | Register 409 peut énumérer les emails |
| Vol de refresh | Rotation + révocation famille | — |
| Vol d’access JWT | TTL 15 min + blacklist Redis | — |
| IDOR | JWT `sub` + 404 sur ressources privées | Grant délégation accepte un `deviceId` qui n’est pas une session active |
| Injection / overposting | ValidationPipe | — |
| Headers volés / CSRF navigateur | CORS allowlist HTTP | WS `origin: true` (JWT quand même requis) |
| Hash leak | `scrubUser` sur `/users/me` **et** `/sync` | — |
| Compte non vérifié | Login 403 tant que `emailVerified` faux | `AUTH_ALLOW_UNVERIFIED` : load tests seulement, pas démo / prod |

## Logs mobile → back

Chaque requête Dio et le handshake WS envoient `x-platform`, `x-device` (modèle lisible), `x-app-version`. `x-device-id` = UUID stable (sessions / délégation). Middleware HTTP : pino. Gateway : connect / join / leave.

Le sujet demande des **logs**, pas une table d’audit SQL.
