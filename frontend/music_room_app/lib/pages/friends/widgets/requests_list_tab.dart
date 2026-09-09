import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/invitation.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';

class RequestsListTab {
  static List<Widget> buildSlivers(
    BuildContext context,
    NotificationsProvider provider,
  ) {
    final hasFriendRequests = provider.incomingFriendRequests.isNotEmpty;
    final hasRoomInvitations = provider.roomInvitations.isNotEmpty;
    final hasOutgoing = provider.outgoingFriendRequests.isNotEmpty;
    final hasSentInvites = provider.sentRoomInvitations.isNotEmpty;

    if (!hasFriendRequests &&
        !hasRoomInvitations &&
        !hasOutgoing &&
        !hasSentInvites) {
      return const [
        SliverFillRemaining(child: Center(child: Text('No pending requests.'))),
      ];
    }

    final List<Widget> slivers = [];

    if (hasRoomInvitations) {
      slivers.add(
        SliverToBoxAdapter(child: _buildHeader(context, 'Room Invitations')),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, index) => _buildRoomInvitationItem(
              context,
              provider,
              provider.roomInvitations[index],
            ),
            childCount: provider.roomInvitations.length,
          ),
        ),
      );
    }

    if (hasFriendRequests) {
      slivers.add(
        SliverToBoxAdapter(child: _buildHeader(context, 'Friend Requests')),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((ctx, index) {
            final req = provider.incomingFriendRequests[index];
            final user = provider.userCache[req.requesterId];
            return user != null
                ? _buildIncomingRequestItem(context, provider, req, user)
                : const SizedBox.shrink();
          }, childCount: provider.incomingFriendRequests.length),
        ),
      );
    }

    if (hasOutgoing) {
      slivers.add(
        SliverToBoxAdapter(child: _buildHeader(context, 'Outgoing Requests')),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((ctx, index) {
            final req = provider.outgoingFriendRequests[index];
            final user = provider.userCache[req.addresseeId];
            return user != null
                ? _buildOutgoingRequestItem(context, provider, req, user)
                : const SizedBox.shrink();
          }, childCount: provider.outgoingFriendRequests.length),
        ),
      );
    }

    if (hasSentInvites) {
      slivers.add(
        SliverToBoxAdapter(
          child: _buildHeader(context, 'Sent Room Invitations'),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, index) => _buildSentRoomInvitationItem(
              context,
              provider,
              provider.sentRoomInvitations[index],
            ),
            childCount: provider.sentRoomInvitations.length,
          ),
        ),
      );
    }

    return slivers;
  }

  static Widget _buildHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimens.xl,
        top: AppDimens.lg,
        bottom: AppDimens.sm,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }

  static Widget _buildRoomInvitationItem(
    BuildContext context,
    NotificationsProvider provider,
    RoomInvitationDto invite,
  ) {
    final theme = Theme.of(context);
    final inviter = provider.userCache[invite.inviterId];
    final room = provider.roomCache[invite.roomId];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm / 2,
      ),
      child: PlaceholderCard(
        title: inviter?.displayName ?? 'Someone',
        subtitle: 'Invited you to: ${room?.name ?? 'a private room'}',
        leading: CircleAvatar(
          backgroundImage: inviter?.avatarUrl != null
              ? NetworkImage(inviter!.avatarUrl!)
              : null,
          child: inviter?.avatarUrl == null
              ? const Icon(Icons.meeting_room_rounded)
              : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeumorphicIconButton(
              icon: Icons.check_circle_rounded,
              tooltip: 'Accept',
              iconSize: 20,
              onTap: () async {
                try {
                  await provider.acceptRoomInvitation(invite.id);
                  if (!context.mounted) return;
                  // Refresh playlists and events so joined room appears immediately
                  context.read<PlaylistsProvider>().fetchPlaylists();
                  context.read<EventsProvider>().fetchEvents();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.error ?? 'Could not accept invitation',
                      ),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: AppDimens.sm),
            NeumorphicIconButton(
              icon: Icons.cancel_rounded,
              iconColor: theme.colorScheme.error,
              tooltip: 'Decline',
              iconSize: 20,
              onTap: () async {
                try {
                  await provider.declineRoomInvitation(invite.id);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.error ?? 'Could not decline invitation',
                      ),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildIncomingRequestItem(
    BuildContext context,
    NotificationsProvider provider,
    FriendshipDto req,
    User user,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm / 2,
      ),
      child: PlaceholderCard(
        title: user.displayName,
        subtitle: 'Wants to be your friend',
        leading: CircleAvatar(
          backgroundImage: user.avatarUrl != null
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: user.avatarUrl == null ? const Icon(Icons.person) : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeumorphicIconButton(
              icon: Icons.check_circle_rounded,
              tooltip: 'Accept',
              iconSize: 20,
              onTap: () async {
                try {
                  await provider.acceptFriendRequest(req.id);
                  if (!context.mounted) return;
                  context.read<FriendsProvider>().fetchFriendsData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.error ?? 'Could not accept request',
                      ),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: AppDimens.sm),
            NeumorphicIconButton(
              icon: Icons.cancel_rounded,
              iconColor: theme.colorScheme.error,
              tooltip: 'Decline',
              iconSize: 20,
              onTap: () async {
                try {
                  await provider.declineFriendRequest(req.id);
                  if (!context.mounted) return;
                  context.read<FriendsProvider>().fetchFriendsData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.error ?? 'Could not decline request',
                      ),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildOutgoingRequestItem(
    BuildContext context,
    NotificationsProvider provider,
    FriendshipDto req,
    User user,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm / 2,
      ),
      child: PlaceholderCard(
        title: user.displayName,
        subtitle: 'Sent request pending response',
        leading: CircleAvatar(
          backgroundImage: user.avatarUrl != null
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: user.avatarUrl == null ? const Icon(Icons.person) : null,
        ),
        trailing: NeumorphicIconButton(
          icon: Icons.delete_forever_rounded,
          iconColor: theme.colorScheme.error,
          tooltip: 'Cancel Request',
          iconSize: 20,
          onTap: () async {
            try {
              await provider.cancelOrRemoveFriendship(req.id);
              if (!context.mounted) return;
              context.read<FriendsProvider>().fetchFriendsData();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.error ?? 'Could not cancel request'),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  static Widget _buildSentRoomInvitationItem(
    BuildContext context,
    NotificationsProvider provider,
    RoomInvitationDto invite,
  ) {
    final theme = Theme.of(context);
    final invitee = provider.userCache[invite.inviteeId];
    final room = provider.roomCache[invite.roomId];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm / 2,
      ),
      child: PlaceholderCard(
        title: invitee?.displayName ?? 'Someone',
        subtitle: 'Invited to: ${room?.name ?? 'a private room'}',
        leading: CircleAvatar(
          backgroundImage: invitee?.avatarUrl != null
              ? NetworkImage(invitee!.avatarUrl!)
              : null,
          child: invitee?.avatarUrl == null
              ? const Icon(Icons.outgoing_mail)
              : null,
        ),
        trailing: NeumorphicIconButton(
          icon: Icons.delete_forever_rounded,
          iconColor: theme.colorScheme.error,
          tooltip: 'Cancel Invitation',
          iconSize: 20,
          onTap: () async {
            try {
              await provider.cancelRoomInvitation(invite.id);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    provider.error ?? 'Could not cancel invitation',
                  ),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
