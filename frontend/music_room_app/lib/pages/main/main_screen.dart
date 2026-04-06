import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/pages/events/events_page.dart';
import 'package:music_room_app/pages/home/home_page.dart';
import 'package:music_room_app/pages/playlists/playlists_page.dart';
import 'package:music_room_app/pages/profile/profile_page.dart';
import 'package:music_room_app/pages/rooms/rooms_list_page.dart';
import 'package:music_room_app/providers/navigation_provider.dart';
import 'package:music_room_app/widgets/responsive_navbar.dart';
import 'package:music_room_app/helper/animations/slide_animation.dart';

//* Main scaffold page skeleton.
class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final pages = <Widget>[
      const HomePage(),
      const PlaylistsPage(),
      const EventsPage(),
      const RoomsListPage(),
      const ProfilePage(),
    ];
    final safeIndex = nav.currentIndex.clamp(0, pages.length - 1).toInt();
    final isMobile = MediaQuery.of(context).size.width < 700;

    final bodyContent = SlideIn(
      key: ValueKey(safeIndex),
      beginOffset: const Offset(0, 30),
      duration: const Duration(milliseconds: 500),
      child: pages[safeIndex],
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: const SizedBox.shrink(),
          elevation: 0,
        ),
        body: bodyContent,
        bottomNavigationBar: const ResponsiveNavbar(),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          const ResponsiveNavbar(),
          Expanded(
            child: bodyContent,
          ),
        ],
      ),
    );
  }
}
