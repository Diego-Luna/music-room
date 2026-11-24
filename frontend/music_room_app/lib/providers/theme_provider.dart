import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  static const _settingsBoxName = 'app_settings';
  static const _themeModeKey = 'theme_mode';

  ThemeMode _themeMode;

  ThemeProvider() : _themeMode = _readStored();

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    setThemeMode(
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _persist();
    notifyListeners();
  }

  static ThemeMode _readStored() {
    if (!Hive.isBoxOpen(_settingsBoxName)) return ThemeMode.system;
    final raw = Hive.box(_settingsBoxName).get(_themeModeKey);
    return switch (raw) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  void _persist() {
    if (!Hive.isBoxOpen(_settingsBoxName)) return;
    Hive.box(_settingsBoxName).put(_themeModeKey, _themeMode.name);
  }
}
