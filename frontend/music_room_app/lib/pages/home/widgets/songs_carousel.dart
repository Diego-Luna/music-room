import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/models/track.dart';

// ! Widget for rendering a horizontal list of personalized songs
class SongsCarousel extends StatelessWidget {
  final List<Track> songs;

  const SongsCarousel({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
        scrollDirection: Axis.horizontal,
        itemCount: songs.length,
        separatorBuilder: (context, _) => const SizedBox(width: AppDimens.md),
        itemBuilder: (context, index) {
          final track = songs[index];
          return SizedBox(
            width: 156,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NeumorphicInteractiveContainer(
                    onTap: () {
                      context.read<PlayerProvider>().playTrack(
                        track,
                        queue: songs,
                        index: index,
                      );
                      context.push(routePlayer);
                    },
                    margin: const EdgeInsets.all(AppDimens.sm),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusMedium,
                      ),
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
                  track.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: AppTypography.semibold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  track.artist,
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
