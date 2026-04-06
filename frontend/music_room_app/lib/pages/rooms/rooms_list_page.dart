import 'package:flutter/material.dart';

//* Rooms list skeleton.
class RoomsListPage extends StatelessWidget {
  const RoomsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      body: const Center(child: Text('Rooms List Page (placeholder)')),
    );
  }
}
