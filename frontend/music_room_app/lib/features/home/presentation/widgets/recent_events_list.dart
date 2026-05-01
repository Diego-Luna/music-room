import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';

// ! Widget for rendering a list of recent live events (Apple Music style)
class RecentEventsList extends StatelessWidget {
  final List<String> events;

  const RecentEventsList({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    return Column(
      children: events.map((event) {
        return NeumorphicInteractiveContainer(
          onTap: () => context.push(routePlayer),
          margin: const EdgeInsets.symmetric(
            horizontal: AppDimens.sm,
            vertical: AppDimens.sm,
          ),
          padding: const EdgeInsets.all(AppDimens.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.all(AppDimens.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  boxShadow: tokens?.neumorphicPressedShadow,
                ),
                child: Icon(Icons.podcasts, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live Event • 2 hours ago',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              NeumorphicInteractiveContainer(
                onTap: () {}, // TODO: Action for play button
                padding: const EdgeInsets.all(AppDimens.sm),
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppDimens.xs),
            ],
          ),
        );
      }).toList(),
    );
  }
}
