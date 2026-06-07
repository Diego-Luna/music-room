import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';

// * Carved/inset neumorphic surface used to wrap text inputs and dropdowns,
// * so they look pressed into the background (the app's input language).
class NeumorphicInset extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const NeumorphicInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppDimens.md,
      vertical: AppDimens.xs,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        boxShadow: tokens?.neumorphicPressedShadow,
      ),
      child: child,
    );
  }
}

// * Labelled neumorphic text field.
class NeumorphicTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool autofocus;

  const NeumorphicTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.xs,
            bottom: AppDimens.xs,
          ),
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        NeumorphicInset(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppDimens.sm,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// * Labelled neumorphic dropdown.
class NeumorphicDropdown<T> extends StatelessWidget {
  final T value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const NeumorphicDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.xs,
            bottom: AppDimens.xs,
          ),
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        NeumorphicInset(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// * Raised neumorphic tile carrying a title/subtitle and a toggle switch.
class NeumorphicToggleTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const NeumorphicToggleTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        boxShadow: tokens?.neumorphicShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
