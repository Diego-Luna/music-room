# Vérification du sujet — Music Room (v6)

Verdicts posés **consigne par consigne**, d’après le code.  
Légende : **OK** = respectée entièrement · **PARTIEL** · **KO** · _à vérifier_

---

## V.1 User

| Consigne | Verdict | Notes |
|----------|---------|-------|
| Premier lancement : l’utilisateur **doit** créer un compte. Choix mail/password **ou** compte social (Facebook ou Google). | **OK** | Pas de mode invité. Routeur → login. Signup email + Google/Facebook (création via `POST /auth/register` ou `POST /auth/social`). |
| Une fois le compte créé, l’app doit permettre de **lier** un compte réseau (Facebook ou Google). | **OK** | Settings → Link Google / Link Facebook → `POST /auth/link-social` (JWT). Pas d’unlink / pas d’état « déjà lié » (non exigé). |
| Profil : déclarer **et** mettre à jour infos publiques, infos amis seulement, infos privées, préférences musicales. | **OK** | 4 champs éditables sur Profile (`publicInfo`, `friendsInfo`, `privateInfo`, `musicPreferences`) via `PATCH /users/me`. Filtrage serveur : public pour tous ceux qui voient le profil ; friends pour amis ; private pour soi uniquement. |
| Compte mail/password : validation mail exigée + invitation à changer le mot de passe oublié. | **OK** | Register envoie un mail, aucun JWT tant que non vérifié, login 403 si `emailVerified` faux. Login → « Forgot Password? » → mail + page reset. Social skip la vérif (hors consigne). |

---

## V.2 Services

| Consigne | Verdict | Notes |
|----------|---------|-------|
| Accès à au moins 2 services sur 3 (Vote, Delegation, Playlist Editor) | **OK** | Vote **OK**, Playlist Editor **OK**, Delegation **OK** (player remote branché sur just_audio). |

### V.2.1 Music Track Vote

| Consigne | Verdict | Notes |
|----------|---------|-------|
| Live music chain : suggérer / voter ; plus de votes → plus haut / jouée plus tôt | **OK** | Suggest `POST /rooms/:id/tracks`, vote `.../vote`. Score en base. File d’attente et prochaine lecture : `score desc`, `addedAt asc`. Temps réel `track:added` / `track:voted` / `track:nowPlaying`. |
| Event public par défaut | **OK** | Prisma + `create()` + dialog Events (`_isPublic = true`). |
| Public : tous les users trouvent l’event **et** votent | **OK** | `GET /rooms` inclut les PUBLIC. Suggest/vote sans être membre (`requireRoomAccess` laisse passer). Users = authentifiés (V.1). |
| Privé : seuls les invités trouvent l’event **et** votent | **OK** | Non-membre : 404, absent de la liste. Invité : inbox → accept → membre → trouve + vote. |

| Licence : par défaut tout le monde peut voter | **OK** | `voteAccess` défaut `EVERYONE` (Prisma, create, dialog). |
| Licence : seuls les invités peuvent voter | **OK** | `voteAccess=INVITED_ONLY`. Indépendant de la visibilité. 403 si pas d’invitation. UI create + edit. |
| Licence : lieu **et** créneau (ex. 16h–18h) | **OK** | Geo (lat/lng/radius, haversine) + fenêtre `SCHEDULED`. Combinables à la création. Vote refusé hors zone / hors horaires. Position envoyée depuis Settings (pas de GPS device). |
| Concurrence : plusieurs gens votent la même track / des tracks différentes | **OK** | 1 vote / user / track (`@@unique`). Score via `increment` atomique SQL. Classement `score desc, addedAt asc`. Suggest : unique `(roomId, provider, providerId)`. Progression : `updateMany` conditionnel. |

**V.2.1 est entièrement OK** (licences + concurrence incluses).

### V.2.2 Music Control Delegation

