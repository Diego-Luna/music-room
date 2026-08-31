# IV.2 / V.5 — Application mobile

L’app est la **télécommande** du back (REST Dio + Socket.IO). Adresse du back **configurable**. Auth sociale Facebook **ou** Google (les deux sont branchés).

## Où se font les actions du sujet

| Action | Écran |
|---|---|
| Signup mail / Google / Facebook | `SignupPage` + SDKs natifs |
| Login, forgot / reset | `LoginPage`, `ForgotPage`, `ResetPasswordPage` (coller le token si pas de deep link) |
| Vérif mail | `VerifyEmailPage` ; le mail pointe `APP_FRONTEND_URL/#/auth/verify-email?token=` (souvent **web**) |
| Lier un réseau | Settings → Link Google / Facebook |
| Profil 4 champs | `ProfilePage` (`publicInfo`, `friendsInfo`, `privateInfo`, `musicPreferences`) |
| Vote : créer, licences, suggest, swipe, invite | Events → dialog + `EventDetailPage` |
| Playlist : créer, licences, add / reorder / remove, invite | Playlists → `PlaylistDetailPage` |
| Privé : trouver + accepter | Inbox (`FriendsPage`) — invitations |
| Amis | Inbox : search + requests |
| Délégation grant / revoke / remote | Profile → Devices ; `RemoteControlPage` (commandes → `just_audio` chez l’owner) |
| URL du back (V.5) | Login + Settings `BackendUrlSection` (Hive). Dio **et** Socket. Android emu : `localhost` → `10.0.2.2` |

Bottom nav sous 700 px. Cibles : `android/` (`INTERNET` + `usesCleartextTraffic`) et `ios/` (URL schemes Google / Facebook). Le sujet demande **l’un** des deux.

## Démo conseillée

**Émulateur Android** (HTTP OK). iPhone physique + `http://IP` LAN : pas de `NSAllowsArbitraryLoads` dans `Info.plist` — ATS peut bloquer. Simulateur iOS + localhost : souvent OK.

OAuth natif : sans `local.properties` / `Secrets.xcconfig` / dart-defines, Google / Facebook cassent **à l’exécution**. Le chemin mail / password suffit pour IV.2 et pour une démo ordi.

## Player

Previews Deezer via `just_audio`. Délégation : l’ami envoie `playback:command` ; seul le device owner dont `deviceId` matche joue / pause / next / prev / volume.
