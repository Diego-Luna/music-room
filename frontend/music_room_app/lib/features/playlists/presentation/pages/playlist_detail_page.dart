import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/models/playlist.dart';
import 'package:music_room_app/config/mock/mock_data.dart';

class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlistsProvider = context.watch<PlaylistsProvider>();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final Playlist? initialPlaylist = extra?['playlist'] as Playlist?;

    if (initialPlaylist == null) {
      return const Scaffold(body: Center(child: Text('No playlist selected')));
    }

    final playlist = playlistsProvider.playlists.firstWhere(
      (p) => p.id == initialPlaylist.id,
      orElse: () => initialPlaylist,
    );

    final tag = 'playlist_cover_${playlist.id}';

    void showAddTrackDialog() {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Song to Playlist', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppDimens.md),
                Expanded(
                  child: ListView.builder(
                    itemCount: MockData.tracks.length,
                    itemBuilder: (context, index) {
                      final track = MockData.tracks[index];
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(track.title),
                        subtitle: Text(track.artist),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                          ),
                          onPressed: () {
                            playlistsProvider.addTrack(playlist.id, track).then(
                              (_) {
                                navigator.pop();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${track.title} added to playlist!',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

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
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: showAddTrackDialog,
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
                        playlist.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: AppTypography.extraBold,
                        ),
                      ),
                      Text(
                        '${playlist.tracks.length} songs',
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
                    Text('Tracks', style: theme.textTheme.titleLarge),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: showAddTrackDialog,
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
                if (i >= playlist.tracks.length) return null;
                final playlistTrack = playlist.tracks[i];
                final track = playlistTrack.track;

                if (track == null) return const SizedBox.shrink();

                return StaggeredList(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.sm),
                    child: PlaceholderCard(
                      title: track.title,
                      subtitle: track.artist,
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
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          playlistsProvider
                              .removeTrack(playlist.id, track.id)
                              .then((_) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${track.title} removed from playlist!',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              });
                        },
                      ),
                      onTap: () {
                        context.read<PlayerProvider>().playTrack(track);
                        context.push(routePlayer);
                      },
                    ),
                  ),
                );
              }, childCount: playlist.tracks.length),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.xxl * 3)),
        ],
      ),
    );
  }
}
