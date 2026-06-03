import 'package:flutter/material.dart';
import 'package:music_room_app/widgets/responsive_navbar.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';

// ! Main scaffold page skeleton wrapped around ShellRoute child.
class MainPage extends StatelessWidget {
  final Widget child;

  const MainPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    final bodyContent = FadeIn(
      key: ValueKey(child.hashCode),
      // Force simple animation when child route changes
      duration: const Duration(milliseconds: 300),
      child: child,
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
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
          Expanded(child: bodyContent),
        ],
      ),
    );
  }
}
