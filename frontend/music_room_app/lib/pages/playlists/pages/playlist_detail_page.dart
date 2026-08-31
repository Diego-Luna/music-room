import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/socket_provider.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/widgets/track_search_sheet.dart';
import 'package:music_room_app/widgets/room_members_sheet.dart';
import 'package:music_room_app/widgets/edit_room_dialog.dart';
import 'package:music_room_app/pages/events/widgets/invite_friend_dialog.dart';

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  String? _roomId;
  late SocketProvider _socketProvider;

  // * Locally-mirrored track order so a drag reorders instantly. While a local
  //   drag is in flight we keep that order; otherwise we follow the provider
  //   (live move/add from another user, or the post-move fetch).
  List<Track> _orderedTracks = [];
  bool _forceResync = false;
  bool _isLocalReorder = false;

  // * newIndex is adjusted here for standard Flutter onReorder semantics.
  Future<void> _onReorder(Room playlist, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (newIndex == oldIndex) return;

    final reordered = List<Track>.from(_orderedTracks);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() {
      _orderedTracks = reordered;
      _isLocalReorder = true;
    });

    // Backend wants exactly one anchor: prefer the track now above the moved
    // one; if it landed at the top, anchor before the track now below it.
    final afterId = newIndex > 0 ? reordered[newIndex - 1].id : null;
    final beforeId = afterId == null && newIndex < reordered.length - 1
        ? reordered[newIndex + 1].id
        : null;

    final provider = context.read<PlaylistsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.moveTrack(
        playlist.id,
        moved.id,
        afterTrackId: afterId,
        beforeTrackId: beforeId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _forceResync = true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.error ??
                'Could not reorder. Reordering a playlist requires Premium.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocalReorder = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _socketProvider = context.read<SocketProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      final Room? initialPlaylist = extra?['playlist'] as Room?;
      if (initialPlaylist != null) {
        _roomId = initialPlaylist.id;
        _socketProvider.joinRoom(_roomId!);
      }
    });
  }

  @override
  void dispose() {
    if (_roomId != null) {
      _socketProvider.leaveRoom(_roomId!);
    }
    super.dispose();
  }

  void _showAddTrackDialog(
    BuildContext context,
    Room playlist,
    PlaylistsProvider playlistsProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TrackSearchSheet(
        title: 'Add Song to Playlist',
        onSelected: (track) => playlistsProvider.addTrack(playlist.id, track),
        confirmationBuilder: (track) => '${track.title} added to playlist!',
      ),
    );
  }

  // * Opens the V.2.3 member management sheet. If the user leaves the room,
  //   pop back to the playlist list.
  Future<void> _showMembersSheet(BuildContext context, Room room) async {
    final router = GoRouter.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomMembersSheet(room: room),
    );
    if (result == membersSheetLeftResult) {
      router.go(routePlaylists);
    }
  }

  void _showEditDialog(BuildContext context, Room playlist) {
    final provider = context.read<PlaylistsProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditRoomDialog(
        room: playlist,
        onSubmit:
            ({
              required name,
              description,
              required isPublic,
              editAccess,
              voteAccess,
            }) => provider.updatePlaylist(
              playlist.id,
              name: name,
              description: description,
              isPublic: isPublic,
              editAccess: editAccess,
            ),
      ),
    );
  }

  void _showInviteFriendDialog(BuildContext context, Room room) {
    final playlistsProvider = context.read<PlaylistsProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InviteFriendDialog(
        room: room,
        onInvite: (userId) => playlistsProvider.inviteFriend(room.id, userId),
      ),
    );
  }

  // * Owner-only: confirm, delete the playlist, then go back to the list.
  Future<void> _confirmDeletePlaylist(
    BuildContext context,
    Room playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          'This permanently deletes "${playlist.name}" and all its tracks. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final playlistsProvider = context.read<PlaylistsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await playlistsProvider.deletePlaylist(playlist.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${playlist.name} deleted'),
          duration: const Duration(seconds: 1),
        ),
      );
      router.go(routePlaylists);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not delete playlist'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlistsProvider = context.watch<PlaylistsProvider>();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final Room? initialPlaylist = extra?['playlist'] as Room?;

    if (initialPlaylist == null) {
      return const Scaffold(body: Center(child: Text('No playlist selected')));
    }

    final Room playlist = playlistsProvider.playlists.firstWhere(
      (p) => p.id == initialPlaylist.id,
      orElse: () => initialPlaylist,
    );

    // Keep the local drag order in sync with the authoritative list, except
    // mid-reorder so the optimistic order isn't clobbered by a provider notify.
    if (_forceResync || !_isLocalReorder) {
      _orderedTracks = List<Track>.from(playlist.tracks);
      _forceResync = false;
    }

    final currentUserId = context.watch<AuthProvider>().user?.id;
    final isOwner = currentUserId != null && playlist.ownerId == currentUserId;

    final tag = 'playlist_cover_${playlist.id}';

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
                icon: const Icon(
                  Icons.people_alt_outlined,
                  color: Colors.white,
                ),
                tooltip: 'Members',
                onPressed: () => _showMembersSheet(context, playlist),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                onPressed: () => _showInviteFriendDialog(context, playlist),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () =>
                    _showAddTrackDialog(context, playlist, playlistsProvider),
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: 'Edit playlist',
                  onPressed: () => _showEditDialog(context, playlist),
                ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Delete playlist',
                  onPressed: () => _confirmDeletePlaylist(context, playlist),
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
                  // FittedBox scales the cover content down as the app bar
                  // collapses, so it never overflows the shrinking header.
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.lg,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                      onPressed: () => _showAddTrackDialog(
                        context,
                        playlist,
                        playlistsProvider,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // The Tracks — long-press a row to drag and reorder (Premium).
          SliverReorderableList(
            itemCount: _orderedTracks.length,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(playlist, oldIndex, newIndex),
            itemBuilder: (context, i) {
              final track = _orderedTracks[i];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(track.id),
                index: i,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.lg,
                    0,
                    AppDimens.lg,
                    AppDimens.sm,
                  ),
                  child: PlaceholderCard(
                    title: track.title,
                    subtitle: track.artist,
                    leading: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusSmall,
                        ),
                      ),
                      child: Icon(
                        Icons.music_note,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
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
                        Icon(Icons.drag_handle, color: theme.disabledColor),
                      ],
                    ),
                    onTap: () {
                      context.read<PlayerProvider>().playTrack(
                        track,
                        queue: _orderedTracks,
                        index: i,
                      );
                      context.push(routePlayer);
                    },
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.xxl * 3)),
        ],
      ),
    );
  }
}
