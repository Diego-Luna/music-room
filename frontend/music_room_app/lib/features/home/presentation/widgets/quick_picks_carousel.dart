import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/animated_scale_button.dart';

// ! Widget for rendering a horizontal list of personalized mixes (Apple/Youtube Music style)
class QuickPicksCarousel extends StatelessWidget {
  final List<String> mixes;

  const QuickPicksCarousel({super.key, required this.mixes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
        scrollDirection: Axis.horizontal,
        itemCount: mixes.length,
        separatorBuilder: (context, _) => const SizedBox(width: AppDimens.md),
        itemBuilder: (context, index) {
          return AnimatedScaleButton(
            onPressed: () => context.push(routePlayer),
            scaleDown: 0.95,
            child: SizedBox(
              width: 156,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(
                        AppDimens.sm,
                      ), // Added margin for shadow rendering
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMedium,
                        ),
                        boxShadow: Theme.of(
                          context,
                        ).extension<AppDesignTokens>()?.neumorphicShadow,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.music_note,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.sm),
                  Text(
                    mixes[index],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: AppTypography.semibold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Based on your taste',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
