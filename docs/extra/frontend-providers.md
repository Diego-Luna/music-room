# Providers (Flutter)

État global : `ChangeNotifier` dans `lib/providers/`. `notifyListeners()` redessine les `watch` / `Consumer`. Injectés via `MultiProvider` dans `main.dart`.

| Provider | Rôle |
|---|---|
| `AuthProvider` | Session, login / register / social, `TokenStorage` |
| `EventsProvider` | Rooms `VOTE` : suggest, vote, live `handleTrack*` |
| `PlaylistsProvider` | Rooms `PLAYLIST` : add / remove / move, sockets scoped `roomId` |
| `RoomsProvider` | Liste / sélection de rooms (pas un kind `DELEGATE`) |
| `SocketProvider` | `socket_io_client` : join/leave, fan-out vers les autres providers |
| `PlayerProvider` | File locale + `just_audio` ; `handlePlaybackCommand` (délégation) |
| `FriendsProvider` | Amis, requests |
| `MembersProvider` | Membres d’une room |
| `NotificationsProvider` | Inbox invitations / notifs |
| `ProfileProvider` | Les 4 champs + display |
| `SubscriptionProvider` | Free / Premium (bonus VI.3) — global, chargé au login |
| `ThemeProvider` | Clair / sombre |
| `NavigationProvider` | Bottom nav / routing helpers |

UI : `context.watch<T>()` pour rebuild, `context.read<T>()` pour un callback (pas d’abonnement). Pas d’appels réseau dans les constructeurs : `fetch*()` après montage.
