import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';

/// A reusable container that implements Neumorphism interactivity.
/// It switches between raised and pressed shadows and adds a scale effect.
class NeumorphicInteractiveContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Clip clipBehavior;
  final bool isForcedPressed;

  const NeumorphicInteractiveContainer({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.decoration,
    this.padding,
    this.margin,
    this.clipBehavior = Clip.none,
    this.isForcedPressed = false,
  });

  @override
  State<NeumorphicInteractiveContainer> createState() =>
      _NeumorphicInteractiveContainerState();
}

class _NeumorphicInteractiveContainerState
    extends State<NeumorphicInteractiveContainer> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
    widget.onTap!();
  }

  void _handleTapCancel() {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();
    final bool isActuallyPressed = _isPressed || widget.isForcedPressed;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: widget.duration,
        margin:
            widget.margin ??
            tokens?.shadowSafeMargin ??
            const EdgeInsets.all(AppDimens.md),
        padding: widget.padding,
        clipBehavior: widget.clipBehavior,
        decoration: (widget.decoration ?? const BoxDecoration()).copyWith(
          color: theme.colorScheme.surface,
          boxShadow: isActuallyPressed
              ? tokens?.neumorphicPressedShadow
              : tokens?.neumorphicShadow,
          border: Border.all(color: theme.scaffoldBackgroundColor, width: 0.5),
        ),
        child: widget.child,
      ),
    );
  }
}
