import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/providers/theme_provider.dart';

/// Day / night appearance. Lives in Account Settings, not on Home.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  bool _isDark(BuildContext context, ThemeProvider themeProv) {
    if (themeProv.themeMode == ThemeMode.dark) return true;
    if (themeProv.themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProv = context.watch<ThemeProvider>();
    final isDark = _isDark(context, themeProv);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        const SizedBox(height: AppDimens.md),
        NeumorphicInteractiveContainer(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark mode',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    Text(
                      isDark ? 'Night appearance' : 'Day appearance',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('appearance_dark_mode_switch'),
                value: isDark,
                onChanged: (value) => themeProv.setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
