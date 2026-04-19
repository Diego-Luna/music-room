# Phase 0 — Justification de la stack technique

**Date :** 2026-04-18
**Audience :** soutenance 42 (jury). Chaque choix doit être défendable face à un évaluateur qui ne connaît pas le projet.

---

## Cadre des contraintes (sujet)

- **IV.1** Pas de lib tierce committée ; deps réinstallables via `make install`.
- **III** Le SDK ne doit pas faire le travail métier.
- **V.3** Le backend est la source de vérité.
- **V.4** API REST recommandée, JSON, doc Swagger.
- **V.6** Logs Platform/Device/Version sur chaque action.
- **V.7** Charge mesurable et justifiée.
- **V.8** Pas de credentials commités.

Tous les choix ci-dessous sont motivés par ces contraintes, par la nécessité de gérer la concurrence (votes, édition collaborative), et par le besoin de rester maintenable en équipe sur ~1 mois.

---

## 1. Runtime — Node.js 20 LTS + TypeScript strict

**Pourquoi.** Écosystème mûr pour API HTTP + WebSocket, single-thread asynchrone idéal pour I/O (DB, Redis, Spotify), TypeScript strict élimine une classe entière de bugs (NPE, mauvais typage de payload) et sert de doc vivante.
**Alternatives écartées.** Go (typage fort + concurrence native, mais écosystème NestJS-équivalent moins riche, équipe à former) ; Python/FastAPI (productivité OK, mais perfs WebSocket en charge moins bonnes sans uvloop) ; PHP (Symfony pertinent mais culture WS/temps-réel moins idiomatique).

## 2. Framework — NestJS 11

**Pourquoi.** Architecture modulaire (modules/controllers/services/DTOs) qui mappe directement les services du sujet (Auth, TrackVote, PlaylistEditor, ControlDelegation). Injection de dépendances → tests unitaires triviaux (mocking via Vitest). Décorateurs `@ApiOperation` couplés à Swagger. Gateways WebSocket de première classe. Guards/Interceptors/Pipes/Filters → couches transverses (auth, validation, logging, exceptions) propres.
**Alternatives écartées.** Express nu (pas de structure imposée, on réinventerait NestJS à la main) ; Hapi (moins de communauté) ; Fastify nu (excellent en perf mais sans la stack DI/Swagger, on devrait câbler tout à la main).

## 3. Adapter HTTP — Fastify (vs Express)

**Pourquoi.** ~2× le throughput d'Express en charge selon les benchmarks officiels NestJS, parser JSON natif optimisé, schémas request/response intégrés, logger Pino par défaut (utile en V.6). Critique pour la cible V.7.
**Trade-off.** Quelques middlewares Express ne sont pas compatibles → on utilise les paquets `@fastify/*` (helmet, cors, multipart) maintenus par la même équipe.

## 4. ORM — Prisma 6

**Pourquoi.** Schéma déclaratif unique (`schema.prisma`) → migrations versionnées + types TS auto-générés → impossible d'envoyer une requête mal typée. Excellent support des transactions (`$transaction` + niveaux d'isolation) — indispensable pour la concurrence des votes et de la file de lecture (V.2.1, V.2.3). Studio fournit un debug visuel pour la soutenance.
**Alternatives écartées.** TypeORM (DX moins fluide, decorators-only) ; Drizzle (jeune, types brillants mais migrations moins matures) ; SQL brut (zéro garde-fou typage, productivité divisée).

## 5. Base — PostgreSQL 16

**Pourquoi.** ACID strict (Serializable disponible) → seul moyen propre de gérer "deux votes simultanés sur le même track" sans condition de course. Types riches (`uuid`, `jsonb`, `text[]`), contraintes uniques composites, index partiels — tout ce qu'il faut pour `Vote`, `PlaylistTrack`, `ControlGrant`. Réplication et tooling cloud universels.
**Alternatives écartées.** MySQL (Serializable plus coûteux historiquement) ; SQLite (pas de concurrence d'écriture sérieuse) ; MongoDB (les votes/playlists sont du relationnel pur ; un document store nous obligerait à recoder l'intégrité référentielle à la main → contredit V.3 "le backend est la vérité").

## 6. Cache & temps réel auxiliaire — Redis 7 (ioredis)

**Pourquoi 4 usages clairs :**
1. **Blacklist JWT** (logout immédiat / révocation device) — TTL aligné sur l'expiration du token.
2. **Cache Spotify** (résultats de recherche, métadonnées track) — réduit la pression sur le SDK et le rate-limit upstream.
3. **Rate-limit distribué** (storage du throttler).
4. **Pub/Sub Socket.io** (scaling horizontal des gateways WS).
**Alternatives écartées.** Memcached (pas de pub/sub, pas de structures riches) ; in-memory pur (perd la blacklist au restart, pas scale-out).

## 7. Temps réel — Socket.io via `@nestjs/platform-socket.io`

