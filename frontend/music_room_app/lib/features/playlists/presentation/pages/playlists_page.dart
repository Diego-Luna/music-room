import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';

//* Playlists page skeleton with Staggered Animations and Background Floaters.
class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> fakePlaylists = List.generate(
      8,
      (i) => 'My Playlist ${i + 1}',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 3D Background entities (Floating tape/guitar, etc.)
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),

          CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Playlists'),
                centerTitle: true,
                floating: true, // Disappears on scroll!
                pinned: false,
                backgroundColor: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.8),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.lg,
                      vertical: AppDimens.sm / 2,
                    ),
                    child: StaggeredList(
                      index: index,
                      child: PlaceholderCard(
                        title: fakePlaylists[index],
                        subtitle: 'Collaborative Playlist',
                        leading: Hero(
                          tag: 'playlist_cover_$index',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusMedium,
                              ),
                              boxShadow: Theme.of(context)
                                  .extension<AppDesignTokens>()
                                  ?.neumorphicPressedShadow,
                            ),
                            child: Icon(
                              Icons.playlist_play,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        onTap: () => context.go(
                          '$routePlaylists/$routePlaylistDetail',
                          extra: {'index': index, 'name': fakePlaylists[index]},
                        ),
                      ),
                    ),
                  );
                }, childCount: fakePlaylists.length),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: AppDimens.xxl * 3,
                ), // Ensure space at bottom
              ),
            ],
          ),
        ],
      ),
    );
  }
}