| Consigne | Verdict | Notes |
|----------|---------|-------|
| Délégation du contrôle musique | **OK** (modèle + player) | Grant / revoke / liste / remote UI **par device**. Les commandes remote pilotent `just_audio` (`pause` / `resume` / next / prev / volume), filtrées par `deviceId`. |
| Licence spécifique à chaque device attaché au compte | **OK** (modèle) | Devices = sessions (`x-device-id` / RefreshToken). 1 délégation unique `(ownerId, deviceId)`. |
| Donner le contrôle à **plusieurs amis** | **OK** | Un ami par device ; plusieurs devices → plusieurs amis. API : amis seulement. |

### V.2.3 Music Playlist Editor

| Consigne | Verdict | Notes |
|----------|---------|-------|
| Playlist multi-user temps réel (« radio stations ») | **OK** | Rooms `kind: PLAYLIST`. Add / remove / reorder. Sockets `playlist:item-added/moved/removed`. Amis via invite ; autres via playlists publiques. « Radio » = file de lecture locale, pas un mode Station. |
| Visibilité : playlist publique par défaut | **OK** | Prisma + `create()` + dialog (`_isPublic = true`). |
| Public : tout user a accès | **OK** | Dans `GET /rooms`. `requireRoomAccess` laisse passer tout authentifié (voir/lire la playlist, sans être membre). |
| Privé : seuls les invités ont accès | **OK** | Non-membre : 404, absent de la liste. Join privé sans invite : 403. PUBLIC→PRIVATE évince les membres non invités. |
| Licence : par défaut tout le monde peut éditer | **OK** | `editAccess` défaut `EVERYONE` (Prisma, create, dialog « Who can edit? »). |
| Licence : seuls les invités peuvent éditer | **OK** | `editAccess=INVITED_ONLY`. Indépendant de la visibilité. 403 si pas d’invitation. Owner toujours OK. UI create + Edit Room. |
| Concurrence : plusieurs gens déplacent la même track / des tracks différentes | **OK** | Indexation fractionnaire (`generateKeyBetween`). Un move ne renumérote pas les autres. Tracks différentes = lignes indépendantes. Même track = last-write-wins. Tie-break `addedAt`. |

**V.2.3 est entièrement OK.**

## V.3 Server

| Consigne | Verdict | Notes |
|----------|---------|-------|
| Toutes les données des services sur le back-end ; le back est la **vérité** | **OK** | NestJS + Prisma + **PostgreSQL**. Users, rooms, tracks, votes, playlists, délégations, amis, invitations en base. L’app est un client REST/WS. Hive = cache + file offline (bonus VI.4) ; au reconnect `GET /sync` **écrase** le cache avec le snapshot serveur. |

## V.4 API

| Consigne | Verdict | Notes |
|----------|---------|-------|
| API = point d’accès pour toutes les apps ; doc méthodes / inputs / outputs | **OK** | Swagger auto-généré : `/api/docs`. Controllers annotés (`@ApiOperation`, DTOs `@ApiProperty`, responses). L’app Flutter (Dio) est le premier client. |
| Principe REST (ou autre, justifiable) | **OK** | Ressources `/users`, `/rooms`, `/auth`… verbes GET/POST/PATCH/PUT/DELETE. JWT Bearer. Socket.IO en plus pour le live (pas un remplacement de REST). |
| JSON (ou autre, justifiable) | **OK** | Bodies JSON, `ValidationPipe`, pas de GraphQL/XML/protobuf. |

## V.5 Mobile application

| Consigne | Verdict | Notes |
|----------|---------|-------|
| App = télécommande du back-end | **OK** | Flutter : REST (Dio) + Socket.IO. Pas de DB métier locale. Hive = cache/settings/offline (VI.4). Votes, rooms, profils, délégations vivent sur l’API. |
| Adresse du back-end configurable pour les tests | **OK** | Login + Settings (`BackendUrlSection`). Persisté Hive. Appliqué à Dio **et** Socket (`applyBackendUrlChange`). Tests `api_config_test` / `backend_url_live_test`. |
| Auth sociale Facebook **ou** Google dans l’app mobile | **OK** | Les deux : `google_sign_in` + `flutter_facebook_auth`, config iOS/Android, `POST /auth/social`. |

