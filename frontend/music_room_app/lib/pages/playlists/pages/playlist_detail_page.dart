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
import 'package:music_room_app/providers/socket_provider.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/widgets/track_search_sheet.dart';
import 'package:music_room_app/pages/events/widgets/invite_friend_dialog.dart';

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  String? _roomId;
  late SocketProvider _socketProvider;

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

  void _showInviteFriendDialog(BuildContext context, Room room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InviteFriendDialog(room: room),
    );
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
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                onPressed: () => _showInviteFriendDialog(context, playlist),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () =>
                    _showAddTrackDialog(context, playlist, playlistsProvider),
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

          // The Tracks
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                if (i >= playlist.tracks.length) return null;
                final track = playlist.tracks[i];

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
