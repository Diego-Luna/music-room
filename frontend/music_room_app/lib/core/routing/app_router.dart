import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/core/repositories/mock_api_repository.dart';
import 'package:music_room_app/core/repositories/rest_api_repository.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/features/auth/presentation/pages/forgot_page.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/navigation_provider.dart';
import 'package:music_room_app/providers/theme_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/socket_provider.dart';
import 'package:music_room_app/features/home/presentation/pages/home_page.dart';
import 'package:music_room_app/features/main/presentation/pages/main_screen.dart';
import 'package:music_room_app/features/playlists/presentation/pages/playlists_page.dart';
import 'package:music_room_app/features/playlists/presentation/pages/playlist_detail_page.dart';
import 'package:music_room_app/features/events/presentation/pages/events_page.dart';
import 'package:music_room_app/features/settings/presentation/pages/settings_page.dart';
import 'package:music_room_app/features/profile/presentation/pages/profile_page.dart';
import 'package:music_room_app/features/auth/presentation/pages/login_page.dart';
import 'package:music_room_app/features/auth/presentation/pages/signup_page.dart';
import 'package:music_room_app/features/auth/presentation/pages/verify_email_page.dart';
import 'package:music_room_app/features/rooms/presentation/pages/rooms_list_page.dart';
import 'package:music_room_app/features/rooms/presentation/pages/room_detail_page.dart';
import 'package:music_room_app/features/player/presentation/pages/player_page.dart';
import 'package:music_room_app/features/start/presentation/pages/start_page.dart';
import 'package:music_room_app/features/not_found/presentation/pages/not_found_page.dart';
import 'package:music_room_app/core/routing/route_names.dart';

//* Native lazy singletons
RoomRepository? _roomRepository;
ApiClient? _apiClient;
NavigationProvider? _navigationProvider;
AuthProvider? _authProvider;
ThemeProvider? _themeProvider;
EventsProvider? _eventsProvider;
PlaylistsProvider? _playlistsProvider;
RoomsProvider? _roomsProvider;
PlayerProvider? _playerProvider;
SocketProvider? _socketProvider;

//* Initialize singletons. safe to call multiple times.
void setupLocator() {
  // * Providers
  _navigationProvider ??= NavigationProvider();
  _authProvider ??= AuthProvider();
  _themeProvider ??= ThemeProvider();
  _eventsProvider ??= EventsProvider(repository: roomRepository);
  _playlistsProvider ??= PlaylistsProvider(repository: roomRepository);
  _roomsProvider ??= RoomsProvider(repository: roomRepository);
  _playerProvider ??= PlayerProvider(
    authProvider: authProvider,
    roomsProvider: roomsProvider,
  );
  _socketProvider ??= SocketProvider(
    authProvider: authProvider,
    eventsProvider: eventsProvider,
    playlistsProvider: playlistsProvider,
    roomsProvider: roomsProvider,
    playerProvider: playerProvider,
  );
}

//* Accessors to retrieve the registered singletons.

// * Resolves the correct repository based on the feature flag
ApiClient get apiClient => _apiClient ??= ApiClient();

RoomRepository get roomRepository {
  if (_roomRepository != null) return _roomRepository!;
  if (ApiConfig.useMockData) {
    _roomRepository = MockApiRepository();
  } else {
    _roomRepository = RestApiRepository(client: apiClient);
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
PlayerProvider get playerProvider => _playerProvider ??= PlayerProvider(
  authProvider: authProvider,
  roomsProvider: roomsProvider,
);

SocketProvider get socketProvider => _socketProvider ??= SocketProvider(
  authProvider: authProvider,
  eventsProvider: eventsProvider,
  playlistsProvider: playlistsProvider,
  roomsProvider: roomsProvider,
  playerProvider: playerProvider,
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
            path: routeRoomsList,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const RoomsListPage(),
            ),
            routes: [
              GoRoute(
                path: routeRoomDetail,
                pageBuilder: (context, state) => _buildPageWithTransition(
                  context: context,
                  state: state,
                  child: const RoomDetailPage(),
                ),
              ),
            ],
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