## V.6 Securing

| Consigne | Verdict | Notes |
|----------|---------|-------|
| User authentifié = ses données, pas celles des autres | **OK** | JWT global. `GET /users/:id` filtré (pas d’email, privateInfo soi seul). Rooms/votes/playlists/sessions/amis scopés `sub`. Pas de `PATCH /users/:id`. |
| Protections (bruteforce, vol de session…) | **OK** | Throttle auth 10/min/IP, bcrypt 12, rotation refresh + révocation famille si reuse, blacklist JWT logout, Helmet, CORS, ValidationPipe whitelist, tokens en Secure Storage. |
| Identifier d’autres hazards et expliquer les protections | **PARTIEL** | Les mécanismes sont dans le code. **Aucun** `dev_reports/05_hardening.md` (README le cite). À réciter en défense — liste ci-dessous. `GET /sync` ne fuite plus `passwordHash` (fix post-audit). |
| Chaque action mobile → logs back (platform, device, version) | **OK** | Headers `x-platform` / `x-device` / `x-app-version` sur **chaque** Dio + handshake WS. Middleware HTTP log pino ; gateway log connect/join/leave. Pas une table SQL (le sujet demande des logs, pas un audit DB). |

## V.7 Ramp-up

| Consigne | Verdict | Notes |
|----------|---------|-------|
| Mesurer / justifier le nombre d’users simultanés sur les **3 services** | **OK** | k6 (`backend/loadtest/`) : Vote `02` (50 VU), Playlist `03` (20 VU), Delegation `05` (40 VU) + auth + WS. Artefacts dans `loadtest/results/*.txt` (tous thresholds **pass**). |
| Outil type AB / Gatling / Siege / Tsung / JMeter | **OK** | **k6** (Grafana). Hors liste mais le sujet dit « for instance » — même classe d’outil, seuils p95 / error rate, reproductible (`measure.sh` / `run.sh`). |
| Specs serveur (CPU, RAM, cloud / premise) | **OK** | `loadtest/README.md` : host M1 8 cœurs / 8 Go, **Colima 2 vCPU / 1.9 GiB** (premise, loopback). Stack Nest + Postgres + Redis dans la VM. Comparé à un petit cloud (`t4g.small` / `e2-small`). |
| Max users cohérent avec la plateforme | **OK** | Dizaines–centaines sur 2 vCPU / ~2 Go (50 vote, 20 playlist, 40 délégation, 100 WS). Pas de claim « milliers » — aligné Raspberry/petit serveur, pas un cluster. |

**Baselines enregistrées** (même machine Colima, localhost) :

| Service | Script | Charge | p95 | Fail |
|---------|--------|--------|-----|------|
| Vote | `02_vote_surge.js` | 50 VU ~100 s | 159 ms | 0 % |
| Playlist | `03_playlist_reorder.js` | 20 VU 45 s | 41 ms | 0 % |
| Delegation | `05_delegation.js` | 40 VU ~100 s | 70 ms | 0 % |
| (sous-jacent) Auth | `01_auth_burst.js` | pic 50 RPS | 29 ms | 0 % |
| (sous-jacent) Realtime | `04_realtime_fanout.js` | 100 WS clients | session 35 s | 2020 events livrés |

**V.7 est OK** pour la soutenance si on montre README + un `results/*.txt`. Points picky (pas un KO) dans « À perfectionner ».

## V.8 Agility, quality and continued integration

