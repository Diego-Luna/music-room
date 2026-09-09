import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';
import 'package:music_room_app/providers/friends_provider.dart';

class FriendsListTab extends StatelessWidget {
  final FriendsProvider provider;

  const FriendsListTab({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (provider.friends.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No friends yet. Add some!')),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((builderContext, index) {
        final friendDto = provider.friends[index];
        final user = provider.userCache[friendDto.friendId];
        if (user == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg,
            vertical: AppDimens.sm / 2,
          ),
          child: StaggeredList(
            index: index,
            child: PlaceholderCard(
              title: user.displayName,
              subtitle: friendDto.since != null
                  ? 'Friends since: ${friendDto.since!.toLocal().toString().split(' ')[0]}'
                  : 'Connected',
              onTap: () => context.push(
                routeUserProfile,
                extra: {'userId': friendDto.friendId},
              ),
              leading: CircleAvatar(
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null ? const Icon(Icons.person) : null,
              ),
              trailing: NeumorphicIconButton(
                icon: Icons.person_remove_rounded,
                iconColor: theme.colorScheme.error,
                tooltip: 'Unfriend',
                iconSize: 20,
                onTap: () async {
                  try {
                    await provider.cancelOrRemoveFriendship(
                      friendDto.friendshipId,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(provider.error ?? 'An error occurred'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        );
      }, childCount: provider.friends.length),
    );
  }
}
