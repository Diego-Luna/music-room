import 'package:flutter/material.dart';

//* Events page skeleton.
class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: const Center(child: Text('Events Page (placeholder)')),
    );
  }
}
