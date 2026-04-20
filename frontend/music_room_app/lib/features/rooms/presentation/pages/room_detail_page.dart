import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';

//* Room detail skeleton receiving Hero Animation.
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    //* Recover the extra arguments passed by GoRouter
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final int? index = extra?['index'];
    final String name = extra?['name'] ?? 'Room Detail';

    final tag = index != null ? 'room_cover_$index' : 'room_cover_default';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(name, style: const TextStyle(color: Colors.white)),
              background: Hero(
                tag:
                    tag, //* Must match the tag from RoomsListPage to animate correctly
                child: Container(
                  color: Theme.of(context).colorScheme.primary,
                  child: const Center(
                    child: Icon(
                      Icons.queue_music,
                      size: 80,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: FadeIn(
                duration: const Duration(milliseconds: 600),
                beginOpacity: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Event Details',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppDimens.md),
                    Text(
                      'Welcome to $name. Here you will see the live track voting and the participants.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    //* Placeholder reserved for live songs list
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
