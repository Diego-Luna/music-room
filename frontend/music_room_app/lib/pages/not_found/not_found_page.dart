import 'package:flutter/material.dart';

//* Not found page skeleton.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: const Center(child: Text('Not Found Page (placeholder)')),
    );
  }
}
