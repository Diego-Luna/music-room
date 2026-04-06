import 'package:flutter/material.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/navigation_provider.dart';
import 'package:music_room_app/pages/home/home_page.dart';
import 'package:music_room_app/pages/main/main_screen.dart';
import 'package:music_room_app/pages/playlists/playlists_page.dart';
import 'package:music_room_app/pages/events/events_page.dart';
import 'package:music_room_app/pages/settings/settings_page.dart';
import 'package:music_room_app/pages/profile/profile_page.dart';
import 'package:music_room_app/pages/auth/login_page.dart';
import 'package:music_room_app/pages/auth/signup_page.dart';
import 'package:music_room_app/pages/rooms/rooms_list_page.dart';
import 'package:music_room_app/pages/rooms/room_detail_page.dart';
import 'package:music_room_app/pages/start/start_page.dart';
import 'package:music_room_app/pages/splash/splash_page.dart';
import 'package:music_room_app/pages/not_found/not_found_page.dart';
import 'package:music_room_app/routes/route_names.dart';

// * Native lazy singletons
NavigationProvider? _navigationProvider;
AuthProvider? _authProvider;

// * Initialize singletons. Idempotent — safe to call multiple times.
void setupLocator() {
  if (_navigationProvider != null && _authProvider != null) return;
  _navigationProvider ??= NavigationProvider();
  _authProvider ??= AuthProvider();
}

// * Accessors to retrieve the registered singletons.
NavigationProvider get navigationProvider => _navigationProvider ??= NavigationProvider();
AuthProvider get authProvider => _authProvider ??= AuthProvider();

class AppRouter {
  static Map<String, WidgetBuilder> get routes => {
        routeSplash: (_) => const SplashPage(),
        routeMain: (_) => const MainPage(),
        routeStart: (_) => const StartPage(),
        routeHome: (_) => const HomePage(),
        routePlaylists: (_) => const PlaylistsPage(),
        routeEvents: (_) => const EventsPage(),
        routeSettings: (_) => const SettingsPage(),
        routeProfile: (_) => const ProfilePage(),
        routeLogin: (_) => const LoginPage(),
        routeSignup: (_) => const SignupPage(),
        routeRoomsList: (_) => const RoomsListPage(),
        routeRoomDetail: (_) => const RoomDetailPage(),
        routeNotFound: (_) => const NotFoundPage(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }
    return MaterialPageRoute(builder: (_) => const NotFoundPage());
  }
}
