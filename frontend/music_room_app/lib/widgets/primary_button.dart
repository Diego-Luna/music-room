import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/animated_scale_button.dart';

//* PrimaryButton
// Reusable button adapted to our Neumorphic design system.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    final Widget content = isLoading
        ? const SizedBox(
            height: AppDimens.iconMedium,
            width: AppDimens.iconMedium,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppDimens.sm),
              ],
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: AppTypography.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppDimens.touchTargetMin),
      child: AnimatedScaleButton(
        onPressed: isLoading ? null : onPressed,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            boxShadow: tokens?.neumorphicShadow,
          ),
          child: Padding(
            padding:
                padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppDimens.lg,
                  vertical: AppDimens.md,
                ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
