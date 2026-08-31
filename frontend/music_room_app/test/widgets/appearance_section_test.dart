import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/pages/settings/widgets/appearance_section.dart';
import 'package:music_room_app/providers/theme_provider.dart';

void main() {
  testWidgets('AppearanceSection switch toggles light and dark', (
    tester,
  ) async {
    final themeProv = ThemeProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProv,
        child: Consumer<ThemeProvider>(
          builder: (context, prov, _) {
            return MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: prov.themeMode,
              home: const Scaffold(body: AppearanceSection()),
            );
          },
        ),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);

    await tester.tap(find.byKey(const Key('appearance_dark_mode_switch')));
    await tester.pumpAndSettle();

    expect(themeProv.themeMode, ThemeMode.dark);
    expect(find.text('Night appearance'), findsOneWidget);

    await tester.tap(find.byKey(const Key('appearance_dark_mode_switch')));
    await tester.pumpAndSettle();

    expect(themeProv.themeMode, ThemeMode.light);
    expect(find.text('Day appearance'), findsOneWidget);
  });
}
