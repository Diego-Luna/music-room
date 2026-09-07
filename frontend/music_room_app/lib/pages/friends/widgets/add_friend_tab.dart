import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/pages/auth/widgets/auth_text_field.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/providers/friends_provider.dart';

class AddFriendTab extends StatefulWidget {
  final FriendsProvider provider;
  final VoidCallback onSearchByName;

  const AddFriendTab({
    super.key,
    required this.provider,
    required this.onSearchByName,
  });

  @override
  State<AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends State<AddFriendTab> {
  final _uuidController = TextEditingController();

  @override
  void dispose() {
    _uuidController.dispose();
    super.dispose();
  }

  void _handleAddFriend() async {
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
      await widget.provider.sendRequest(uuid);
      if (!mounted) return;
      _uuidController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Friend request sent successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      widget.provider.setView(FriendsView.friends);
      widget.provider.fetchFriendsData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.provider.error ?? 'Failed to send friend request',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              'Search people by name, or paste a User ID (UUID) directly.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: AppDimens.xl),
            PrimaryButton(
              label: 'Search by name',
              leading: Icon(
                Icons.search,
                color: theme.colorScheme.primary,
                size: AppDimens.iconMedium,
              ),
              onPressed: widget.onSearchByName,
            ),
            const SizedBox(height: AppDimens.xl),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                  child: Text(
                    'or by ID',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
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
              isLoading: widget.provider.isLoading,
              onPressed: _handleAddFriend,
            ),
          ],
        ),
      ),
    );
  }
}
