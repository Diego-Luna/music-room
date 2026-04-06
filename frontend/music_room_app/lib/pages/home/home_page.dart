import 'package:flutter/material.dart';
import 'package:music_room_app/helper/animations/fade_animation.dart';

/// Home page skeleton used as placeholder for routing and UI iterations.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: FadeIn(
          child: Text(
            'Home Page (placeholder)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}
