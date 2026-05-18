import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/providers/rooms_provider.dart';

//* Rooms list skeleton with Staggered and Hero Animations.
class RoomsListPage extends StatefulWidget {
  const RoomsListPage({super.key});

  @override
  State<RoomsListPage> createState() => _RoomsListPageState();
}

class _RoomsListPageState extends State<RoomsListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomsProvider>().fetchRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomsProvider = context.watch<RoomsProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background floaters for immersive UI
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),

          if (roomsProvider.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: const Text('Rooms'),
                  centerTitle: true,
                  floating: true,
                  pinned: false,
                  backgroundColor: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= roomsProvider.rooms.length) return null;
                    final room = roomsProvider.rooms[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.lg,
                        vertical: AppDimens.sm / 2,
                      ),
                      child: StaggeredList(
                        index: index,
                        child: PlaceholderCard(
                          title: room.name,
                          subtitle: 'Tap to join room session...',
                          leading: Hero(
                            tag: 'room_cover_${room.id}',
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
                            context.read<RoomsProvider>().selectRoom(room);
                            context.go(
                              '$routeRoomsList/$routeRoomDetail',
                              extra: {'room': room},
                            );
                          },
                        ),
                      ),
                    );
                  }, childCount: roomsProvider.rooms.length),
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
