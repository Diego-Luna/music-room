import 'package:flutter/material.dart';

//* Room detail skeleton.
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Room Detail')),
      body: const Center(child: Text('Room Detail Page (placeholder)')),
    );
  }
}
