import 'package:flutter/material.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Coming Soon events screen',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
