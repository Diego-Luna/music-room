import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';
import 'package:music_room_app/widgets/user_search_sheet.dart';
import 'package:music_room_app/pages/friends/widgets/friends_list_tab.dart';
import 'package:music_room_app/pages/friends/widgets/requests_list_tab.dart';
import 'package:music_room_app/pages/friends/widgets/add_friend_tab.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendsProvider>().fetchFriendsData();
      context.read<NotificationsProvider>().fetchNotifications();
    });
  }

  void _openUserSearch(FriendsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserSearchSheet(
        title: 'Find People',
        onSelected: (user) async {
          try {
            await provider.sendRequest(user.id);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Friend request sent to ${user.displayName}'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
            provider.fetchFriendsData();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.error ?? 'Failed to send request'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendsProvider>();
    final notificationsProv = context.watch<NotificationsProvider>();
    final theme = Theme.of(context);

    final isInitialLoading =
        (provider.isLoading || notificationsProv.isLoading) &&
        provider.friends.isEmpty &&
        notificationsProv.incomingFriendRequests.isEmpty &&
        notificationsProv.roomInvitations.isEmpty &&
        notificationsProv.outgoingFriendRequests.isEmpty;

    return Scaffold(
      body: Stack(
        children: [
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),
          if (isInitialLoading)
            const Center(child: CircularProgressIndicator())
          else
            CustomScrollView(
              slivers: [
                _buildAppBar(context, provider, notificationsProv, theme),
                if (provider.currentView == FriendsView.friends)
                  FriendsListTab(provider: provider)
                else if (provider.currentView == FriendsView.requests)
                  ...RequestsListTab.buildSlivers(context, notificationsProv)
                else
                  AddFriendTab(
                    provider: provider,
                    onSearchByName: () => _openUserSearch(provider),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    FriendsProvider provider,
    NotificationsProvider notificationsProv,
    ThemeData theme,
  ) {
    final pendingCount =
        notificationsProv.incomingFriendRequests.length +
        notificationsProv.roomInvitations.length;

    return SliverAppBar(
      expandedHeight: 120.0,
      toolbarHeight: 76.0,
      floating: true,
      pinned: false,
      backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
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
        NeumorphicIconButton(
          icon: Icons.people_outline_rounded,
          tooltip: 'My Friends',
          isForcedPressed: provider.currentView == FriendsView.friends,
          onTap: () => provider.setView(FriendsView.friends),
        ),
        NeumorphicIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Requests',
          isForcedPressed: provider.currentView == FriendsView.requests,
          badgeCount: pendingCount,
          onTap: () => provider.setView(FriendsView.requests),
        ),
        NeumorphicIconButton(
          icon: Icons.person_add_alt_1_rounded,
          tooltip: 'Add Friend',
          isForcedPressed: provider.currentView == FriendsView.add,
          onTap: () => provider.setView(FriendsView.add),
        ),
      ],
    );
  }
}
