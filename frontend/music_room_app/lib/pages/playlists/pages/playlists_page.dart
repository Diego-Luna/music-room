import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/providers/playlists_provider.dart';

//* Playlists page skeleton with Staggered Animations and Background Floaters.
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistsProvider>().fetchPlaylists();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlistsProvider = context.watch<PlaylistsProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 3D Background entities (Floating tape/guitar, etc.)
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),

          if (playlistsProvider.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: const Text('Playlists'),
                  centerTitle: true,
                  floating: true,
                  pinned: false,
                  backgroundColor: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= playlistsProvider.playlists.length)
                      return null;
                    final playlist = playlistsProvider.playlists[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.lg,
                        vertical: AppDimens.sm / 2,
                      ),
                      child: StaggeredList(
                        index: index,
                        child: PlaceholderCard(
                          title: playlist.name,
                          subtitle:
                              'Collaborative Playlist • ${playlist.tracks.length} songs',
                          leading: Hero(
                            tag: 'playlist_cover_${playlist.id}',
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
                            extra: {'playlist': playlist},
                          ),
                        ),
                      ),
                    );
                  }, childCount: playlistsProvider.playlists.length),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimens.xxl * 3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
