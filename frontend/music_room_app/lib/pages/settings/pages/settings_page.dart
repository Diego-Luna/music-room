import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/auth/social_auth_service.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/pages/settings/widgets/active_sessions_section.dart';
import 'package:music_room_app/widgets/backend_url_section.dart';
import 'package:music_room_app/widgets/vote_location_section.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';

//* Settings page (Account Settings).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _linkAccount(
    BuildContext context,
    SocialProvider provider,
  ) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.linkSocial(provider);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${provider.label} account linked.'
              : (auth.error ?? 'Could not link ${provider.label}.'),
        ),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 76.0,
        title: const Text('Account Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Opacity(opacity: 0.3, child: BackgroundFloaters()),
          ListView(
            padding: const EdgeInsets.all(AppDimens.xl),
            children: [
              const BackendUrlSection(),
              const SizedBox(height: AppDimens.xxl),
              const VoteLocationSection(),
              const SizedBox(height: AppDimens.xxl),

              Text(
                'Subscription',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(height: AppDimens.md),
              NeumorphicInteractiveContainer(
                onTap: () => context.push(routeSubscription),
                padding: const EdgeInsets.all(AppDimens.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage subscription',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                          Text(
                            'Free / Premium plans',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.xxl),

              Text(
                'Linked accounts',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(height: AppDimens.md),
              NeumorphicInteractiveContainer(
                onTap: () => _linkAccount(context, SocialProvider.google),
                padding: const EdgeInsets.all(AppDimens.md),
                child: Row(
                  children: [
                    const Icon(Icons.g_mobiledata, size: 30),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Text(
                        'Link Google account',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.md),
              NeumorphicInteractiveContainer(
                onTap: () => _linkAccount(context, SocialProvider.facebook),
                padding: const EdgeInsets.all(AppDimens.md),
                child: Row(
                  children: [
                    const Icon(Icons.facebook, color: Colors.blue),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Text(
                        'Link Facebook account',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.xxl),

              Text(
                'Active Sessions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(height: AppDimens.md),
              const ActiveSessionsSection(),
            ],
          ),
        ],
      ),
    );
  }
}