| Consigne | Verdict | Notes |
|----------|---------|-------|
| Agilité, équipe, remettre en question ses choix | **OK** | 2 auteurs (Diego + Jérémy). Branches `main` / `dev` / `frontend`. Makefile racine (`install` / `test` / `dev`). Pivot Spotify → Deezer / rooms DELEGATE → délégation par device visible dans le code. Doc CI : `Doc/github/github_actions.md`. |
| Tests one-off **par couche** | **OK** | Back : ~45 `*.spec.ts` (controllers, services — **chaque** `*.service.ts` a un spec —, guards, filters, middleware, strategies) + e2e (auth, health, hardening, rate-limit, realtime, delegation). Front : models / providers / widgets / config / repos + `integration_test/offline_mode_test.dart`. Charge : k6 (V.7). `make test` lance les deux. |
| Intégration continue | **OK** (gate front) | GitHub Actions. Back : unit + e2e + Postgres/Redis. Front PR : `flutter test` + `build web`. **Fix** : `backend_url_live_test` skip si `/health` injoignable ; `debug_api_test` commenté. Reste picky : pas de `flutter analyze` / integration_test / k6 ; push `main` front déploie sans retester. |
| Credentials / API keys / env **hors git** (sinon fail projet) | **OK** | `backend/.env` gitignoré, pas de `.env` tracké. Placeholders dans `.env.example`. OAuth secrets via `local.properties` / `Secrets.xcconfig` / GitHub `secrets.*` / `--dart-define`. Compose lit `env_file: backend/.env`. |

**V.8 est OK** sur agilité, tests, secrets et CI front (skip live). Picky restants dans « À perfectionner ».

## IV.1 Architecture logicielle

| Consigne | Verdict | Notes |
|----------|---------|-------|
| Choix techno libres ; **justifier** bénéfices / inconvénients | **PARTIEL** | Stack réel cohérent (voir cheatsheet ci-dessous). Le rapport cité `dev_reports/01_stack_justification.md` est **absent** (comme `05_hardening.md`). README backend + `Doc/` décrivent encore Spotify, rooms DELEGATE, Firebase, Stripe, MailHog — **faux**. Un évaluateur qui lit ça avant l’oral peut coller. |
| Pas de libs commitées que vous n’avez pas écrites | **OK** | Pas de `node_modules`, Pods, `.dart_tool`, vendor. Déps via npm / pub. Lockfiles (`package-lock.json`, `pubspec.lock`, `Podfile.lock`). Assets 3D (`.glb`) = modèles, pas des libs. `package-lock.json` racine vide (bruit). |
| Clone → deps auto (Makefile ou équivalent) | **OK** | Makefile racine : `make install` → `backend` `npm install` + `flutter pub get`. Infra : `make up` / `docker-compose.yml`. CI fait `npm ci` + `flutter pub get`. Il faut Node 24 + Flutter sur la machine (toolchain, pas une lib du repo). |

**Cheatsheet orale « pourquoi ce stack »** (la consigne demande de justifier) :

| Choix | Bénéfice | Inconvénient / pourquoi pas l’autre |
|--------|----------|-------------------------------------|
| NestJS | Modules = domaines (auth, rooms, users), guards, Swagger | Plus lourd qu’Express ; on gagne la structure équipe |
| Fastify | Perfs vs adapter Express | Moins de middleware « tout fait » |
| Prisma + **PostgreSQL** | Schéma typé, migrations, ACID (votes / playlist concurrent) | Pas SQLite (trop léger pour multi-users) ; pas Mongo (relations rooms/votes) |
| Redis | Adapter Socket.IO + blacklist JWT ; scale horizontal sans sticky sessions | Service de plus |
| Flutter | iOS + Android + web (bonus VI.1) un seul client | Pas Swift/Kotlin natif |
| Provider + Dio + Socket.IO | REST = vérité ; WS = live | Deux canaux à expliquer (V.4) |
| Deezer | Previews sans OAuth user pour la lecture | Pas le catalogue Spotify (README encore Spotify) |

**IV.1 est OK** sur Makefile + pas de vendor ; **PARTIEL** sur la justification écrite. En défense : réciter le tableau, ne pas ouvrir le README backend tel quel.

## IV.2 Expérience mobile

| Consigne | Verdict | Notes |
|----------|---------|-------|
| L’app mobile permet **toutes** les actions du projet | **OK** | Flutter : mêmes écrans sur téléphone (V.1 + Vote + Playlist + délégation remote). Bottom nav sous 700 px. |
| Android **ou** iOS (techno libre) | **OK** | Les deux : `android/` (INTERNET + `usesCleartextTraffic`) et `ios/` (URL schemes Google/Facebook). Sujet = l’un des deux. |

