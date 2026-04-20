import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';

class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final int? index = extra?['index'];
    final String name = extra?['name'] ?? 'Playlist Details';

    final tag = index != null
        ? 'playlist_cover_$index'
        : 'playlist_cover_default';

    // Fake track list for the playlist
    final List<String> fakeTracks = List.generate(
      15,
      (i) => 'Awesome Track ${i + 1}',
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {}, // Future: Open playlist editor,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: tag,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.secondary.withValues(alpha: 0.8),
                        theme.colorScheme.primary.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppDimens.xl),
                      const Icon(
                        Icons.playlist_play,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: AppDimens.sm),
                      Text(
                        name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: AppTypography.extraBold,
                        ),
                      ),
                      Text(
                        '15 songs • 45 mins',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Tracks List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.xl,
                AppDimens.xl,
                AppDimens.xl,
                AppDimens.sm,
              ),
              child: FadeIn(
                duration: const Duration(milliseconds: 600),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Up Next', style: theme.textTheme.titleLarge),
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // The Tracks
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                return StaggeredList(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.sm),
                    child: PlaceholderCard(
                      title: fakeTracks[i],
                      subtitle: 'Artist ${i + 1}',
                      leading: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSmall,
                          ),
                        ),
                        child: Icon(
                          Icons.music_note,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onTap: () {
                        // Tap a track to play it
                        context.push(routePlayer);
                      },
                    ),
                  ),
                );
              }, childCount: fakeTracks.length),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.xxl * 3)),
        ],
      ),
    );
  }
}
