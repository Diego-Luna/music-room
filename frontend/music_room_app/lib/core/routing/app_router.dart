import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/core/repositories/mock_api_repository.dart';
import 'package:music_room_app/core/repositories/rest_api_repository.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/core/repositories/rest_api_friends_repository.dart';
import 'package:music_room_app/core/repositories/mock_friends_repository.dart';
import 'package:music_room_app/core/repositories/offline_friends_repository.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/core/repositories/offline_room_repository.dart';
import 'package:music_room_app/core/services/connectivity_sync_manager.dart';
import 'package:music_room_app/core/repositories/device_repository.dart';
import 'package:music_room_app/core/repositories/rest_device_repository.dart';
import 'package:music_room_app/core/repositories/mock_device_repository.dart';
import 'package:music_room_app/core/services/push_token_service.dart';
import 'package:music_room_app/pages/auth/pages/forgot_page.dart';
import 'package:music_room_app/pages/auth/pages/reset_password_page.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/navigation_provider.dart';
import 'package:music_room_app/providers/theme_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/socket_provider.dart';
import 'package:music_room_app/core/audio/audio_player_service.dart';
import 'package:music_room_app/pages/home/pages/home_page.dart';
import 'package:music_room_app/pages/main/pages/main_screen.dart';
import 'package:music_room_app/pages/playlists/pages/playlists_page.dart';
import 'package:music_room_app/pages/playlists/pages/playlist_detail_page.dart';
import 'package:music_room_app/pages/events/pages/events_page.dart';
import 'package:music_room_app/pages/settings/pages/settings_page.dart';
import 'package:music_room_app/pages/settings/pages/devices_page.dart';
import 'package:music_room_app/pages/subscription/pages/subscription_page.dart';
import 'package:music_room_app/pages/profile/pages/profile_page.dart';
import 'package:music_room_app/pages/auth/pages/login_page.dart';
import 'package:music_room_app/pages/auth/pages/signup_page.dart';
import 'package:music_room_app/pages/auth/pages/verify_email_page.dart';
import 'package:music_room_app/pages/friends/pages/friends_page.dart';
import 'package:music_room_app/pages/player/pages/player_page.dart';
import 'package:music_room_app/pages/start/pages/start_page.dart';
import 'package:music_room_app/pages/not_found/pages/not_found_page.dart';
import 'package:music_room_app/core/routing/route_names.dart';

//* Native lazy singletons
RoomRepository? _roomRepository;
RoomRepository? _remoteRepository;
FriendsRepository? _friendsRepository;
ApiClient? _apiClient;
OfflineCache? _offlineCache;
ConnectivitySyncManager? _syncManager;
PushTokenService? _pushTokenService;
NavigationProvider? _navigationProvider;
AuthProvider? _authProvider;
ThemeProvider? _themeProvider;
EventsProvider? _eventsProvider;
PlaylistsProvider? _playlistsProvider;
RoomsProvider? _roomsProvider;
FriendsProvider? _friendsProvider;
NotificationsProvider? _notificationsProvider;
PlayerProvider? _playerProvider;
SocketProvider? _socketProvider;
DeviceRepository? _deviceRepository;

//* Initialize singletons. safe to call multiple times.
void setupLocator() {
  // * Providers
  _navigationProvider ??= NavigationProvider();
  _authProvider ??= AuthProvider();
  _themeProvider ??= ThemeProvider();
  _eventsProvider ??= EventsProvider(repository: roomRepository);
  _playlistsProvider ??= PlaylistsProvider(repository: roomRepository);
  _roomsProvider ??= RoomsProvider(repository: roomRepository);
  _friendsProvider ??= FriendsProvider(repository: friendsRepository);
  _notificationsProvider ??= NotificationsProvider(
    roomRepository: roomRepository,
    friendsRepository: friendsRepository,
  );
  _playerProvider ??= PlayerProvider(
    authProvider: authProvider,
    roomsProvider: roomsProvider,
    deviceRepository: deviceRepository,
    audioService: JustAudioPlayerService(),
  );
  _socketProvider ??= SocketProvider(
    authProvider: authProvider,
    eventsProvider: eventsProvider,
    playlistsProvider: playlistsProvider,
    roomsProvider: roomsProvider,
    playerProvider: playerProvider,
    friendsProvider: friendsProvider,
    notificationsProvider: notificationsProvider,
  );
}

//* Accessors to retrieve the registered singletons.

// * Resolves the correct repository based on the feature flag
ApiClient get apiClient => _apiClient ??= ApiClient(
  onUnauthorized: () {
    authProvider.forceLogout();
  },
);

RoomRepository get remoteRepository =>
    _remoteRepository ??= RestApiRepository(client: apiClient);

FriendsRepository get friendsRepository {
  if (_friendsRepository != null) return _friendsRepository!;
  if (ApiConfig.useMockData) {
    _friendsRepository = MockFriendsRepository();
  } else {
    // * Offline decorator: friend lists are read from cache when offline.
    _friendsRepository = OfflineFriendsRepository(
      remoteRepository: RestApiFriendsRepository(client: apiClient),
    );
  }
  return _friendsRepository!;
}

OfflineCache get offlineCache => _offlineCache ??= OfflineCache();

