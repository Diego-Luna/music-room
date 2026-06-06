import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/models/room.dart';

// ! Widget for rendering a horizontal list of personalized mixes (Apple/Youtube Music style)
class QuickPicksCarousel extends StatelessWidget {
  final List<Room> mixes;

  const QuickPicksCarousel({super.key, required this.mixes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
        scrollDirection: Axis.horizontal,
        itemCount: mixes.length,
        separatorBuilder: (context, _) => const SizedBox(width: AppDimens.md),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 156,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NeumorphicInteractiveContainer(
                    onTap: () {
                      context.go(routePlaylists);
                    },
                    margin: const EdgeInsets.all(AppDimens.sm),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusMedium,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.queue_music,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.sm),
                Text(
                  mixes[index].name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: AppTypography.semibold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Collaborative Playlist',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
