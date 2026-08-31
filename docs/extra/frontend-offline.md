# Bonus VI.4 — Offline

Hive n’est **pas** une 2ᵉ base métier. C’est un cache + une file. Au reconnect, le **serveur** gagne.

## Pièces

| Classe | Fichier | Rôle |
|---|---|---|
| `OfflineCache` | `lib/config/offline_cache.dart` | Rooms / tracks + file d’`OfflineAction` |
| `OfflineRoomRepository` | `lib/core/repositories/offline_room_repository.dart` | Décorateur : lecture remote puis cache ; écriture optimiste + enqueue |
| `ConnectivitySyncManager` | `lib/core/services/connectivity_sync_manager.dart` | Drain FIFO au retour réseau, puis `GET /sync` |

Le reorder playlist **n’est pas** mis en file (online-only).

## Reconnect

1. Envoi séquentiel des actions.
2. 409 / 404 removal : traité comme déjà appliqué, on retire de la file.
3. 403 / autre 4xx définitif : discard + notif (cause) ; on ne bloque pas la suite.
4. 5xx / réseau : pause, retry plus tard.
5. Snapshot `GET /sync` (user **scrubbé**, pas de `passwordHash`) écrase Hive.
6. Socket reconnect.

Tests : `flutter test integration_test/offline_mode_test.dart -d flutter-tester` + suite `test/core/services/connectivity_sync_manager_test.dart`, `test/repositories/offline_*`.
