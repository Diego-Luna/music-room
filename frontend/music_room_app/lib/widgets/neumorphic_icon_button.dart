import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';

// * NeumorphicIconButton
// A reusable icon button adapted to our Neumorphic design system, supporting
// tooltips, active states, and badges.
class NeumorphicIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final String? tooltip;
  final double iconSize;
  final bool isForcedPressed;
  final int badgeCount;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const NeumorphicIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor,
    this.tooltip,
    this.iconSize = 24.0,
    this.isForcedPressed = false,
    this.badgeCount = 0,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget button = NeumorphicInteractiveContainer(
      onTap: onTap,
      isForcedPressed: isForcedPressed,
      margin: margin ?? const EdgeInsets.all(AppDimens.sm),
      padding: padding ?? const EdgeInsets.all(AppDimens.sm),
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Icon(
        icon,
        color: iconColor ?? theme.colorScheme.primary,
        size: iconSize,
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    if (badgeCount > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return button;
  }
}