ConnectivitySyncManager get syncManager =>
    _syncManager ??= ConnectivitySyncManager(
      remoteRepository: remoteRepository,
      cache: offlineCache,
    );

PushTokenService get pushTokenService =>
    _pushTokenService ??= PushTokenService(client: apiClient);

RoomRepository get roomRepository {
  if (_roomRepository != null) return _roomRepository!;
  if (ApiConfig.useMockData) {
    _roomRepository = MockApiRepository();
  } else {
    // * Offline decorator wraps remote — reads from cache on failure,
    // * writes optimistically and queues mutations for sync on reconnect.
    _roomRepository = OfflineRoomRepository(
      remoteRepository: remoteRepository,
      cache: offlineCache,
    );
  }
  return _roomRepository!;
}

ThemeProvider get themeProvider => _themeProvider ??= ThemeProvider();

NavigationProvider get navigationProvider =>
    _navigationProvider ??= NavigationProvider();

AuthProvider get authProvider => _authProvider ??= AuthProvider();

EventsProvider get eventsProvider =>
    _eventsProvider ??= EventsProvider(repository: roomRepository);
PlaylistsProvider get playlistsProvider =>
    _playlistsProvider ??= PlaylistsProvider(repository: roomRepository);
RoomsProvider get roomsProvider =>
    _roomsProvider ??= RoomsProvider(repository: roomRepository);
FriendsProvider get friendsProvider =>
    _friendsProvider ??= FriendsProvider(repository: friendsRepository);

NotificationsProvider get notificationsProvider =>
    _notificationsProvider ??= NotificationsProvider(
      roomRepository: roomRepository,
      friendsRepository: friendsRepository,
    );

DeviceRepository get deviceRepository {
  if (_deviceRepository != null) return _deviceRepository!;
  if (ApiConfig.useMockData) {
    _deviceRepository = MockDeviceRepository();
  } else {
    _deviceRepository = RestDeviceRepository(client: apiClient);
  }
  return _deviceRepository!;
}

PlayerProvider get playerProvider => _playerProvider ??= PlayerProvider(
  authProvider: authProvider,
  roomsProvider: roomsProvider,
  deviceRepository: deviceRepository,
  audioService: JustAudioPlayerService(),
);

SocketProvider get socketProvider => _socketProvider ??= SocketProvider(
  authProvider: authProvider,
  eventsProvider: eventsProvider,
  playlistsProvider: playlistsProvider,
  roomsProvider: roomsProvider,
  playerProvider: playerProvider,
  friendsProvider: friendsProvider,
  notificationsProvider: notificationsProvider,
);

//* Helper for Apple-style transitions
//* This ensures that when we navigate (push), the new page slides in from the right
CustomTransitionPage<void> _buildPageWithTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: false,
        child: child,
      );
    },
  );
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: routeStart,
    debugLogDiagnostics: true,
    errorBuilder: (context, state) => const NotFoundPage(),
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isLoggedIn = authProvider.signedIn;
      final isAuthRoute =
          state.matchedLocation == routeLogin ||
          state.matchedLocation == routeSignup ||
          state.matchedLocation == routeForgotPassword ||
          state.matchedLocation == routeResetPassword ||
          state.matchedLocation == routeStart ||
          state.matchedLocation == routeVerifyEmail;

      if (!isLoggedIn && !isAuthRoute) return routeLogin;
      if (isLoggedIn && isAuthRoute) return routeHome;

      return null;
    },
    routes: [
      GoRoute(
        path: routeLogin,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: routeVerifyEmail,
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: VerifyEmailPage(token: token),
          );
        },
      ),
      GoRoute(
        path: routeForgotPassword,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: routeResetPassword,
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: ResetPasswordPage(token: token),
          );
        },
      ),
      GoRoute(
        path: routeSignup,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SignupPage(),
        ),
      ),
      GoRoute(
        path: routeStart,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const StartPage(),
        ),
      ),
      GoRoute(
        path: routeSettings,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SettingsPage(),
        ),
      ),
      GoRoute(
        path: routeDevices,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const DevicesPage(),
        ),
      ),
      GoRoute(
        path: routeSubscription,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SubscriptionPage(),
        ),
      ),
      GoRoute(
        path: routePlayer,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const PlayerPage(),
            fullscreenDialog: true,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  );
                },
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          // Sync navigation provider tab index with actual route (important for deep linking or web reloads)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final uri = state.uri.toString();
            final destinations = navigationProvider.destinations;
            final idx = destinations.indexWhere((d) => uri.startsWith(d.route));
            if (idx != -1 && idx != navigationProvider.currentIndex) {
              navigationProvider.setIndex(idx);
            }
          });
          return MainPage(child: child);
        },
        routes: [
          GoRoute(
            path: routeHome,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const HomePage(),
            ),
          ),
          GoRoute(
            path: routePlaylists,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const PlaylistsPage(),
            ),
            routes: [
              GoRoute(
                path: routePlaylistDetail,
                pageBuilder: (context, state) => _buildPageWithTransition(
                  context: context,
                  state: state,
                  child: const PlaylistDetailPage(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: routeEvents,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const EventsPage(),
            ),
          ),
          GoRoute(
            path: routeFriends,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const FriendsPage(),
            ),
          ),
          GoRoute(
            path: routeProfile,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const ProfilePage(),
            ),
          ),
        ],
      ),
    ],
  );
}
