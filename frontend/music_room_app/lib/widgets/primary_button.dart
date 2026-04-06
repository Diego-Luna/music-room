import 'package:flutter/material.dart';
import 'package:music_room_app/theme/app_theme.dart';

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
    final Widget content = isLoading
        ? SizedBox(
            height: AppDimens.iconMedium,
            width: AppDimens.iconMedium,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
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
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
            ],
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppDimens.touchTargetMin),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: AppTheme.primaryButtonStyle,
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: content,
        ),
      ),
    );
  }
}
