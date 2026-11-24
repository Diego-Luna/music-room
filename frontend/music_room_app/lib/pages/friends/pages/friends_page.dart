import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/widgets/shelf_chip.dart';
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
                _buildAppBar(context, theme),
                SliverToBoxAdapter(
                  child: _buildShelves(context, provider, notificationsProv),
                ),
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

  SliverAppBar _buildAppBar(BuildContext context, ThemeData theme) {
    return SliverAppBar(
      title: const Text('Friends'),
      centerTitle: true,
      floating: true,
      toolbarHeight: 76.0,
      pinned: false,
      backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
      elevation: 0,
    );
  }

  Widget _buildShelves(
    BuildContext context,
    FriendsProvider provider,
    NotificationsProvider notificationsProv,
  ) {
    final pendingCount =
        notificationsProv.incomingFriendRequests.length +
        notificationsProv.roomInvitations.length;
    final shelves = <(FriendsView, String, Key, int)>[
      (FriendsView.friends, 'Friends', const Key('friends_tab_friends'), 0),
      (
        FriendsView.requests,
        'Requests',
        const Key('friends_tab_requests'),
        pendingCount,
      ),
      (FriendsView.add, 'Add', const Key('friends_tab_add'), 0),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.md,
        AppDimens.lg,
        0,
      ),
      child: Row(
        children: [
          for (var i = 0; i < shelves.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimens.sm),
            Expanded(
              child: ShelfChip(
                key: shelves[i].$3,
                label: shelves[i].$2,
                badgeCount: shelves[i].$4,
                selected: provider.currentView == shelves[i].$1,
                onTap: () => provider.setView(shelves[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
