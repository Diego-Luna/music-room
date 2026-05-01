import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/core/animations/animated_scale_button.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _handleLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signing out...'),
        duration: Duration(milliseconds: 1000),
      ),
    );

    await auth.signOutPlaceholder();

    if (context.mounted) {
      context.go(routeLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // * The 4 exact fields requested by the 42 documentation
    final List<Map<String, dynamic>> profileFields = [
      {
        'title': 'Public Information',
        'icon': Icons.public,
        'value': 'Diego Luna - Music Lover',
      },
      {
        'title': 'Friends Only Info',
        'icon': Icons.group,
        'value': 'Currently playing: Queen',
      },
      {
        'title': 'Private Information',
        'icon': Icons.lock,
        'value': 'diego@example.com',
      },
      {
        'title': 'Music Preferences',
        'icon': Icons.library_music,
        'value': 'Rock, Classical, Electronic',
      },
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Ambient 3D floating models
          const Opacity(opacity: 0.3, child: BackgroundFloaters()),

          CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Profile'),
                centerTitle: true,
                expandedHeight: 250.0,
                floating: true, // Now it floats and disappears on scroll
                pinned: false, // Ensures it doesn't stay fixed
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
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
                        'Diego Luna',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: AppTypography.extraBold,
                        ),
                      ),
                      const SizedBox(height: AppDimens.xs),
                      Text(
                        '@diegoluna',
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
                    final field = profileFields[index];
                    return StaggeredList(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.lg),
                        child: _buildEditableField(
                          context,
                          field['title'] as String,
                          field['value'] as String,
                          field['icon'] as IconData,
                        ),
                      ),
                    );
                  }, childCount: profileFields.length),
                ),
              ),
              // Botón de Logout
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.xl,
                    vertical: AppDimens.lg,
                  ),
                  child: StaggeredList(
                    index: profileFields.length,
                    child: PrimaryButton(
                      label: 'Log Out',
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => _handleLogout(context),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppDimens.xxl * 3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

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
        AnimatedScaleButton(
          onPressed: () {
            // TODO: Open edit modal
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Edit $title coming soon...')),
            );
          },
          scaleDown: 0.98,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius:
                  tokens?.cardRadius ??
                  BorderRadius.circular(AppDimens.radiusLarge),
              boxShadow: tokens
                  ?.neumorphicPressedShadow, // Inset shadow for an "input field" look
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
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: AppTypography.medium,
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
        ),
      ],
    );
  }
}
