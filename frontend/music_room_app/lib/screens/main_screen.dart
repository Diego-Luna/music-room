import 'package:flutter/material.dart';
import 'package:music_room_app/screens/events_screen.dart';
import 'package:music_room_app/screens/home_page.dart';
import 'package:music_room_app/screens/playlists_screen.dart';
import 'package:music_room_app/screens/settings_screen.dart';
import 'package:music_room_app/widgets/responsive_navbar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<NavItem> navItems = [
    NavItem(label: 'Home', icon: Icons.home, index: 0),
    NavItem(label: 'Events', icon: Icons.event, index: 1),
    NavItem(label: 'Playlists', icon: Icons.playlist_play, index: 2),
    NavItem(label: 'Settings', icon: Icons.settings, index: 3),
  ];

  late final List<Widget> screens = [
    const HomeScreen(),
    const EventsScreen(),
    const PlaylistsScreen(),
    const SettingsScreen(),
  ];

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Scaffold(
        body: screens[_currentIndex],
        bottomNavigationBar: ResponsiveNavbar(
          currentIndex: _currentIndex,
          onTap: _onNavTap,
          items: navItems,
          isMobile: true,
        ),
      );
    }

    // Web layout with top navbar
    return Scaffold(
      body: Column(
        children: [
          ResponsiveNavbar(
            currentIndex: _currentIndex,
            onTap: _onNavTap,
            items: navItems,
            isMobile: false,
          ),
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: screens[_currentIndex],
            ),
          ),
        ],
      ),
    );
    
  }
}
