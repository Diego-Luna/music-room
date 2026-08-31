# V.3 / V.4 — Architecture (back = vérité)

Toutes les données métier vivent sur le backend (Nest + Prisma + PostgreSQL). L’app Flutter est un client REST + Socket.IO. Hive n’est **pas** une seconde vérité : cache + file d’actions (bonus offline) ; au reconnect `GET /sync` **écrase** le cache.

## Deux kinds de rooms

`RoomKind` Prisma : `VOTE` | `PLAYLIST`. Pas de kind `DELEGATE`.

| Kind | Sujet | Live (Socket.IO) |
|---|---|---|
| `VOTE` | V.2.1 Track Vote | `track:added`, `track:voted`, `track:nowPlaying` |
| `PLAYLIST` | V.2.3 Playlist Editor | `playlist:item-added`, `playlist:item-moved`, `playlist:item-removed` |

Visibilité (`PUBLIC` / `PRIVATE`) et licences (`voteAccess` / `editAccess` = `EVERYONE` | `INVITED_ONLY`) sont **orthogonales**. Geo + créneau (`SCHEDULED`) s’appliquent au vote.

Le client **émet** `room:join` / `room:leave` avec `{ roomId }`. Les mutations (vote, add, move) passent par **REST** ; le serveur **broadcast** ensuite. WS n’est pas un CRUD parallèle.

## Délégation (V.2.2)

Pas une room : une licence par **device** attaché au compte (`x-device-id` + session RefreshToken). Grant / revoke / liste : REST `Delegation`. Commandes remote : event `playback:command` (filtrées par `deviceId`) → `just_audio` chez l’**owner**.

## REST vs Socket.IO

| Canal | Rôle | Exemples |
|---|---|---|
| HTTP JSON | Vérité, auth, CRUD, licences | `POST /rooms/:id/tracks/:tid/vote`, `PATCH .../playlist/:tid/move` |
| Socket.IO | Fan-out vers les clients déjà dans la room | scores, ordre playlist, playback, invitations |

JWT sur les deux (Bearer HTTP ; handshake WS). Adapter Redis : plusieurs instances backend sans sticky sessions.

Catalogue : `GET` Search **Deezer**. Le player in-app joue `previewUrl` (30 s), pas un stream Spotify.

## Concurrence (ce qu’on assume)

- Vote : 1 vote / user / track (`@@unique`) ; score via `increment` SQL ; classement `score desc, addedAt asc`.
- Playlist : indexation fractionnaire (`generateKeyBetween`). Un move ne renumérote pas les autres. Tie-break `addedAt` si deux clés identiques.
