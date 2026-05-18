import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/features/events/presentation/widgets/swipeable_track_card.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';

//* Events page skeleton with Staggered Animations and Dual Voting Interface.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventsProvider>().fetchEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final activeEvent = eventsProvider.events.isNotEmpty
        ? eventsProvider.events.first
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 3D Background effect
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),

          if (eventsProvider.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (activeEvent == null)
            const Center(child: Text('No active events available'))
          else
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(activeEvent.name),
                  centerTitle: true,
                  floating: true,
                  pinned: false,
                  backgroundColor: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.8),
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
                      // Exclude the first track which is currently active in voting interface
                      final queueTracks = activeEvent.tracks.skip(1).toList();
                      if (index >= queueTracks.length) return null;

                      final eventTrack = queueTracks[index];
                      final track = eventTrack.track;

                      if (track == null) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.lg,
                          vertical: AppDimens.sm / 2,
                        ),
                        child: StaggeredList(
                          index: index,
                          child: PlaceholderCard(
                            title: track.title,
                            subtitle:
                                '${track.artist} • ${eventTrack.voteCount} votes',
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
                    childCount: activeEvent.tracks.length > 1
                        ? activeEvent.tracks.length - 1
                        : 0,
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
}
