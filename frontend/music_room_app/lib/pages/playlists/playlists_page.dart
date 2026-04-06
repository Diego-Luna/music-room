import 'package:flutter/material.dart';

//* Playlists page skeleton.
class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: const Center(child: Text('Playlists Page (placeholder)')),
    );
  }
}
