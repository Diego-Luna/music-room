# Music Room — Conformité au sujet (back-end)

Référence : `en.subject.pdf` v6, 15 pages.
Cible : ce document indique, **consigne par consigne**, ce qui est fait, ce qui est
discutable, ce qui manque, et l'état des bonus.

Tous les chemins de fichiers sont relatifs à `backend/` sauf mention contraire.

---

## 1. Consignes du sujet RÉALISÉES (✅)

### Interdictions / règles dures

| # | Consigne du sujet | Fichier(s) prouvant la conformité |
|---|---|---|
| IV.1 | Aucune lib tierce committée dans le repo | `.gitignore:1-2` (`node_modules/`) ; `git ls-files \| grep node_modules` = vide |
| IV.1 | Dépendances installables automatiquement | `Makefile:13-14` (cible `install: npm install`) ; `package.json` (dependencies + devDependencies) |
| III | Le SDK ne fait pas le travail | Spotify : appels REST manuels `fetch()` dans `src/spotify/spotify.service.ts:165-219` (pas de SDK). Google/Facebook : vérification token + REST `fetch()` dans `src/auth/auth.service.ts:456-515` |
| V.8 | `.env` jamais committé | `backend/.gitignore:6-9` ; `git ls-files \| grep -E '\.env$'` = vide (seul `.env.example` tracké) |
| V.8 | Tous credentials/API keys dans `.env` local | `.env.example` (template) ; chargé via `ConfigModule.forRoot` + `src/config/env.validation.ts` |

### V.1 — User

| # | Consigne | Fichier(s) |
|---|---|---|
| V.1 | Inscription via email/mot de passe | `src/auth/auth.controller.ts:57-67` (`POST /auth/register`) ; `src/auth/auth.service.ts:69-91` |
| V.1 | Inscription via réseau social (Google ou Facebook) | `src/auth/auth.controller.ts:86-97` (`POST /auth/social`) ; `src/auth/auth.service.ts:131-181` (handle les deux providers) |
| V.1 | Validation email **exigée** si email/mdp ("must demand") | `register()` n'émet **aucune session** (renvoie un message) ; `login()` rejette en **403** tout compte email/mdp non vérifié (`src/auth/auth.service.ts`) ; `POST /auth/verify-email` + `POST /auth/resend-verification` (`src/auth/auth.controller.ts`) ; `src/mail/mail.service.ts` (envoi, capté par Mailpit en dev) ; modèle `EmailVerification` |
| V.1 | Forgot password / changement de mdp | `src/auth/auth.controller.ts:124-147` ; `src/auth/auth.service.ts:248-295` ; modèle `PasswordReset` dans `prisma/schema.prisma:269-280` |
| V.1 | Lier compte social après inscription | `src/auth/auth.controller.ts:99-111` (`POST /auth/link-social`) ; `src/auth/auth.service.ts:183-218` |
| V.1 | Music preferences modifiables | `src/users/dto/update-user.dto.ts:37-42` ; `src/users/users.service.ts:46-48` ; champ `musicPreferences` dans `prisma/schema.prisma:23` |

### V.2.1 — Music Track Vote

| # | Consigne | Fichier(s) |
|---|---|---|
| V.2.1 | Suggérer un track | `src/rooms/tracks.controller.ts:37-47` ; `src/rooms/tracks.service.ts:50-85` |
| V.2.1 | Voter (et tri par votes) | `src/rooms/tracks.controller.ts:49-61` (vote) ; `src/rooms/tracks.service.ts:87-144` ; tri `orderBy [{ score: 'desc' }, { addedAt: 'asc' }]` à la ligne 178 |
| V.2.1 | Visibilité Public/Private (défaut Public) | `prisma/schema.prisma:69-72, 98` (`RoomVisibility @default(PUBLIC)`) ; check d'accès `src/rooms/tracks.service.ts:168-175` et `src/rooms/rooms.service.ts:45-61` |
| V.2.1 | License : tout le monde par défaut | `requireMember` autorise tout membre (`src/rooms/tracks.service.ts:191-198`) |
| V.2.1 | License : voter à un lieu + un horaire | `voteWindow ALWAYS\|SCHEDULED` + `voteLocationLat/Lng/RadiusM` dans `prisma/schema.prisma:106-111` ; enforcement `src/rooms/tracks.service.ts:200-231` (Haversine) |
| V.2.1 | Concurrence sur les votes | `prisma.$transaction` + `score: { increment: delta }` atomique : `src/rooms/tracks.service.ts:114-135` |
| V.2.1 | Progression automatique de la file | `src/rooms/queue-progression.service.ts` (tick serveur, avance le morceau quand il se termine, broadcast `track:nowPlaying`) ; champ `Room.currentTrackStartedAt` dans `prisma/schema.prisma:122` |