**Mapping actions → écrans** (téléphone) :

| Action sujet | Où dans l’app |
|--------------|----------------|
| Signup mail / Google / Facebook | `SignupPage` + SDKs natifs (`authenticate()` / Facebook login) |
| Login + forgot / reset | `LoginPage`, `ForgotPage`, `ResetPasswordPage` (coller le token si pas de deep link) |
| Vérif mail | `VerifyEmailPage` ; le mail pointe `APP_FRONTEND_URL/#/auth/verify-email?token=` (souvent **web**) |
| Lier un réseau | Settings → Link Google / Facebook |
| Profil 4 champs | `ProfilePage` |
| Vote : créer, licences, suggest, swipe vote, invite | Events → dialog + `EventDetailPage` |
| Playlist : créer, licences, add / reorder / remove, invite | Playlists → `PlaylistDetailPage` (`SliverReorderableList`) |
| Privé : trouver + accepter | Inbox (`FriendsPage`) invitations |
| Amis | Inbox : search + requests |
| Délégation grant / revoke / remote UI | Profile → Devices ; `RemoteControlPage` (commandes → just_audio chez le owner) |
| URL du back (V.5) | Login + Settings `BackendUrlSection` ; Android emu réécrit `localhost` → `10.0.2.2` |

**IV.2 est OK.** Démo conseillée : **Android émulateur** (HTTP OK). iPhone physique + `http://IP` peut se faire bloquer (pas d’ATS cleartext dans `Info.plist`).

## Bonus — _à vérifier_

- [ ] VI.1 Multi-platform / web responsive
- [ ] VI.2 IoT / iBeacon
- [ ] VI.3 Free vs Paid subscription
- [ ] VI.4 Offline mode

---

## À perfectionner avant push (notes de défense)

Ce n’est **pas** des KO sujet. Un évaluateur picky peut quand même les poser. Cocher si on les fixe.

### V.1 Auth / comptes

- [ ] **Secrets OAuth natifs** pour la démo téléphone (`Secrets.xcconfig`, `local.properties`, dart-defines Google/Facebook). Sans ça les boutons sociaux et le link échouent à l’exécution.
- [ ] **Settings « Linked accounts »** : afficher l’état déjà lié + éventuellement Unlink (API `GET` / unlink absentes aujourd’hui). L’UI dit toujours « Link … ».
- [ ] **Login** : bouton « Renvoyer le mail de vérif » inline (aujourd’hui snackbar 403 seulement ; le resend est sur la page Verify Email).
- [ ] **Signup web Google** : le Login a le bouton GIS (`GoogleSignInButton`) ; le Signup appelle `authenticate()` qui retourne `null` sur web. Hors mandatory mobile, gênant si démo navigateur.
- [ ] **Reset password** : le front ne check que longueur ≥ 8 ; le back exige aussi majuscule / minuscule / chiffre → 400 peu lisible.
- [ ] **`AUTH_ALLOW_UNVERIFIED`** : savoir le justifier (load tests uniquement). Ne pas le laisser à `true` en démo / prod.
- [ ] **SMTP / Mailpit** : sans mail configuré, vérif + reset ne livrent pas les liens. Préparer une démo mail.

### V.1 Profil

- [ ] **displayName / avatar** : le back les accepte en `PATCH /users/me`, l’UI Profile ne les édite pas (hors consigne des 4 champs, mais on peut le demander).

### V.2.1 Vote — visibilité privée

- [ ] **Inbox invitation** : le DTO ignore le `room` imbriqué ; `GET /rooms/:id` 404 tant que pending → libellé **« a private room »**. Parser le nom côté API ou renvoyer le nom dans l’invitation.
- [ ] **Events list** : un invité pending ne voit pas l’event dans Events tant qu’il n’a pas Accept. Savoir expliquer : « find » = inbox, pas la search publique.

