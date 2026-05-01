import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';

//* Rooms list skeleton with Staggered and Hero Animations.
class RoomsListPage extends StatelessWidget {
  const RoomsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulated data to demonstrate the cascading animation
    final List<String> fakeRooms = List.generate(10, (i) => 'Room ${i + 1}');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background floaters for immersive UI
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),

          CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Rooms'),
                centerTitle: true,
                floating: true, // Hides when scrolled!
                pinned: false,
                backgroundColor: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.8),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final roomName = fakeRooms[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.lg,
                      vertical: AppDimens.sm / 2,
                    ),
                    child: StaggeredList(
                      index: index,
                      child: PlaceholderCard(
                        title: roomName,
                        subtitle: 'Tap to join event...',
                        //* We apply a Hero wrapper to the leading image to connect it to the Detail Page
                        leading: Hero(
                          tag: 'room_cover_$index', // Unique tag for each room
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
                              Icons.queue_music,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        onTap: () {
                          //* We pass the index via GoRouter state extra to maintain the Hero animation correctly
                          context.go(
                            '$routeRoomsList/$routeRoomDetail',
                            extra: {'index': index, 'name': roomName},
                          );
                        },
                      ),
                    ),
                  );
                }, childCount: fakeRooms.length),
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
