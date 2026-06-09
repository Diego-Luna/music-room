import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/pages/events/widgets/swipeable_track_card.dart';
import 'package:music_room_app/pages/events/widgets/suggest_track_dialog.dart';
import 'package:music_room_app/pages/events/widgets/invite_friend_dialog.dart';
import 'package:music_room_app/widgets/room_members_sheet.dart';
import 'package:music_room_app/widgets/edit_room_dialog.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/socket_provider.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

// * Detail page for a single VOTE room: the live Tinder-style voting interface,
// * the "Up Next" queue and the "Voted Tracks" list. Mirror of
// * PlaylistDetailPage so both features feel symmetric.
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  String? _roomId;
  late SocketProvider _socketProvider;
  late EventsProvider _eventsProvider;

  @override
  void initState() {
    super.initState();
    _socketProvider = context.read<SocketProvider>();
    _eventsProvider = context.read<EventsProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      final Room? event = extra?['event'] as Room?;
      if (event != null) {
        _roomId = event.id;
        _eventsProvider.selectEvent(event);
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

  // * Opens the V.2.3 member management sheet. If the user leaves the room,
  //   pop back to the events list.
  Future<void> _showMembersSheet(BuildContext context, Room room) async {
    final router = GoRouter.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomMembersSheet(room: room),
    );
    if (result == membersSheetLeftResult) {
      router.go(routeSocial);
    }
  }

  void _showEditDialog(BuildContext context, Room event) {
    final provider = context.read<EventsProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditRoomDialog(
        room: event,
        onSubmit:
            ({
              required name,
              description,
              required isPublic,
              editAccess,
              voteAccess,
            }) => provider.updateEvent(
              event.id,
              name: name,
              description: description,
              isPublic: isPublic,
              voteAccess: voteAccess,
            ),
      ),
    );
  }

  // * Owner-only: confirm, delete the event, then go back to the events list.
  Future<void> _confirmDeleteEvent(BuildContext context, Room event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
          'This permanently deletes "${event.name}" and all its tracks. '
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

    final eventsProvider = context.read<EventsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await eventsProvider.deleteEvent(event.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${event.name} deleted'),
          duration: const Duration(seconds: 1),
        ),
      );
      router.go(routeSocial);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not delete event'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuggestTrackDialog(BuildContext context, Room room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SuggestTrackDialog(room: room),
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
    final eventsProvider = context.watch<EventsProvider>();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final Room? initialEvent = extra?['event'] as Room?;

    if (initialEvent == null) {
      return const Scaffold(body: Center(child: Text('No event selected')));
    }

    final Room event = eventsProvider.events.firstWhere(
      (e) => e.id == initialEvent.id,
      orElse: () => initialEvent,
    );
    final tag = 'event_cover_${event.id}';

    final currentUserId = context.watch<AuthProvider>().user?.id;
    final isOwner = currentUserId != null && event.ownerId == currentUserId;

    final unvotedTracks = event.tracks
        .where((t) => !eventsProvider.votedTrackIds.contains(t.id))
        .toList();
    final queueTracks = unvotedTracks.skip(1).toList();
    final votedTracks = event.tracks
        .where((t) => eventsProvider.votedTrackIds.contains(t.id))
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240.0,
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
                onPressed: () => _showMembersSheet(context, event),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                tooltip: 'Invite Friend',
                onPressed: () => _showInviteFriendDialog(context, event),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Suggest Song',
                onPressed: () => _showSuggestTrackDialog(context, event),
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: 'Edit event',
                  onPressed: () => _showEditDialog(context, event),
                ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Delete event',
                  onPressed: () => _confirmDeleteEvent(context, event),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: tag,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                        theme.colorScheme.secondary.withValues(alpha: 0.6),
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
                        Icons.how_to_vote,
                        size: 72,
                        color: Colors.white,
                      ),
                      const SizedBox(height: AppDimens.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.lg,
                        ),
                        child: Text(
                          event.name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: AppTypography.extraBold,
                          ),
                        ),
                      ),
                      Text(
                        '${event.tracks.length} tracks',
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

          // Voting area + "Up Next" header
          SliverToBoxAdapter(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: AppDimens.sm),
                  child: DualModeVotingInterface(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.lg,
                    vertical: AppDimens.sm,
                  ),
                  child: Divider(
                    color: theme.disabledColor.withValues(alpha: 0.2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Up Next', style: theme.textTheme.titleLarge),
                  ),
                ),
                const SizedBox(height: AppDimens.md),
              ],
            ),
          ),

          _buildTrackSliver(context, queueTracks, event.id),

          // Voted tracks header
          if (votedTracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.lg,
                      vertical: AppDimens.sm,
                    ),
                    child: Divider(
                      color: theme.disabledColor.withValues(alpha: 0.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.xl,
                    ),
                    child: Text(
                      'Voted Tracks',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppDimens.md),
                ],
              ),
            ),

          _buildTrackSliver(context, votedTracks, event.id),

          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.xxl * 3)),
        ],
      ),
    );
  }

  Widget _buildTrackSliver(BuildContext context, List tracks, String roomId) {
    final theme = Theme.of(context);
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index >= tracks.length) return null;
        final track = tracks[index];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg,
            vertical: AppDimens.sm / 2,
          ),
          child: StaggeredList(
            index: index,
            child: PlaceholderCard(
              title: track.title,
              subtitle: '${track.artist} • ${track.score} votes',
              leading: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  boxShadow: theme
                      .extension<AppDesignTokens>()
                      ?.neumorphicPressedShadow,
                ),
                child: Icon(Icons.music_note, color: theme.colorScheme.primary),
              ),
              onTap: () {
                context.read<PlayerProvider>().playTrack(
                  track,
                  queue: List<Track>.from(tracks),
                  index: index,
                  voteRoomId: roomId,
                );
                context.push(routePlayer);
              },
            ),
          ),
        );
      }, childCount: tracks.length),
    );
  }
}
