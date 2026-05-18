import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/config/mock/mock_data.dart';

//* Room detail page with control delegation.
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final roomsProvider = context.watch<RoomsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final room = roomsProvider.currentActiveRoom;

    if (room == null) {
      return const Scaffold(
        body: Center(child: Text('No active room session selected.')),
      );
    }

    final isOwner = room.ownerId == authProvider.user?.id;
    final tag = 'room_cover_${room.id}';

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
              title: Text(
                room.name,
                style: const TextStyle(color: Colors.white),
              ),
              background: Hero(
                tag: tag,
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
                      'Live Evnet Details',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppDimens.sm),
                    Text(
                      'Current Controller: ${room.currentControllerId == room.ownerId ? "Room Host" : "Delegated User (ID: ${room.currentControllerId})"}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.md),
                    Text(
                      'As the room host, you can delegate DJ/playback control to any participant in the room session.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppDimens.xl),

                    // List of participants
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: room.connectedUsers.length,
                      itemBuilder: (context, index) {
                        final participantId = room.connectedUsers[index];
                        // Find participant details from MockData.users
                        final participant = MockData.users.firstWhere(
                          (u) => u.id == participantId,
                          orElse: () => MockData.users.first,
                        );

                        final isCurrentController =
                            room.currentControllerId == participant.id;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: AppDimens.sm,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                participant.avatarUrl ??
                                    'https://i.pravatar.cc/150',
                              ),
                            ),
                            title: Text(participant.displayName),
                            subtitle: Text(participant.email),
                            trailing: isOwner
                                ? (isCurrentController
                                      ? (participant.id == room.ownerId
                                            ? const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                              )
                                            : ElevatedButton(
                                                onPressed: () => roomsProvider
                                                    .revokeControl(room.id),
                                                child: const Text('Revoke'),
                                              ))
                                      : ElevatedButton(
                                          onPressed: () =>
                                              roomsProvider.delegateControl(
                                                room.id,
                                                participant.id,
                                              ),
                                          child: const Text('Delegate'),
                                        ))
                                : (isCurrentController
                                      ? const Icon(
                                          Icons.music_note,
                                          color: Colors.green,
                                        )
                                      : null),
                          ),
                        );
                      },
                    ),
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