**Pourquoi.** Le frontend Flutter dispose d'un client Socket.io officiel ; la sémantique "rooms" mappe parfaitement les `events`, `playlists` et `devices`. Reconnexion auto, fallback long-polling utile en mobilité (V.2.1 "people gathered in a place" = wifi médiocre). Adapter Redis natif → scale-out trivial.
**Alternatives écartées.** WS natif Fastify (perf max, mais on perdrait reconnexion/rooms qu'il faudrait recoder — contredit "écrire ce qu'on n'a pas écrit nous-mêmes serait de toute façon hors-règle pour des libs significatives") ; SSE (unidirectionnel, inadapté aux votes/édition).

## 8. Auth — JWT (access court + refresh long) + Passport

**Pourquoi.** Stateless → scale horizontal sans session sticky. Refresh long stocké côté client + blacklist Redis pour rotation/logout couvre la critique habituelle "JWT est non-révocable". Passport encapsule proprement les stratégies `local`, `jwt`, et plus tard `google-oauth20` / `facebook`.
**Sécurité spécifique** : access token 15 min, refresh 7 j, rotation à chaque refresh, blacklist du précédent → vol de token mitigé.

## 9. Mail dev — Mailpit + nodemailer

**Pourquoi.** Validation email + reset password (V.1) exigent un envoi réel. Mailpit capture le SMTP local et expose une UI web → soutenance démontrable en direct sans configurer de provider tiers. Nodemailer est l'abstraction SMTP standard → bascule prod (SendGrid, SES, Mailgun) = changement de transport, zéro code métier touché.

## 10. SDK musique — client Spotify hand-written via `undici`

**Pourquoi.** Le sujet (III) interdit qu'un SDK fasse le travail. Notre service `SpotifyClient` ne fait que :
- échanger un client_credentials token,
- proxifier `/search` et `/tracks/:id`,
- mettre en cache via Redis.
Toute la logique métier (vote, file, édition collaborative) reste dans nos modules. `undici` est le client HTTP natif de Node.js 20, le plus performant.
**Pas de lib `spotify-web-api-node`** : on coderait 3 endpoints, l'inclure serait précisément le piège dénoncé par III.

## 11. Notifications push — endpoint `/notifications/register` + `firebase-admin` (planifié)

**Pourquoi.** L'enregistrement de tokens FCM/APNs côté back est l'interface minimale. `firebase-admin` est l'outillage officiel ; l'envoi reste un détail d'implémentation contrôlé par nous.

## 12. Documentation API — Swagger via `@nestjs/swagger`

**Pourquoi.** V.4 cite explicitement Swagger comme exemple acceptable. Génération à partir des annotations TS (`@ApiOperation`, `@ApiResponse`, DTOs) → toujours synchrone avec le code. Export OpenAPI JSON livré dans `dev_reports/openapi.json` à la fin (réutilisable par n'importe quel outil tiers ou le frontend).

## 13. Validation entrée — `class-validator` + `class-transformer` + `joi`

**Pourquoi.** `class-validator` aux DTOs (validation au niveau request, intégrée à NestJS), `joi` aux variables d'environnement (validation au boot, plus souple pour les patterns ENV). Frontière sécurité → on rejette tôt.

## 14. Sécurité transverse — `@fastify/helmet` + `@nestjs/throttler` + bcrypt 12

**Pourquoi.** Helmet (CSP, HSTS, X-Frame-Options, XContent-Type) → couvre OWASP top des en-têtes manquants. Throttler global + bucket dédié `/auth/*` → bruteforce (V.6). Bcrypt cost 12 → ~250 ms par hash, équilibre brute-force/UX.

## 15. Logs — Pino (intégré à Fastify) + middleware `RequestLogger`

**Pourquoi.** Pino est le logger le plus rapide de l'écosystème Node, déjà utilisé par Fastify. Le middleware capture `X-Platform`, `X-Device`, `X-App-Version` (V.6 obligatoire) et persiste les actions sensibles dans `ActionLog` (Phase 4).

## 16. Tests — Vitest 3 + `@vitest/coverage-v8` + supertest/light-my-request + socket.io-client

**Pourquoi.** Vitest démarre en ~200 ms (vs 5–10 s pour Jest avec ts-jest), watch instantané — la TDD impose un boucle Red→Green courte. Coverage v8 natif sans transformer custom. `light-my-request` est l'injecteur Fastify → tests HTTP sans ouvrir de port. Socket.io-client pour les tests WS bout-en-bout.

## 17. Conteneurisation — Docker Compose (dev) + Dockerfile multi-stage (prod, Phase 11)

**Pourquoi.** Compose en dev = `make docker-up` lance Postgres + Redis + Mailpit en une commande, identique sur tout poste. Dockerfile multi-stage en prod = image runtime ~150 MB, sans toolchain de build, sans node_modules dev → surface d'attaque réduite.

## 18. Charge — k6

**Pourquoi.** Scripts JS proches de notre stack, sortie metrics riche, support WebSocket natif (indispensable pour stresser les votes et l'édition de playlist en concurrence). Binaire installé via Makefile (`loadtest-install`), scripts versionnés dans `backend/loadtest/`. Apache Bench est trop limité (HTTP only, pas de scénario complexe).

---

## Récapitulatif "1 phrase par choix" pour la soutenance

- **NestJS** : structure modulaire = mappe les 3 services du sujet 1-pour-1.
- **Fastify** : 2× les perfs Express → V.7 facilité.
- **Prisma + Postgres** : ACID + Serializable → V.2.1/V.2.3 race conditions résolues.
- **Redis** : blacklist JWT + cache Spotify + rate-limit + pub/sub WS.
- **Socket.io** : rooms + reconnexion mobile = besoins live couverts.
- **JWT + refresh + blacklist Redis** : stateless mais révocable.
- **Mailpit** : V.1 démontrable en démo locale.
- **Client Spotify hand-written** : III "le SDK ne fait pas le travail" respecté à la lettre.
- **Swagger natif NestJS** : doc auto-synchrone avec le code (V.4).
- **Helmet + Throttler + bcrypt 12** : V.6 sécurité.
- **Pino + middleware Platform/Device/Version** : V.6 logs.
- **Vitest TDD** : R→G→R court, coverage 100 % visé (qualité V.8).
- **Docker Compose + Makefile** : `make install && make dev` = up-and-running, IV.1 respecté.
- **k6** : V.7 mesurable et reproductible.
