import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:music_room_app/providers/theme_provider.dart';

void main() {
  setUp(() async {
    Hive.init('./.dart_tool/test_hive_theme_provider');
    if (!Hive.isBoxOpen('app_settings')) {
      await Hive.openBox('app_settings');
    }
    await Hive.box('app_settings').clear();
  });

  tearDown(() async {
    if (Hive.isBoxOpen('app_settings')) {
      await Hive.box('app_settings').clear();
    }
  });

  test('setThemeMode is still dark after a new provider is created', () {
    final first = ThemeProvider();
    first.setThemeMode(ThemeMode.dark);

    final reloaded = ThemeProvider();
    expect(reloaded.themeMode, ThemeMode.dark);
  });

  test('a fresh install follows the system theme', () {
    expect(ThemeProvider().themeMode, ThemeMode.system);
  });
}
