import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/auth/social_auth_service.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/providers/auth_provider.dart';

//* Settings page.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Subscription',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: const Text('Manage subscription'),
            subtitle: const Text('Free / Premium plans'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(routeSubscription),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Linked accounts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.g_mobiledata, size: 30),
            title: const Text('Link Google account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _linkAccount(context, SocialProvider.google),
          ),
          ListTile(
            leading: const Icon(Icons.facebook, color: Colors.blue),
            title: const Text('Link Facebook account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _linkAccount(context, SocialProvider.facebook),
          ),
        ],
      ),
    );
  }
}
