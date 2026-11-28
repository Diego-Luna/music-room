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
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/pages/playlists/widgets/create_playlist_dialog.dart';
import 'package:music_room_app/widgets/neumorphic_search_bar.dart';
import 'package:music_room_app/widgets/shelf_chip.dart';
import 'package:music_room_app/providers/subscription_provider.dart';
import 'package:music_room_app/models/room.dart';

enum _PlaylistShelf { yours, joined, discover }

//* Playlists page. One list, split into the caller's own rooms, rooms they
//* joined, and public rooms they have not joined.
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  String _searchQuery = '';
  _PlaylistShelf _shelf = _PlaylistShelf.yours;

  String? _currentUserId(BuildContext context) {
    try {
      return context.watch<AuthProvider>().user?.id;
    } on ProviderNotFoundException {
      return null;
    }
  }

  bool _onShelf(Room playlist, String? userId) {
    switch (_shelf) {
      case _PlaylistShelf.yours:
        return playlist.ownedBy(userId);
      case _PlaylistShelf.joined:
        return playlist.joinedBy(userId);
      case _PlaylistShelf.discover:
        return !playlist.ownedBy(userId) && playlist.myRole == null;
    }
  }

  String _relationLabel(Room playlist, String? userId) {
    if (playlist.ownedBy(userId)) return 'Yours';
    switch (playlist.myRole) {
      case 'ADMIN':
      case 'MEMBER':
        return 'Member';
      default:
        return 'Public';
    }
  }

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

  void _onCreateTap(BuildContext context) {
    final isPremium = SubscriptionProvider.isPremiumOf(context, listen: false);
    if (isPremium) {
      _showCreatePlaylistDialog(context);
    } else {
      context.push(routeSubscription);
    }
  }

  Widget _buildEmptyState(BuildContext context, {required bool isPremium}) {
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
              isPremium
                  ? 'Create a collaborative playlist and add tracks from Deezer.'
                  : 'Creating playlists is a Premium feature. '
                        'You can still join and edit other playlists.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimens.lg),
            PrimaryButton(
              onPressed: () => _onCreateTap(context),
              leading: Icon(isPremium ? Icons.add : Icons.workspace_premium),
              label: isPremium ? 'Create Playlist' : 'Upgrade to Premium',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedHeader(BuildContext context, {required bool isPremium}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          primary: true,
          automaticallyImplyLeading: false,
          centerTitle: true,
          toolbarHeight: 76,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          forceMaterialTransparency: true,
          title: const Text('Playlists'),
          actions: [
            Center(
              child: NeumorphicIconButton(
                icon: Icons.playlist_add,
                tooltip: isPremium ? 'New Playlist' : 'Upgrade to Premium',
                onTap: () => _onCreateTap(context),
              ),
            ),
          ],
        ),
        _buildShelves(context),
        Padding(
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
      ],
    );
  }

  Widget _buildShelves(BuildContext context) {
    const shelves = <(_PlaylistShelf, String, Key)>[
      (_PlaylistShelf.yours, 'Yours', Key('playlists_tab_yours')),
      (_PlaylistShelf.joined, 'Joined', Key('playlists_tab_joined')),
      (_PlaylistShelf.discover, 'Discover', Key('playlists_tab_discover')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.md,
        AppDimens.lg,
        0,
      ),
      child: Row(
        children: [
          for (var i = 0; i < shelves.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimens.sm),
            Expanded(
              child: ShelfChip(
                key: shelves[i].$3,
                label: shelves[i].$2,
                selected: _shelf == shelves[i].$1,
                onTap: () => setState(() => _shelf = shelves[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShelfEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (_shelf) {
      _PlaylistShelf.yours => 'You have not created a playlist yet.',
      _PlaylistShelf.joined => 'You have not joined a playlist yet.',
      _PlaylistShelf.discover => 'No public playlists to discover.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
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
    final userId = _currentUserId(context);
    final isPremium = SubscriptionProvider.isPremiumOf(context);
    final isEmpty = playlistsProvider.playlists.isEmpty;
    final filteredPlaylists = playlistsProvider.playlists.where((playlist) {
      if (!_onShelf(playlist, userId)) return false;
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
    final isShelfEmpty =
        _searchQuery.isEmpty && filteredPlaylists.isEmpty && !isEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 3D Background entities (Floating tape/guitar, etc.)
          const Opacity(opacity: 0.4, child: BackgroundFloaters(noteTop: 8)),

          if (playlistsProvider.isLoading && isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                _buildPinnedHeader(context, isPremium: isPremium),
                Expanded(
                  child: Stack(
                    children: [
                      CustomScrollView(
                        slivers: [
                          if (isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(
                                context,
                                isPremium: isPremium,
                              ),
                            )
                          else if (isSearchEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildSearchEmptyState(context),
                            )
                          else if (isShelfEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildShelfEmptyState(context),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
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
                                          '${_relationLabel(playlist, userId)} • ${playlist.tracks.length} songs',
                                      leading: Hero(
                                        tag: 'playlist_cover_${playlist.id}',
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              AppDimens.radiusMedium,
                                            ),
                                            boxShadow: Theme.of(context)
                                                .extension<AppDesignTokens>()
                                                ?.neumorphicPressedShadow,
                                          ),
                                          child: Icon(
                                            Icons.playlist_play,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
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
                          if (!isEmpty && !isSearchEmpty && !isShelfEmpty)
                            const SliverToBoxAdapter(
                              child: SizedBox(height: AppDimens.xxl * 3),
                            ),
                        ],
                      ),
                      if (playlistsProvider.isLoading)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