### V.2.2 — Music Control Delegation

| # | Consigne | Fichier(s) |
|---|---|---|
| V.2.2 | Déléguer le contrôle musical à des amis | `src/delegation/delegation.service.ts` (`grant`/`revoke`) ; gate amitié via `FriendsService.areFriends` (un non-ami → 403) |
| V.2.2 | Spécifique à chaque device du compte | Table `MusicControlDelegation`, clé `(ownerId, deviceId)` unique : `prisma/schema.prisma:202` ; `deviceId` = valeur du header `X-Device` |
| V.2.2 | Donner le contrôle à *différents* amis | Une délégation par device → chaque device est délégable indépendamment ; routes `PUT/DELETE/GET /users/me/devices/:deviceId/delegate` dans `src/delegation/delegation.controller.ts` |
| V.2.2 | Contrôle effectif de la lecture | `src/delegation/delegation-playback.service.ts` (play/pause/next/previous/volume) exécuté contre le token Spotify **du propriétaire** ; routes `/delegations/:id/playback/*` dans `src/delegation/delegation-playback.controller.ts` |

### V.2.3 — Music Playlist Editor

| # | Consigne | Fichier(s) |
|---|---|---|
| V.2.3 | Édition temps réel multi-user | Socket.io fan-out via `emitToRoom` : `src/rooms/playlist.service.ts:79, 123, 149` ; gateway dans `src/realtime/realtime.gateway.ts` ; adapter Redis dans `src/realtime/redis-io.adapter.ts` |
| V.2.3 | Visibilité Public/Private (défaut Public) | Idem V.2.1 (même modèle `Room`) ; check `src/rooms/playlist.service.ts:152-164` |
| V.2.3 | Concurrence sur le déplacement de tracks | Fractional indexing : `src/rooms/playlist.service.ts:190-218` + lib `fractional-indexing` dans `package.json` |

### V.3 — Server

| # | Consigne | Fichier(s) |
|---|---|---|
| V.3 | Toutes les données stockées côté back-end (back = source de vérité) | `prisma/schema.prisma` (toutes les entités) ; aucun stockage côté client n'est utilisé pour l'autorité |

### V.4 — API

| # | Consigne | Fichier(s) |
|---|---|---|
| V.4 | API REST | Tous les controllers : `@Controller(...)` + `@Get/@Post/@Patch/@Delete` ; routes resource-oriented (`/rooms/:id/tracks/:trackId/vote`) |
| V.4 | Échanges JSON | `ValidationPipe` global avec class-transformer (`src/main.ts:36-42`) |
| V.4 | Documentation API auto-générée (méthodes, inputs ET outputs) | `src/main.ts` (Swagger `DocumentBuilder`, exposé sur `/api/docs`) ; `@ApiTags` + `@ApiOperation` sur tous les controllers ; **inputs** via les DTOs class-validator ; **outputs** via des classes de réponse typées câblées en `@ApiOkResponse`/`@ApiCreatedResponse({ type })` (`src/**/dto/*-response.dto.ts`) — 60/64 endpoints exposent un schéma de réponse |

### V.5 — Mobile (côté back-end)