### V.2.1 Vote — licences geo / horaire

- [ ] **Pas de GPS device** : la position de vote vient de Settings → Vote location (lat/lng manuels). Suffisant pour une démo ordi ; un évaluateur peut demander le GPS réel.
- [ ] **Edit Room** : on peut changer « Who can vote? » après coup, mais **pas** geo ni fenêtre horaire (réglés à la création seulement).

### V.2.1 Vote — concurrence

- [ ] **`previous` vote lu hors transaction** : deux clics très rapides du *même* user peuvent TOCTOU ; le unique `(trackId, userId)` sert de filet (un 409). Mieux : lire / upsert *dans* la tx.
- [ ] **Load test `02_vote_surge`** : 50 VUs, 0 % fail — mais **chaque VU a sa propre room**. Ça prouve la charge, pas N votants sur *une* même track. Pour la défense, expliquer l’`increment` atomique + unique, ou refaire un script shared-room.

### V.2.2 Delegation

- [x] **Player owner** : `handlePlaybackCommand` pilote `_audio` (just_audio). `audioplayers` retiré.
- [x] **next / previous** : `case 'next'` / `'previous'` → `playNext()` / `playPrevious()`.
- [x] **Payload play** : plus de Spotify `uris`. Play sans `trackId` = resume. Owner ignore `trackUri`.
- [x] **Cible device** : ignore l’event si `data['deviceId']` ≠ le `x-device-id` local (`TokenStorage`).
- [ ] **Rapide — UI displayName** : l’API envoie déjà `delegate` / `owner` ; afficher `displayName` au lieu de l’UUID.
- [x] **Loadtest** : `05_delegation.js` liste `GET /users/me/devices` (plus `/users/me/delegations`).
- [x] **Picker amis** : `UserSearchSheet` est déjà sur Devices. L’API 403 si pas ami. Optionnel : n’afficher que `getFriends()`.
- [ ] **Moyen / court — Grant** : refuser un `deviceId` qui n’est pas une session active du owner.

### V.2.3 Playlist — live UI (pas un KO du paragraphe)

- [ ] **Rapide — `handleTrackMoved`** : met à jour `position` mais **ne re-trie pas**. La page détail skip le resync si les ids n’ont pas changé → le reorder d’un autre user peut ne pas bouger visuellement tant qu’on ne refresh pas.
- [ ] **Rapide — `handleTrackAdded`** : n’est **pas** filtré par `roomId` → la track peut apparaître sur toutes les playlists en cache.
- [ ] Pas de matching sur `musicPreferences` (amis + playlists publiques à la place). Savoir le dire.
- [ ] Éditer une playlist exige **PREMIUM** (bonus VI.3). Un FREE peut voir/rejoindre mais pas add/move/remove. En défense : c’est le bonus abo, pas un trou V.2.3.
- [ ] Playlist **privée** : même chemin que le Vote — l’invité pending la trouve dans l’inbox (libellé « a private room »), pas dans l’onglet Playlists tant qu’il n’a pas Accept.

### V.2.3 Playlist — concurrence

- [ ] **Load test `03_playlist_reorder`** : 20 VUs, 0 % fail, p95 ~41 ms — mais **chaque VU a sa propre playlist**. Charge OK, pas N éditeurs sur *une* liste. En défense : parler de l’indexation fractionnaire (pas de renumérotation, pas de deadlock).
- [ ] **Même trou entre deux tracks** : `generateKeyBetween(after, before)` est déterministe → deux inserts simultanés peuvent avoir la **même** `position`. Pas de unique là-dessus ; le tie-break `addedAt` départage. Pas un crash.
- [ ] **`computePosition` hors transaction** : voisins lus puis update. Un voisin peut avoir bougé entre-temps → last-write-wins, pas de 500.

### V.3 Server

- [ ] **Offline Hive** n’est pas une 2e vérité : file d’actions + cache. Conflit → le serveur gagne (409 discard, snapshot `/sync`). Savoir l’expliquer si on demande « les votes offline, c’est local ? ».
- [ ] `backend/README.md` parle encore de rooms DELEGATE et de Spotify (Deezer + délégation par device aujourd’hui). Cosmétique.

