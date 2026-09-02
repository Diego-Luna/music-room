import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/safe_navigation.dart';

void main() {
  group('SafeNavigationExtension Tests', () {
    testWidgets('safePop pops when previous route exists in stack', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/first',
        routes: [
          GoRoute(
            path: '/first',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.push('/second'),
                child: const Text('Go to Second'),
              ),
            ),
          ),
          GoRoute(
            path: '/second',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.safePop(fallbackRoute: '/first'),
                child: const Text('Back'),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(find.text('Go to Second'), findsOneWidget);

      await tester.tap(find.text('Go to Second'));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Go to Second'), findsOneWidget);
    });

    testWidgets('safePop navigates to fallbackRoute when stack is empty without throwing', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/second',
        routes: [
          GoRoute(
            path: '/first',
            builder: (context, state) => const Scaffold(
              body: Text('First Screen'),
            ),
          ),
          GoRoute(
            path: '/second',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.safePop(fallbackRoute: '/first'),
                child: const Text('Back'),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(find.text('Back'), findsOneWidget);

      // Tapping back should NOT throw "There is nothing to pop"
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('First Screen'), findsOneWidget);
    });
  });
}