| # | Consigne | Fichier(s) |
|---|---|---|
| V.5 | Auth via réseau social exposée pour le mobile | `POST /auth/social` (`src/auth/auth.controller.ts:86-97`) ; `POST /auth/link-social` |
| V.5 | Backend joignable depuis un mobile (CORS, host 0.0.0.0) | `src/main.ts:34` (`app.enableCors()`), `src/main.ts:74` (`listen(port, '0.0.0.0')`) |

### V.6 — Securing

| # | Consigne | Fichier(s) |
|---|---|---|
| V.6 | User authentifié n'accède qu'à ses données | Guard JWT global : `src/app.module.ts:96-98` (`APP_GUARD: JwtAuthGuard`) ; `src/common/guards/jwt-auth.guard.ts` ; vérifications de possession sur chaque ressource (room ownerId, friendship, track addedById…) |
| V.6 | Anti-bruteforce | `@nestjs/throttler` avec tier `auth` à 10/min/IP : `src/app.module.ts:63-77` ; `@Throttle({ auth: {} })` sur `src/auth/auth.controller.ts:40` |
| V.6 | Vol de session | Refresh token rotation + détection de réutilisation (révocation famille entière) : `src/auth/auth.service.ts:298-343` ; blacklist Redis : `src/auth/jwt-blacklist.service.ts` |
| V.6 | Headers HTTP de sécurité | Helmet : `src/main.ts:21-32` |
| V.6 | Validation des entrées | `ValidationPipe { whitelist, forbidNonWhitelisted, transform }` : `src/main.ts:36-42` ; DTOs avec class-validator partout (`src/**/dto/*.ts`) |
| V.6 | Logs obligatoires : X-Platform, X-Device, X-App-Version | `src/common/middleware/request-logger.middleware.ts:25-27` ; appliqué `forRoutes('*')` dans `src/app.module.ts:103` |

### V.7 — Ramp-up

| # | Consigne | Fichier(s) |
|---|---|---|
| V.7 | Évaluation et mesure de la charge supportée par les 3 services | `loadtest/02_vote_surge.js` (vote), `loadtest/03_playlist_reorder.js` (playlist), `loadtest/05_delegation.js` (delegation) couvrent les 3 services obligatoires ; `loadtest/01_auth_burst.js` (auth) + `loadtest/04_realtime_fanout.js` (realtime) couvrent les couches sous-jacentes — k6 avec `thresholds` |
| V.7 | Spécification du serveur (CPU, RAM, etc.) | `loadtest/README.md:8-41` (tableau host + container) |
| V.7 | Nombre d'utilisateurs cohérent avec la plateforme | `loadtest/README.md:155-170` (par scénario) |

### V.8 — Agility, quality, CI

| # | Consigne | Fichier(s) |
|---|---|---|
| V.8 | Tests unitaires par couche | 40 fichiers `*.spec.ts` dans `src/` ; lancement `make test` |
| V.8 | Tests e2e | `test/e2e/auth.e2e-spec.ts`, `delegation.e2e-spec.ts`, `hardening.e2e-spec.ts`, `health.e2e-spec.ts`, `rate-limit.e2e-spec.ts`, `realtime.e2e-spec.ts` ; lancement `make test-e2e` |

---

## 2. Consignes SUJETTES À DISCUSSION (🟡)

À préparer pour la soutenance : un argumentaire clair sur chacun de ces points car un correcteur strict peut les contester.

### 🟡 V.1 — Granularité de la visibilité du profil

**Texte du sujet :**
> *"In their profile, the user must be able to state and update :*
> *- their public informations,*
> *- informations only available to their friends,*
> *- their private informations,*
> *- their music preferences."*

**Implémentation actuelle :**
- Une **seule** valeur `visibility` au niveau de l'utilisateur entier : `PUBLIC \| FRIENDS_ONLY \| PRIVATE` (`prisma/schema.prisma:22`).
- `findOnePublic` applique ce flag globalement (`src/users/users.service.ts:79-87`).

