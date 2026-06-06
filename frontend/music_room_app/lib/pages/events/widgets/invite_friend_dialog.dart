import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/models/room.dart';

//* Bottom sheet to invite a friend to a (private) room.
//* Lists the current user's friends and sends POST /rooms/:id/invitations.
class InviteFriendDialog extends StatefulWidget {
  final Room room;

  const InviteFriendDialog({super.key, required this.room});

  @override
  State<InviteFriendDialog> createState() => _InviteFriendDialogState();
}

class _InviteFriendDialogState extends State<InviteFriendDialog> {
  final Set<String> _invitingIds = {};
  final Set<String> _invitedIds = {};

  @override
  void initState() {
    super.initState();
    // * Ensure friends + their profiles are loaded before we render names.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendsProvider>().fetchFriendsData();
    });
  }

  Future<void> _invite(String userId) async {
    final events = context.read<EventsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _invitingIds.add(userId));
    try {
      await events.inviteFriend(widget.room.id, userId);
      if (!mounted) return;
      setState(() {
        _invitingIds.remove(userId);
        _invitedIds.add(userId);
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Invitation sent')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _invitingIds.remove(userId));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not invite: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friends = context.watch<FriendsProvider>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.lg),
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDimens.radiusLarge),
            topRight: Radius.circular(AppDimens.radiusLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invite to ${widget.room.name}',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            Expanded(child: _buildBody(theme, friends)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, FriendsProvider friends) {
    if (friends.isLoading && friends.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (friends.friends.isEmpty) {
      return Center(
        child: Text(
          'You have no friends to invite yet.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      itemCount: friends.friends.length,
      itemBuilder: (context, index) {
        final friend = friends.friends[index];
        final user = friends.userCache[friend.friendId];
        final name = user?.displayName ?? friend.friendId;
        final inviting = _invitingIds.contains(friend.friendId);
        final invited = _invitedIds.contains(friend.friendId);

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user?.avatarUrl != null
                ? NetworkImage(user!.avatarUrl!)
                : null,
            child: user?.avatarUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(name),
          trailing: invited
              ? const Icon(Icons.check_circle, color: Colors.green)
              : inviting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: () => _invite(friend.friendId),
                      child: const Text('Invite'),
                    ),
        );
      },
    );
  }
}