### V.7 Ramp-up

- [ ] **Pas un run mixte** des 3 services en même temps : 5 scénarios **séparés**. Suffisant pour « mesurer chaque service » ; un évaluateur peut demander « et si vote + playlist + délégation d’un coup ? ». Réponse : budget 2 vCPU, le goulot est Postgres ; additionner 50+20+40 VU saturera le pool. Le README qui dit « Vote (3 services together) » est **faux** — corriger avant défense.
- [ ] **k6 vs JMeter** : savoir dire « même famille, Grafana k6, seuils CI ». Pas besoin de relancer en JMeter.
- [ ] **Premise localhost**, pas Render/prod : latence réseau réelle absente. Les chiffres sont un **plafond local**. En cloud, moins de RPS à p95 égal.
- [ ] **`measure.sh` assouplit** `THROTTLE_LIMIT`, `AUTH_THROTTLE_LIMIT`, `BCRYPT_ROUNDS_OVERRIDE=4`, `AUTH_ALLOW_UNVERIFIED`. La capacité auth est donc **optimiste**. Vote / playlist / délégation (hors setup register) restent représentatifs.
- [x] **`GET /users/me/devices`** dans `05_delegation.js` (l’ancienne route `/users/me/delegations` n’existe plus). Relancer k6 avant soutenance pour un `results/05_delegation.txt` à jour.
- [ ] Vote 50 VU / playlist 20 VU = **1 room par VU** (déjà noté V.2). Charge API OK, pas N users sur *une* ressource.
- [ ] `dev_reports/11_loadtest.md` **absent** (README backend le cite). La vraie doc = `backend/loadtest/README.md` + `results/`.
- [ ] Playback délégation **exclu** des k6 (grant/list/revoke seulement — le player remote est just_audio chez le owner).

### V.8 Agility / CI / secrets

- [x] **CI front verte** : `backend_url_live_test` skip si `/health` injoignable. `debug_api_test.dart` commenté comme `debug_delegation_api_test.dart`.
- [ ] **`flutter analyze`** + `integration_test/offline_mode_test.dart` dans `validate-pr.yml`. Optionnel : k6 smoke.
- [ ] **Push `main` front** : `deploy-main.yml` build/deploy **sans** `flutter test`. Brancher le job test avant deploy, ou garder les PR comme gate (et ne plus push direct).
- [ ] **`backend-ci.yml`** : trigger `backend` (branche absente du remote) et **pas** `dev`. Ajouter `dev` si vous mergez là.
- [ ] Pas de PRs GitHub visibles (`gh pr list` vide) — en défense : branches + CI, ou coller 2–3 PRs d’exemple.
- [ ] **e2e vote / playlist** : uniquement unit (`tracks.service.spec`, `playlist.service.spec`). Suffisant « par couche » ; un picky peut demander un e2e HTTP vote.
- [ ] **Mot de passe seed** `Diego1@#` dans `prisma/seed.ts` (et le debug test commenté). Compte démo local, pas une clé API — savoir le dire. Ne pas le réutiliser en prod.
- [ ] **IDs publics commités** : Google client IDs dans `Info.plist` / `web/index.html` (le plist dit déjà « NOT a secret ») ; Facebook App ID défaut `1028619539827089` dans `main.dart`. Les **secrets** (client secret, client token) restent hors git. Si on demande : App ID ≠ App Secret.
- [x] **Root `.gitignore`** : `.env` / `.env.local` / `.env.*.local` à la racine. `backend/.gitignore` les ignorait déjà sous `backend/`.

### IV.1 Architecture