**Interprétation 1 (la nôtre) :** le user range *son profil* dans une catégorie de visibilité.
**Interprétation 2 (stricte) :** chaque champ du profil doit pouvoir être catégorisé individuellement.

**Soit on défend, soit on étend :** ajouter `displayNameVisibility`, `avatarVisibility`, `musicPreferencesVisibility` sur le modèle `User` + filtrage par champ dans `toPublic`.

---

### 🟡 V.2.1 — License "invited-only" pour le vote

**Texte du sujet :**
> *"With the right license, the invited people are the only one who can vote."*

**Implémentation actuelle :** pour qu'un user vote, il doit être membre de la room (`src/rooms/tracks.service.ts:97, 191-198`). Une room PRIVATE n'est joignable que sur invitation. La license "invited-only" se confond donc avec la visibilité PRIVATE — il n'y a pas de license orthogonale.

**Limite défensive :** une room **PUBLIC** où seuls les invités peuvent voter (tout en étant visible de tous) n'est pas représentable en l'état.

La migration `prisma/migrations/20260510190655_drop_license_tier/` montre qu'un modèle `licenseTier` plus explicite a été retiré pendant le développement.

---

### 🟡 V.2.3 — License "invited users only can edit"

**Texte du sujet :**
> *"With the right license, the invited users are the only ones who can edit the playlist."*

**Implémentation actuelle :** `allowMembersEdit` à `false` restreint l'édition à OWNER + ADMIN (`src/rooms/playlist.service.ts:178-188`). Ce n'est pas exactement "invited users" — c'est **plus strict** (un membre invité non-promu ne peut pas éditer).

**Choix à clarifier :**
- soit on assouplit : `allowMembersEdit=false` → tous les membres (= invités) peuvent éditer, tout le monde d'autre est bloqué ;
- soit on garde la logique actuelle et on défend "ADMIN = invité promu".

---

## 3. Consignes NON RÉALISÉES (🔴)

**Aucune.** V.2.2 (Music Control Delegation par device) — qui était le dernier écart net avec la lettre du sujet — a été implémentée le 2026-05-21. Voir §1, section V.2.2. La délégation est désormais au niveau **compte + device** (table `MusicControlDelegation`), conformément à *"specific for each device attached to the user's account"*. L'ancien modèle `RoomKind.DELEGATE` (DJ scopé à une room) a été entièrement retiré.

---

## 4. Bonus (VI) — État

Rappel : le bonus n'est évalué **que si** la partie obligatoire est PARFAITE.

| # | Bonus | Fait | Détail |
|---|---|---|---|
| VI.1 | Multi-platform / responsive web | ❌ Non fait | Front Flutter est multi-plateforme par défaut (iOS, Android, Web), mais aucune optimisation responsive spécifique web vérifiable côté back-end |
| VI.2 | IoT (IBeacon) | ❌ Non fait | Aucune route ni mécanisme de découverte d'événement par proximité |
| VI.3 | Free vs Paid subscription | ❌ Non fait | Aucun modèle `Subscription` / `Plan` dans le schéma ; aucune gate sur les features |
| VI.4 | Offline mode | ❌ Non fait | Aucun mécanisme de sync / conflict resolution côté back-end (cohérent : c'est plutôt côté client) |

---

## 5. Checklist finale avant soutenance

1. **✅ V.2.2** : délégation par device implémentée (`src/delegation/`). Reste à appliquer les 2 migrations (`20260521000000`, `20260521120000`) sur la base de soutenance.
2. **🟡 V.1** : décider visibilité globale vs par-champ et documenter.
3. **🟡 V.2.3** : clarifier la sémantique de `allowMembersEdit=false`.
4. **V.7** : faire tourner les 5 scripts k6 et déposer la sortie dans `loadtest/results.YYYYMMDD.md` (la procédure est déjà dans `loadtest/README.md`).
5. Re-vérifier que `git status` ne montre aucun `.env` ni `node_modules`.
