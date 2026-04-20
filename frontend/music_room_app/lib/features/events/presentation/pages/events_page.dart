import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
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
      appBar: AppBar(title: const Text('Live Event'), centerTitle: true),
      body: Column(
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
              color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
            ),
          ),

          // 2. The Next Tracks Queue
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Up Next',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          // 3. Staggered list of upcoming tracks
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimens.lg),
              itemCount: fakeEvents.length,
              separatorBuilder: (context, _) =>
                  const SizedBox(height: AppDimens.sm),
              itemBuilder: (context, index) {
                return StaggeredList(
                  index: index,
                  child: PlaceholderCard(
                    title: fakeEvents[index],
                    subtitle: 'Queue position #${index + 1}',
                    leading: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMedium,
                        ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
