import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/profile_provider.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // * Page owns its own provider → no global registration needed (isolated).
  final ProfileProvider _profile = ProfileProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _profile.loadProfile());
  }

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    final auth = context.read<AuthProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signing out...'),
        duration: Duration(milliseconds: 1000),
      ),
    );
    await auth.logout();
    if (mounted) context.go(routeLogin);
  }

  String _visibilityLabel(UserVisibility v) {
    switch (v) {
      case UserVisibility.public:
        return 'Public';
      case UserVisibility.friendsOnly:
        return 'Friends only';
      case UserVisibility.private:
        return 'Private';
    }
  }

  void _showResult(bool ok, String title) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '$title updated' : (_profile.error ?? 'Update failed')),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
      ),
    );
  }

  // * Generic text editor (one or multi line) → calls onSave with the new text.
  Future<void> _editText({
    required String title,
    required String? current,
    required Future<bool> Function(String value) onSave,
    bool multiline = true,
  }) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: multiline ? 4 : 1,
          minLines: 1,
          decoration: InputDecoration(hintText: title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return; // cancelled
    final ok = await onSave(result.trim());
    _showResult(ok, title);
  }

  Future<void> _editVisibility(UserVisibility current) async {
    final selected = await showDialog<UserVisibility>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Profile visibility'),
        children: [
          RadioGroup<UserVisibility>(
            groupValue: current,
            onChanged: (val) => Navigator.pop(ctx, val),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: UserVisibility.values
                  .map(
                    (v) => RadioListTile<UserVisibility>(
                      value: v,
                      title: Text(_visibilityLabel(v)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    final ok = await _profile.updateProfile(visibility: selected);
    _showResult(ok, 'Visibility');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Opacity(opacity: 0.3, child: BackgroundFloaters()),
          ListenableBuilder(
            listenable: _profile,
            builder: (context, _) {
              final user = _profile.profile;

              if (user == null && _profile.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (user == null) {
                return _buildError(theme);
              }
              return _buildContent(theme, user);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _profile.error ?? 'Could not load your profile.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppDimens.lg),
          PrimaryButton(label: 'Retry', onPressed: _profile.loadProfile),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, User user) {
    // * The 4 subject fields + visibility, all wired to PATCH /users/me.
    final fields = <Map<String, dynamic>>[
      {
        'title': 'Public Information',
        'icon': Icons.public,
        'value': user.publicInfo,
        'onEdit': () => _editText(
          title: 'Public Information',
          current: user.publicInfo,
          onSave: (v) => _profile.updateProfile(publicInfo: v),
        ),
      },
      {
        'title': 'Friends Only Info',
        'icon': Icons.group,
        'value': user.friendsInfo,
        'onEdit': () => _editText(
          title: 'Friends Only Info',
          current: user.friendsInfo,
          onSave: (v) => _profile.updateProfile(friendsInfo: v),
        ),
      },
      {
        'title': 'Private Information',
        'icon': Icons.lock,
        'value': user.privateInfo,
        'onEdit': () => _editText(
          title: 'Private Information',
          current: user.privateInfo,
          onSave: (v) => _profile.updateProfile(privateInfo: v),
        ),
      },
      {
        'title': 'Music Preferences',
        'icon': Icons.library_music,
        'value': user.musicPreferences.join(', '),
        'onEdit': () => _editText(
          title: 'Music Preferences',
          current: user.musicPreferences.join(', '),
          multiline: false,
          onSave: (v) => _profile.updateProfile(
            musicPreferences: v
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
          ),
        ),
      },
      {
        'title': 'Visibility',
        'icon': Icons.visibility_outlined,
        'value': _visibilityLabel(user.visibility),
        'onEdit': () => _editVisibility(user.visibility),
      },
    ];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('Profile'),
          centerTitle: true,
          expandedHeight: 250.0,
          floating: true,
          pinned: false,
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => context.push(routeSettings),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: AppDimens.xxl),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                    boxShadow: theme
                        .extension<AppDesignTokens>()
                        ?.neumorphicShadow,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppDimens.sm),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 45,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                Text(
                  user.displayName,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: AppTypography.extraBold,
                  ),
                ),
                const SizedBox(height: AppDimens.xs),
                Text(
                  user.email,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.disabledColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.xl,
            vertical: AppDimens.md,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final field = fields[index];
              return StaggeredList(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.lg),
                  child: _buildEditableField(
                    theme,
                    field['title'] as String,
                    field['value'] as String?,
                    field['icon'] as IconData,
                    field['onEdit'] as VoidCallback,
                  ),
                ),
              );
            }, childCount: fields.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.xl,
              vertical: AppDimens.lg,
            ),
            child: StaggeredList(
              index: fields.length,
              child: PrimaryButton(
                label: 'Log Out',
                leading: Icon(
                  Icons.logout,
                  color: theme.colorScheme.primary,
                  size: AppDimens.iconMedium,
                ),
                onPressed: _handleLogout,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppDimens.xxl * 3),
        ),
      ],
    );
  }

  Widget _buildEditableField(
    ThemeData theme,
    String title,
    String? value,
    IconData icon,
    VoidCallback onEdit,
  ) {
    final tokens = theme.extension<AppDesignTokens>();
    final hasValue = value != null && value.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.xs,
            bottom: AppDimens.sm,
          ),
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: AppTypography.bold,
              color: theme.disabledColor,
            ),
          ),
        ),
        NeumorphicInteractiveContainer(
          onTap: onEdit,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                tokens?.cardRadius ??
                BorderRadius.circular(AppDimens.radiusLarge),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg,
            vertical: AppDimens.lg,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: theme.colorScheme.primary,
                size: AppDimens.iconMedium,
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Text(
                  hasValue ? value : 'Not set',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: AppTypography.medium,
                    color: hasValue ? null : theme.disabledColor,
                  ),
                ),
              ),
              Icon(
                Icons.edit_rounded,
                color: theme.disabledColor,
                size: AppDimens.iconSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
