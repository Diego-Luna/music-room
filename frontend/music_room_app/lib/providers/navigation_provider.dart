import 'package:flutter/material.dart';
import 'package:music_room_app/routes/route_names.dart';

// Todo: move the type a new folder `models/` but in a dub fodler fot the app flow
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

// * Active index and the list of top-level destinations.
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  // Default destinations for the bottom/top navigation.
  static const List<NavDestination> _defaultDestinations = [
    NavDestination(label: 'Home', icon: Icons.home, route: routeHome),
    NavDestination(label: 'Playlists', icon: Icons.queue_music, route: routePlaylists),
    NavDestination(label: 'Events', icon: Icons.event, route: routeEvents),
    NavDestination(label: 'Rooms', icon: Icons.meeting_room, route: routeRoomsList),
    NavDestination(label: 'Profile', icon: Icons.person, route: routeProfile),
  ];

  // Expose an immutable view of destinations.
  List<NavDestination> get destinations => List.unmodifiable(_defaultDestinations);

  int get currentIndex => _currentIndex;

  String get currentRoute => destinations[_currentIndex].route;

  // Update the active index and notify listeners.
  void setIndex(int index) {
    if (index < 0 || index >= destinations.length) return;
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  // * return the route for a destination index.
  String routeForIndex(int index) => destinations[index].route;

  /// Navigate to a destination by index. Uses `pushReplacementNamed` to avoid stacking pages.
  void navigateToIndex(BuildContext context, int index) {
    if (index < 0 || index >= destinations.length) return;
    final current = ModalRoute.of(context)?.settings.name;

    // If we're already on the main host route, just update the index so the
    // host `MainScreen` swaps the visible child — this avoids navigation churn.
    if (current == routeMain) {
      setIndex(index);
      return;
    }

    // If we're on a different route (detail page, etc.), navigate back to the
    // main host and set the index. We use pushReplacement to avoid stacking
    // multiple main hosts on the stack.
    Navigator.of(context).pushReplacementNamed(routeMain);
    setIndex(index);
  }
}
