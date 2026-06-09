import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/neumorphic_search_bar.dart';

void main() {
  group('NeumorphicSearchBar Tests', () {
    testWidgets('Renders correctly with search icon and placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: NeumorphicSearchBar(
              onChanged: (_) {},
              hintText: 'Search playlists...',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Search playlists...'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('Triggers callback and shows clear button', (tester) async {
      String result = '';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: NeumorphicSearchBar(onChanged: (val) => result = val),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Lounge Music');
      await tester.pumpAndSettle();

      expect(result, 'Lounge Music');
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(result, '');
      expect(find.text('Lounge Music'), findsNothing);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('Sanitizes input by blocking denied injection characters', (
      tester,
    ) async {
      String result = '';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: NeumorphicSearchBar(onChanged: (val) => result = val),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '<script>Test*');
      await tester.pumpAndSettle();

      // Denied chars: < > * should be filtered out by FilteringTextInputFormatter and listener
      expect(result, 'scriptTest');
    });

    testWidgets('Truncates input at 50 characters maximum', (tester) async {
      String result = '';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: NeumorphicSearchBar(onChanged: (val) => result = val),
          ),
        ),
      );

      final longInput = 'A' * 60;
      await tester.enterText(find.byType(TextField), longInput);
      await tester.pumpAndSettle();

      expect(result.length, 50);
      expect(result, 'A' * 50);
    });
  });
}
