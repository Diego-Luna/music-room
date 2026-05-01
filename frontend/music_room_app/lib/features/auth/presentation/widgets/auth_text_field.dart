import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';

//* AuthTextField
// Uses an inner neumorphic shadow effect (pressed shadow) to look like an inset field.
class AuthTextField extends StatelessWidget {
  final String hintText;
  final IconData icon;
  final bool isPassword;

  const AuthTextField({
    super.key,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    return Container(
      margin:
          tokens?.shadowSafeMargin ??
          const EdgeInsets.symmetric(vertical: AppDimens.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        boxShadow: tokens?.neumorphicPressedShadow,
      ),
      child: TextField(
        obscureText: isPassword,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: theme.disabledColor,
          ),
          prefixIcon: Icon(icon, color: theme.colorScheme.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: AppDimens.lg,
          ),
        ),
      ),
    );
  }
}
