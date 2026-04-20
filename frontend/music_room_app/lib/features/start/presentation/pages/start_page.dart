import 'package:flutter/material.dart';

//* Page skeleton: Start
// ! Placeholder compilable widget used for routing and visual smoke tests.
class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start')),
      body: const Center(child: Text('Start Page (placeholder)')),
    );
  }
}
