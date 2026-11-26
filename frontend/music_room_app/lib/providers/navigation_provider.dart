import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';

class NavDestination {
  final String label;
  final IconData icon;
  final String route;

  const NavDestination({
    required this.label,
    required this.icon,
    required this.route,
  });
}

//* Active index and the list of top-level destinations.
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  // Default destinations for the bottom/top navigation.
  static const List<NavDestination> _defaultDestinations = [
    NavDestination(label: 'Home', icon: Icons.home, route: routeHome),
    NavDestination(
      label: 'Playlists',
      icon: Icons.queue_music,
      route: routePlaylists,
    ),
    NavDestination(label: 'Events', icon: Icons.event, route: routeEvents),
    NavDestination(
      label: 'Inbox',
      icon: Icons.notifications_none_rounded,
      route: routeFriends,
    ),
    NavDestination(label: 'Profile', icon: Icons.person, route: routeProfile),
  ];

  List<NavDestination> get destinations =>
      List.unmodifiable(_defaultDestinations);

  int get currentIndex => _currentIndex;

  String get currentRoute => destinations[_currentIndex].route;

  void setIndex(int index) {
    if (index < 0 || index >= destinations.length) return;
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// Called by the responsive navbar when a tab is tapped.
  void navigateToIndex(BuildContext context, int index) {
    if (index < 0 || index >= destinations.length) return;
    final route = destinations[index].route;
    setIndex(index);
    context.go(route);

    // * StatefulShellRoute keeps tabs mounted so initState() does not re-run
    // * on tab switch; refresh lists so deleted rooms do not linger as ghosts.
    if (route == routePlaylists) {
      try {
        unawaited(context.read<PlaylistsProvider>().fetchPlaylists());
      } on ProviderNotFoundException catch (e) {
        debugPrint('Skipping playlists refresh on tab switch: $e');
      }
    } else if (route == routeEvents) {
      try {
        unawaited(context.read<EventsProvider>().fetchEvents());
      } on ProviderNotFoundException catch (e) {
        debugPrint('Skipping events refresh on tab switch: $e');
      }
    }
  }
}
