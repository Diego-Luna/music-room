import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';

//* PlaceholderCard
// A reusable card component upgraded to use Neumorphism.
class PlaceholderCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double? height;
  final int maxTitleLines;
  final int maxSubtitleLines;

  const PlaceholderCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.height = 64.0,
    this.maxTitleLines = 1,
    this.maxSubtitleLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();
    final double imageSize = height ?? 64.0;

    return NeumorphicInteractiveContainer(
      onTap: onTap,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius:
            tokens?.cardRadius ?? BorderRadius.circular(AppDimens.radiusMedium),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          if (leading != null)
            SizedBox(width: imageSize, height: imageSize, child: leading)
          else
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                boxShadow: tokens?.neumorphicPressedShadow,
              ),
              child: Icon(Icons.music_note, color: theme.colorScheme.primary),
            ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                  maxLines: maxTitleLines,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppDimens.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                    maxLines: maxSubtitleLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppDimens.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
