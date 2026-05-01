import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/widgets/interactive_3d/daft_punk_loader.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/widgets/interactive_3d/interactive_mpc.dart';

void main() {
  group('3D Interactive Architecture Tests', () {
    testWidgets('DaftPunkLoader renders placeholder in tests', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DaftPunkLoader(size: 150))),
      );

      final loaderFinder = find.byType(DaftPunkLoader);
      expect(loaderFinder, findsOneWidget);

      // Should find the placeholder key instead of Flutter3DViewer
      final placeholderFinder = find.byKey(const Key('3d_placeholder_loader'));
      expect(placeholderFinder, findsOneWidget);
    });

    testWidgets('BackgroundFloaters renders placeholders in tests', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BackgroundFloaters())),
      );

      final floaters = find.byType(FloatingModel);
      expect(floaters, findsNWidgets(3));

      final placeholders = find.byKey(const Key('3d_placeholder_floater'));
      expect(placeholders, findsNWidgets(3));
    });

    testWidgets('InteractiveMPC hitbox emits simulated Raycast callback', (
      WidgetTester tester,
    ) async {
      bool isHitboxPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveMpc(
              onPadInteraction: () {
                isHitboxPressed =
                    true; // The virtual tap was successfully captured
              },
            ),
          ),
        ),
      );

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
