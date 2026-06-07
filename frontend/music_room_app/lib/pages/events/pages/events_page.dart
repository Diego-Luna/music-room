import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/pages/events/widgets/swipeable_track_card.dart';
import 'package:music_room_app/pages/events/widgets/suggest_track_dialog.dart';
import 'package:music_room_app/pages/events/widgets/create_event_dialog.dart';
import 'package:music_room_app/pages/events/widgets/invite_friend_dialog.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/socket_provider.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';

//* Events page skeleton with Staggered Animations and Dual Voting Interface.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  String? _currentRoomId;
  late SocketProvider _socketProvider;
  late EventsProvider _eventsProvider;

  @override
  void initState() {
    super.initState();
    _socketProvider = context.read<SocketProvider>();
    _eventsProvider = context.read<EventsProvider>();
    _eventsProvider.addListener(_onEventChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _eventsProvider.fetchEvents();
    });
  }

  void _onEventChanged() {
    final activeEvent = _eventsProvider.selectedEvent;
    if (activeEvent?.id != _currentRoomId) {
      if (_currentRoomId != null) {
        _socketProvider.leaveRoom(_currentRoomId!);
      }
      if (activeEvent != null) {
        _socketProvider.joinRoom(activeEvent.id);
      }
      _currentRoomId = activeEvent?.id;
    }
  }

  @override
  void dispose() {
    _eventsProvider.removeListener(_onEventChanged);
    if (_currentRoomId != null) {
      _socketProvider.leaveRoom(_currentRoomId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final activeEvent = eventsProvider.selectedEvent;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 3D Background effect
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),

          if (eventsProvider.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (activeEvent == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No active events available',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: AppDimens.md),
                  PrimaryButton(
                    onPressed: () => _showCreateEventDialog(context),
                    leading: const Icon(Icons.add),
                    label: 'Create Event',
                  ),
                ],
              ),
            )
          else
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: _buildEventSelector(
                    context,
                    eventsProvider,
                    activeEvent,
                  ),
                  centerTitle: true,
                  floating: true,
                  toolbarHeight: 90.0,
                  pinned: false,
                  backgroundColor: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                  actions: [
                    Center(
                      child: NeumorphicIconButton(
                        icon: Icons.add_box_outlined,
                        tooltip: 'Create Event',
                        onTap: () => _showCreateEventDialog(context),
                      ),
                    ),
                    Center(
                      child: NeumorphicIconButton(
                        icon: Icons.person_add_alt_1,
                        tooltip: 'Invite Friend',
                        onTap: () =>
                            _showInviteFriendDialog(context, activeEvent),
                      ),
                    ),
                    Center(
                      child: NeumorphicIconButton(
                        icon: Icons.add,
                        tooltip: 'Suggest Song',
                        onTap: () =>
                            _showSuggestTrackDialog(context, activeEvent),
                      ),
                    ),
                  ],
                ),

                // Contains the Voting Area and Headers
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // 1. The Tinder-Style Voting Area
                      const Padding(
                        padding: EdgeInsets.only(top: AppDimens.sm),
                        child: DualModeVotingInterface(),
                      ),

                      //* Simple Divider for separation
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.lg,
                          vertical: AppDimens.sm,
                        ),
                        child: Divider(
                          color: Theme.of(
                            context,
                          ).disabledColor.withValues(alpha: 0.2),
                        ),
                      ),

                      // 2. The Next Tracks Queue
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.xl,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Up Next',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.md),
                    ],
                  ),
                ),

                // 3. Staggered list of upcoming tracks as slivers
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // * Exclude the tracks that have already been voted on in this session
                      final unvotedTracks = activeEvent.tracks
                          .where(
                            (t) => !eventsProvider.votedTrackIds.contains(t.id),
                          )
                          .toList();

                      // * Exclude the first track which is currently active in voting interface
                      final queueTracks = unvotedTracks.skip(1).toList();
                      if (index >= queueTracks.length) return null;

                      final track = queueTracks[index];

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
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusMedium,
                                ),
                                boxShadow: Theme.of(context)
                                    .extension<AppDesignTokens>()
                                    ?.neumorphicPressedShadow,
                              ),
                              child: Icon(
                                Icons.music_note,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            onTap: () {
                              context.read<PlayerProvider>().playTrack(track);
                              context.push(routePlayer);
                            },
                          ),
                        ),
                      );
                    },
                    childCount:
                        activeEvent.tracks
                                .where(
                                  (t) => !eventsProvider.votedTrackIds.contains(
                                    t.id,
                                  ),
                                )
                                .length >
                            1
                        ? activeEvent.tracks
                                  .where(
                                    (t) => !eventsProvider.votedTrackIds
                                        .contains(t.id),
                                  )
                                  .length -
                              1
                        : 0,
                  ),
                ),

                // 4. Voted Tracks section header
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      if (eventsProvider.votedTrackIds.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.lg,
                              vertical: AppDimens.sm,
                            ),
                            child: Divider(
                              color: Theme.of(
                                context,
                              ).disabledColor.withValues(alpha: 0.2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.xl,
                            ),
                            child: Text(
                              'Voted Tracks',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(height: AppDimens.md),
                        ],
                      );
                    },
                  ),
                ),

                // 5. Staggered list of voted tracks as slivers
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final votedTracks = activeEvent.tracks
                          .where(
                            (t) => eventsProvider.votedTrackIds.contains(t.id),
                          )
                          .toList();
                      if (index >= votedTracks.length) return null;

                      final track = votedTracks[index];

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
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusMedium,
                                ),
                                boxShadow: Theme.of(context)
                                    .extension<AppDesignTokens>()
                                    ?.neumorphicPressedShadow,
                              ),
                              child: Icon(
                                Icons.music_note,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            onTap: () {
                              context.read<PlayerProvider>().playTrack(track);
                              context.push(routePlayer);
                            },
                          ),
                        ),
                      );
                    },
                    childCount: activeEvent.tracks
                        .where(
                          (t) => eventsProvider.votedTrackIds.contains(t.id),
                        )
                        .length,
                  ),
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

  Widget _buildEventSelector(
    BuildContext context,
    EventsProvider eventsProvider,
    Room? activeEvent,
  ) {
    if (activeEvent == null) {
      return const Text('Events');
    }

    final otherEvents = eventsProvider.events
        .where((e) => e.id != activeEvent.id)
        .toList();
    if (otherEvents.isEmpty) {
      return Text(activeEvent.name);
    }

    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        boxShadow: tokens?.neumorphicShadow,
      ),
      child: Theme(
        data: theme.copyWith(canvasColor: theme.colorScheme.surface),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Room>(
            isExpanded: true,
            value: activeEvent,
            icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
            onChanged: (Room? newValue) {
              if (newValue != null) {
                eventsProvider.selectEvent(newValue);
              }
            },
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            items: eventsProvider.events.map<DropdownMenuItem<Room>>((
              Room room,
            ) {
              return DropdownMenuItem<Room>(
                value: room,
                child: Text(room.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showCreateEventDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CreateEventDialog(),
    );
  }
}
