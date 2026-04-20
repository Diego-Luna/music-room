import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/core/theme/app_theme.dart';

//* Rooms list skeleton with Staggered and Hero Animations.
class RoomsListPage extends StatelessWidget {
  const RoomsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulated data to demonstrate the cascading animation
    final List<String> fakeRooms = List.generate(10, (i) => 'Room ${i + 1}');

    return Scaffold(
      appBar: AppBar(title: const Text('Rooms'), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppDimens.lg),
        itemCount: fakeRooms.length,
        separatorBuilder: (context, _) => const SizedBox(height: AppDimens.sm),
        itemBuilder: (context, index) {
          final roomName = fakeRooms[index];

          return StaggeredList(
            index: index,
            child: PlaceholderCard(
              title: roomName,
              subtitle: 'Tap to join event...',
              //* We apply a Hero wrapper to the leading image to connect it to the Detail Page
              leading: Hero(
                tag: 'room_cover_$index', // Unique tag for each room
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
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
          );
        },
      ),
    );
  }
}
