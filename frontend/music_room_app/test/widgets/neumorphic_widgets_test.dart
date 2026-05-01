import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/core/theme/app_theme.dart';

void main() {
  group('Neumorphic Widgets Tests', () {
    testWidgets(
      'NeumorphicInteractiveContainer handles tap interaction without scaling',
      (WidgetTester tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: NeumorphicInteractiveContainer(
                onTap: () => tapped = true,
                child: const Text('Test'),
              ),
            ),
          ),
        );

        final containerFinder = find.byType(NeumorphicInteractiveContainer);
        expect(containerFinder, findsOneWidget);

        // Tap down
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.touch,
        );
        await gesture.addPointer(location: tester.getCenter(containerFinder));
        await gesture.down(tester.getCenter(containerFinder));
        await tester.pump(const Duration(milliseconds: 50));

        // Verify it's still there and hasn't changed size (no AnimatedScale)
        expect(find.byType(AnimatedScale), findsNothing);

        // Release
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      },
    );

    testWidgets('PrimaryButton renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrimaryButton(label: 'Click Me', onPressed: () {}),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      expect(find.byType(NeumorphicInteractiveContainer), findsOneWidget);
    });

    testWidgets('PlaceholderCard renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PlaceholderCard(title: 'Song Title', subtitle: 'Artist Name'),
          ),
        ),
      );

      expect(find.text('Song Title'), findsOneWidget);
      expect(find.text('Artist Name'), findsOneWidget);
      expect(find.byType(NeumorphicInteractiveContainer), findsOneWidget);
    });
  });
}
