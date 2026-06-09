import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/pages/playlists/widgets/create_playlist_dialog.dart';
import 'package:music_room_app/widgets/neumorphic_search_bar.dart';

//* Playlists page skeleton with Staggered Animations and Background Floaters.
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistsProvider>().fetchPlaylists();
    });
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreatePlaylistDialog(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppDimens.md),
            Text('No playlists yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppDimens.sm),
            Text(
              'Create a collaborative playlist and add tracks from Deezer.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimens.lg),
            PrimaryButton(
              onPressed: () => _showCreatePlaylistDialog(context),
              leading: const Icon(Icons.add),
              label: 'Create Playlist',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppDimens.md),
            Text('No results found', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppDimens.sm),
            Text(
              'No playlists match "$_searchQuery".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistsProvider = context.watch<PlaylistsProvider>();
    final isEmpty = playlistsProvider.playlists.isEmpty;
    final filteredPlaylists = playlistsProvider.playlists.where((playlist) {
      final nameMatch = playlist.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final descMatch =
          playlist.description?.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ??
          false;
      return nameMatch || descMatch;
    }).toList();
    final isSearchEmpty = _searchQuery.isNotEmpty && filteredPlaylists.isEmpty;

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
                  actions: [
                    Center(
                      child: NeumorphicIconButton(
                        icon: Icons.playlist_add,
                        tooltip: 'New Playlist',
                        onTap: () => _showCreatePlaylistDialog(context),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.lg),
                    child: NeumorphicSearchBar(
                      key: const Key('playlists_search_bar'),
                      hintText: 'Search playlists...',
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),
                if (isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else if (isSearchEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildSearchEmptyState(context),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= filteredPlaylists.length) {
                        return null;
                      }
                      final playlist = filteredPlaylists[index];

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
                    }, childCount: filteredPlaylists.length),
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