- [ ] **Rapide — 1 page `dev_reports/01_stack_justification.md`** (ou coller le tableau IV.1). Le README backend le cite et il n’existe pas.
- [ ] **README backend** : Prisma 7 / Postgres 18, Deezer pas Spotify, plus de kind DELEGATE, Mailpit pas MailHog. Tel quel c’est un contre-exemple de « on assume nos choix ».
- [ ] **`Doc/music-room - Resumen`** : Firebase, Stripe, Codemagic, `web_socket_channel` — plus le stack. À archiver ou à réécrire.
- [ ] `Doc/Arquitecture/*.md` : brouillons (DEVICE_LICENSE, Spotify ID, SQL « mon copain »). Swagger = contrat actuel.
- [ ] **`package-lock.json` racine** vide : le supprimer.
- [ ] `make install` n’installe **pas** Flutter/Node/Docker : les avoir pour la démo. `make build-frontend` = APK debug (pas web/iOS).
- [ ] Modèles `.glb` (Daft Punk, Marshall…) : assets Sketchfab, pas des libs — savoir le dire si on chipote « vous n’avez pas écrit ça ».

### IV.2 Mobile

- [ ] **Vérif / reset mail** : liens → front **web** (`/#/auth/...`). Reset a un champ coller token ; verify **non**. Sans Pages/web, coller le token n’est possible que pour le reset. Prévoir Mailpit + ouvrir le lien dans le navigateur du téléphone, ou un APK qui ouvre le hash.
- [ ] **iOS HTTP** : pas de `NSAllowsArbitraryLoads`. Simulateur + localhost souvent OK ; iPhone + IP LAN en `http://` peut échouer. Android a `usesCleartextTraffic=true`.
- [ ] **OAuth device** : sans `local.properties` / `Secrets.xcconfig` / dart-defines, Google/Facebook natifs cassent. Le chemin mail/password suffit pour IV.2.
- [x] **Play remote** : commandes branchées sur just_audio. Démo : owner lance une preview, ami play/pause depuis Remote Control.

### V.4 API

- [ ] **Doc markdown** `Doc/Arquitectura/Arquitectura REST.md` est un brouillon (DEVICE_LICENSE, Spotify, register+token). La doc **vraie** pour la défense = Swagger `/api/docs`.
- [ ] Tags Swagger dans `main.ts` : Auth, Users, Rooms, Search, Notifications, Health. Delegation / Subscription / Sync existent via `@ApiTags` mais ne sont pas listés dans le `DocumentBuilder`.
- [ ] Socket.IO n’est **pas** dans Swagger (normal). Savoir justifier : REST = vérité CRUD ; WS = fan-out live (votes, playlist, playback).

### V.6 Securing

**À fixer avant push (sécurité réelle) :**

- [x] **`GET /sync` fuit `passwordHash`** — `scrubUser()` (même mapping que `/users/me`). Spec sync vérifie l’absence du hash.
- [x] **Throttle** : Joi default `THROTTLE_LIMIT=100` (plus 100000). `.env` local déjà à 100. `docker-compose.yml` override passé de 100000 → 100 (`make up` n’éteint plus le throttle). Auth reste 10/min. `measure.sh` garde 1000000 pour les k6.

**Cheatsheet orale « hazards » (la consigne demande de les identifier) :**

| Hazard | Protection en place | Trou éventuel |
|--------|---------------------|---------------|
| Bruteforce login | Throttle auth 10/60s/IP | Register 409 énumère les emails |
| Vol de refresh | Rotation + révocation de toute la famille | — |
| Vol d’access JWT | TTL 15 min + blacklist Redis au logout | — |
| IDOR | JWT `sub` + 404 sur ressources privées | Grant délégation accepte un `deviceId` fantôme |
| Injection / champs en trop | ValidationPipe whitelist + forbidNonWhitelisted | — |
| Headers volés | CORS allowlist HTTP | WS `origin: true` (JWT quand même requis) |
| Hash leak | `scrubUser` sur `/users/me` **et** `GET /sync` | — |
| Compte non vérifié | Login 403 | `AUTH_ALLOW_UNVERIFIED` load tests seulement |

- [ ] Recréer 1 page `dev_reports/05_hardening.md` (ou coller ce tableau) pour la défense. Le README pointe un fichier **absent**.
