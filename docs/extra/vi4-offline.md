# VI.4 — Offline mode

Le sujet : profiter de l’app **sans réseau**, avec une expérience **différente**, plus une **synchro** au retour. Attention aux **conflits** et aux **données périmées** sur le mobile.

Hive n’est **pas** une 2ᵉ base métier. Cache + file. Au reconnect, le **serveur** gagne.

## Expérience offline (différente)

Bandeau app-wide : *Offline — cached playlists and votes. Changes sync when you reconnect.*

| Marche hors-ligne | Refusé (besoin du serveur) |
|---|---|
| Lire events / playlists / tracks **déjà cachés** | Créer / supprimer / join / leave / invite une room |
| Voter (optimiste + file) | Reorder playlist (indices fractionnaires + Premium) |
| Ajouter / retirer un track playlist | Search Deezer, invitations, membres / rôles |
| Suggérer un track vote | Mutations amis, profil d’un autre user |
| Liste d’amis (cache) | Player preview Deezer (besoin du CDN) |

Un Free ne voit pas l’éditeur playlist (VI.3) même online.

## Synchro au reconnect

`ConnectivitySyncManager` écoute `connectivity_plus`. Drain aussi **au lancement** et **au login** s’il y a déjà du réseau (sinon une file restante ne partirait que sur un *changement* de connectivité). **Pas de JWT** (Start / Login) → pas d’appel `/rooms` (sinon 401). Retour réseau → `syncQueue()` :

1. **File FIFO** (`pending_actions`) : vote, add playlist/vote track, remove playlist track.
2. Succès → pop. **409** / **404** sur un remove = déjà appliqué, pop silencieux.
3. **403 / autre 4xx** : pop + SnackBar avec la **cause** backend (session vote fermée, Premium requis…).
4. **401 / 5xx / réseau** : **pause**, on retente plus tard (une action pourrie ne gèle pas la file).
5. **Données périmées** : `GET /rooms` (liste **complète**, y compris publiques) → `deleteRoomsExcept` (ghosts) ; on **garde** les tracks cachés car la liste n’embarque pas les tracks.
6. **`GET /sync`** : snapshot *mes* données (profil scrubbé, rooms owned/member **sans** tracks, invitations, friendships) → on n’écrase **pas** le cache rooms avec ça (sinon on perdrait le catalogue public + les tracks). On rafraîchit seulement les listes d’**amis**.

`move` n’est **jamais** mis en file (replay d’ancres décalées = liste corrompue).

## Conflits / concurrence

- Votes : unique `(trackId, userId)` → re-vote = upsert / 409.
- Add track : unique `(roomId, provider, providerId)` → doublon 409 = OK.
- Deux clients éditent : le serveur départage ; le cache local est recouvert au sync. Pas de merge 3-ways.

## Démo orale

1. Online : ouvrir une playlist, noter les tracks.
2. Mode avion → bandeau. La playlist se lit. Delete un track → disparaît tout de suite.
3. Réseau → la file part ; si 403 Premium, SnackBar *Remove from playlist not synced — …*.
4. Room supprimée ailleurs → elle disparaît du cache (`deleteRoomsExcept`).

Tests : `flutter test integration_test/offline_mode_test.dart -d flutter-tester` + suite `test/core/services/connectivity_sync_manager_test.dart`, `test/repositories/offline_*`, `test/widgets/offline_host_test.dart`.
