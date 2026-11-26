import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/routing/safe_navigation.dart';
import 'package:music_room_app/pages/events/widgets/vote_queue.dart';
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

// * Detail page for a single VOTE room: the track the room is playing, then
// * the shared queue. A tap votes for a waiting track; a second tap clears it.
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  String? _roomId;
  String? _heardTrackId;
  Room? _hint;
  bool _loading = true;
  String? _loadError;
  late SocketProvider _socketProvider;
  late EventsProvider _eventsProvider;

  @override
  void initState() {
    super.initState();
    _socketProvider = context.read<SocketProvider>();
    _eventsProvider = context.read<EventsProvider>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = GoRouterState.of(context).pathParameters['eventId'];
    if (id == null || id.isEmpty || id == _roomId) return;
    if (_roomId != null) _socketProvider.leaveRoom(_roomId!);
    _roomId = id;
    _heardTrackId = null;
    _loadError = null;
    final extra = GoRouterState.of(context).extra;
    final hinted = extra is Map ? extra['event'] as Room? : null;
    _hint = hinted != null && hinted.id == id ? hinted : null;
    _loading = _visibleEvent(_eventsProvider, id) == null;
    _socketProvider.joinRoom(id);
    _refresh(id);
  }

  Future<void> _refresh(String id) async {
    try {
      await _eventsProvider.loadEvent(id);
      if (!mounted || _roomId != id) return;
      setState(() {
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || _roomId != id) return;
      setState(() {
        _loading = false;
        _loadError = ApiErrorHandler.getMessage(
          error,
          defaultMessage: 'This event is unavailable.',
        );
      });
    }
  }

  Room? _visibleEvent(EventsProvider provider, String? id) {
    if (id == null) return null;
    for (final event in provider.events) {
      if (event.id == id) return event;
    }
    if (provider.selectedEvent?.id == id) return provider.selectedEvent;
    if (_hint?.id == id) return _hint;
    return null;
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
      router.go(routeEvents);
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
      router.go(routeEvents);
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
    final id = GoRouterState.of(context).pathParameters['eventId'];
    final Room? event = _visibleEvent(eventsProvider, id);

    if (event == null) {
      if (_loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return _unavailable(context);
    }
    final tag = 'event_cover_${event.id}';

    final currentUserId = context.watch<AuthProvider>().user?.id;
    final isOwner = currentUserId != null && event.ownerId == currentUserId;
    final canControl =
        isOwner || event.myRole == 'ADMIN' || event.myRole == 'OWNER';
    _scheduleRoomPlayback(event);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240.0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => context.safePop(fallbackRoute: routeEvents),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                              '${event.tracks.length} ${event.tracks.length == 1 ? 'track' : 'tracks'}',
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

          SliverToBoxAdapter(
            child: VoteQueue(
              tracks: event.tracks,
              currentTrackId: event.currentTrackId,
              isPaused: event.playbackPausedAt != null,
              canControl: canControl,
              onToggle: (track) => _toggleVote(context, event, track),
              onTogglePlayback: (track) =>
                  _toggleRoomPlayback(context, event, track),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.xxl * 3)),
        ],
      ),
    );
  }

  Widget _unavailable(BuildContext context) {
    final message = _loadError;
    final text =
        message == null ||
            message.startsWith('Exception:') ||
            message.startsWith('DioException')
        ? 'This event is unavailable.'
        : message;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: AppDimens.md),
              TextButton(
                onPressed: () => context.go(routeEvents),
                child: const Text('Back to events'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Track? _currentRoomTrack(Room event) {
    final id = event.currentTrackId;
    if (id == null) return null;
    for (final track in event.tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  Duration _sharedElapsed(Room event) {
    final started = event.currentTrackStartedAt;
    if (started == null) return Duration.zero;
    final end = event.playbackPausedAt ?? DateTime.now();
    final elapsed = end.difference(started);
    if (elapsed.isNegative) return Duration.zero;
    return elapsed;
  }

  void _scheduleRoomPlayback(Room event) {
    final track = _currentRoomTrack(event);
    if (track == null || track.id == _heardTrackId) return;
    final preview = track.previewUrl;
    if (preview == null || preview.isEmpty) return;
    if (event.currentTrackStartedAt == null) return;
    final elapsed = _sharedElapsed(event);
    const previewLength = Duration(seconds: 30);
    final position = elapsed >= previewLength ? previewLength : elapsed;
    final autoplay = event.playbackPausedAt == null && elapsed < previewLength;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _heardTrackId == track.id) return;
      _heardTrackId = track.id;
      context.read<PlayerProvider>().handlePlaybackPlayed(
        track,
        position: position,
        autoplay: autoplay,
      );
    });
  }

  Future<void> _toggleRoomPlayback(
    BuildContext context,
    Room event,
    Track track,
  ) async {
    final canControl =
        event.ownerId == context.read<AuthProvider>().user?.id ||
        event.myRole == 'ADMIN' ||
        event.myRole == 'OWNER';
    if (!canControl) return;
    final events = context.read<EventsProvider>();
    final player = context.read<PlayerProvider>();
    final pausing = event.playbackPausedAt == null;
    try {
      if (pausing) {
        await events.pausePlayback(event.id);
        player.pause();
      } else {
        await events.resumePlayback(event.id);
        if (player.currentTrack?.id == track.id) {
          player.resume();
        } else {
          _heardTrackId = null;
        }
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(events.error ?? 'Could not change playback.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _toggleVote(
    BuildContext context,
    Room event,
    Track track,
  ) async {
    if (track.id == event.currentTrackId) return;
    final next = track.myVote == 1 ? 0 : 1;
    final messenger = ScaffoldMessenger.of(context);
    final events = context.read<EventsProvider>();
    try {
      await events.voteForTrack(event.id, track.id, next);
    } catch (_) {
      if (!context.mounted) return;
      final message = events.error ?? 'Could not cast vote.';
      if (message.contains('started')) {
        _heardTrackId = null;
        await events.fetchEvents(force: true);
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }
}
