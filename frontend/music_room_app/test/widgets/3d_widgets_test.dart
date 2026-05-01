import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/widgets/interactive_3d/daft_punk_loader.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/widgets/interactive_3d/interactive_mpc.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

void main() {
  group('3D Interactive Architecture Tests', () {
    
    testWidgets('DaftPunkLoader levanta el AnimationController', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: DaftPunkLoader(size: 150),
        ),
      ));

      final loaderFinder = find.byType(DaftPunkLoader);
      expect(loaderFinder, findsOneWidget);

      final viewerFinder = find.byType(Flutter3DViewer);
      expect(viewerFinder, findsOneWidget);

      // Clear asynchronous timer stack
      await tester.pumpAndSettle(const Duration(milliseconds: 100)); // We destroy the loop by cutting it short
    });

    testWidgets('BackgroundFloaters correctly initializes Staggered Stack Elements', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BackgroundFloaters(),
        ),
      ));

      final floaters = find.byType(FloatingModel);
      expect(floaters, findsNWidgets(3));
      
      // Frame progression
      await tester.pump(const Duration(milliseconds: 500));
      // No memory leaks should occur on teardown
    });

    testWidgets('InteractiveMPC hitbox emits simulated Raycast callback', (WidgetTester tester) async {
      bool isHitboxPressed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InteractiveMpc(
            onPadInteraction: () {
              isHitboxPressed = true; // The virtual tap was successfully captured
            },
          ),
        ),
      ));

      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);

      final mpcFinder = find.byType(InteractiveMpc);
      expect(mpcFinder, findsOneWidget);

      // Verify hitboxes (Grid contains 16 gesture detectors for MPC pads)
      final hitboxes = find.byType(GestureDetector);
      expect(hitboxes, findsAtLeastNWidgets(16));

      // Tap the first invisible pad
      await tester.tap(hitboxes.first);
      await tester.pumpAndSettle();

      expect(isHitboxPressed, isTrue);
    });

  });
}
