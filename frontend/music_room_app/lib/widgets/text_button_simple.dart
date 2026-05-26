import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';

// * Custom TextButtonSimple
// * A minimal clickable text button with no padding or extra layout.
class TextButtonSimple extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final FontWeight? fontWeight;

  const TextButtonSimple({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // * Base style matching the requested bodyMedium styling.
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: color ?? theme.colorScheme.secondary,
      fontWeight: fontWeight ?? AppTypography.bold,
    );

    return MouseRegion(
      cursor: onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onPressed,
        child: Text(text, style: baseStyle),
      ),
    );
  }
}
