import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/invitation.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/pages/auth/widgets/auth_text_field.dart';
import 'package:music_room_app/widgets/primary_button.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _uuidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendsProvider>().fetchFriendsData();
      context.read<NotificationsProvider>().fetchNotifications();
    });
  }

  @override
  void dispose() {
    _uuidController.dispose();
    super.dispose();
  }

  void _handleAddFriend(FriendsProvider provider) async {
    final uuid = _uuidController.text.trim();
    if (uuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a User ID'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    try {
      await provider.sendRequest(uuid);
      if (!mounted) return;
      _uuidController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Friend request sent successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      provider.setView(FriendsView.friends);
      provider.fetchFriendsData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to send friend request'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendsProvider>();
    final notificationsProv = context.watch<NotificationsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),
          if ((provider.isLoading || notificationsProv.isLoading) &&
              provider.friends.isEmpty &&
              notificationsProv.incomingFriendRequests.isEmpty &&
              notificationsProv.roomInvitations.isEmpty &&
              notificationsProv.outgoingFriendRequests.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120.0,
                  toolbarHeight: 76.0,
                  floating: true,
                  pinned: false,
                  backgroundColor: theme.scaffoldBackgroundColor.withValues(
                    alpha: 0.8,
                  ),
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(
                      left: AppDimens.lg,
                      bottom: AppDimens.md,
                    ),
                    title: Text(
                      'Friends',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: AppTypography.extraBold,
                      ),
                    ),
                  ),
                  actions: [
                    _buildTabButton(
                      icon: Icons.people_outline_rounded,
                      tooltip: 'My Friends',
                      isActive: provider.currentView == FriendsView.friends,
                      onTap: () => provider.setView(FriendsView.friends),
                    ),
                    _buildTabButton(
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'Requests',
                      isActive: provider.currentView == FriendsView.requests,
                      badgeCount:
                          notificationsProv.incomingFriendRequests.length +
                          notificationsProv.roomInvitations.length,
                      onTap: () => provider.setView(FriendsView.requests),
                    ),
                    _buildTabButton(
                      icon: Icons.person_add_alt_1_rounded,
                      tooltip: 'Add Friend',
                      isActive: provider.currentView == FriendsView.add,
                      onTap: () => provider.setView(FriendsView.add),
                    ),
                  ],
                ),

                if (provider.currentView == FriendsView.friends)
                  _buildFriendsList(provider, theme)
                else if (provider.currentView == FriendsView.requests)
                  ..._buildRequestsList(notificationsProv, theme)
                else
                  _buildAddFriendForm(provider, theme),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return NeumorphicIconButton(
      icon: icon,
      tooltip: tooltip,
      isForcedPressed: isActive,
      onTap: onTap,
      badgeCount: badgeCount,
    );
  }

  Widget _buildFriendsList(FriendsProvider provider, ThemeData theme) {
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
                    if (!mounted) return;
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

  List<Widget> _buildRequestsList(
    NotificationsProvider provider,
    ThemeData theme,
  ) {
    final hasFriendRequests = provider.incomingFriendRequests.isNotEmpty;
    final hasRoomInvitations = provider.roomInvitations.isNotEmpty;
    final hasOutgoing = provider.outgoingFriendRequests.isNotEmpty;

    if (!hasFriendRequests && !hasRoomInvitations && !hasOutgoing) {
      return [
        const SliverFillRemaining(
          child: Center(child: Text('No pending requests.')),
        ),
      ];
    }

    final List<Widget> slivers = [];

    if (hasRoomInvitations) {
      slivers.add(
        SliverToBoxAdapter(child: _buildHeaderSection('Room Invitations')),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (builderContext, index) => _buildRoomInvitationItem(
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
        SliverToBoxAdapter(child: _buildHeaderSection('Friend Requests')),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((builderContext, index) {
            final req = provider.incomingFriendRequests[index];
            final user = provider.userCache[req.requesterId];
            return user != null
                ? _buildIncomingRequestItem(provider, req, user)
                : const SizedBox.shrink();
          }, childCount: provider.incomingFriendRequests.length),
        ),
      );
    }

    if (hasOutgoing) {
      slivers.add(
        SliverToBoxAdapter(child: _buildHeaderSection('Outgoing Requests')),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((builderContext, index) {
            final req = provider.outgoingFriendRequests[index];
            final user = provider.userCache[req.addresseeId];
            return user != null
                ? _buildOutgoingRequestItem(provider, req, user)
                : const SizedBox.shrink();
          }, childCount: provider.outgoingFriendRequests.length),
        ),
      );
    }

    return slivers;
  }

  Widget _buildHeaderSection(String title) {
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

  Widget _buildRoomInvitationItem(
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
                } catch (e) {
                  if (!mounted) return;
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
                  if (!mounted) return;
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

  Widget _buildIncomingRequestItem(
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
                  if (!mounted) return;
                  context.read<FriendsProvider>().fetchFriendsData();
                } catch (e) {
                  if (!mounted) return;
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
                  if (!mounted) return;
                  context.read<FriendsProvider>().fetchFriendsData();
                } catch (e) {
                  if (!mounted) return;
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

  Widget _buildOutgoingRequestItem(
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
              if (!mounted) return;
              context.read<FriendsProvider>().fetchFriendsData();
            } catch (e) {
              if (!mounted) return;
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

  Widget _buildAddFriendForm(FriendsProvider provider, ThemeData theme) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppDimens.md),
            Text(
              'Add a Friend',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              'Enter your friend\'s unique User ID (UUID) to send them a friendship request.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: AppDimens.xl),
            AuthTextField(
              hintText: 'User ID (UUID)',
              icon: Icons.vpn_key_rounded,
              controller: _uuidController,
            ),
            const SizedBox(height: AppDimens.xl),
            PrimaryButton(
              label: 'Send Request',
              isLoading: provider.isLoading,
              onPressed: () => _handleAddFriend(provider),
            ),
          ],
        ),
      ),
    );
  }
}
