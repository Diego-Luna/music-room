import 'package:flutter/material.dart';
import 'package:music_room_app/theme/app_theme.dart';

class PlaceholderCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onTap;
  final double? height;

  const PlaceholderCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onTap,
    this.height = 64.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double imageSize = height ?? 64.0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMedium)),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              if (leading != null)
                SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: leading,
                )
              else
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha((0.08 * 255).round()),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  ),
                  child: Icon(Icons.music_note, color: theme.colorScheme.primary),
                ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppDimens.xs),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
