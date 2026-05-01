import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/features/events/presentation/widgets/swipeable_track_card.dart';

//* Events page skeleton with Staggered Animations and Dual Voting Interface.
class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> fakeEvents = List.generate(
      4,
      (i) => 'Upcoming Event ${i + 1}',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 3D Background effect
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),

          CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Live Event'),
                centerTitle: true,
                floating: true, // Disappears on scroll
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
                      padding: EdgeInsets.only(
                        top: AppDimens.sm,
                      ), // Reduced padding to leave more space for "Up Next"
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
                delegate: SliverChildBuilderDelegate((context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.lg,
                      vertical: AppDimens.sm / 2,
                    ),
                    child: StaggeredList(
                      index: index,
                      child: PlaceholderCard(
                        title: fakeEvents[index],
                        subtitle: 'Queue position #${index + 1}',
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
                            Icons.podcasts,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onTap: () {
                          context.push(routePlayer);
                        },
                      ),
                    ),
                  );
                }, childCount: fakeEvents.length),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: AppDimens.xxl * 3,
                ), // Ensure space at bottom
              ),
            ],
          ),
        ],
      ),
    );
  }
}
