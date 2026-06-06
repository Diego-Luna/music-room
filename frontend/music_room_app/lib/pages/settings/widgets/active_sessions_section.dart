import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/models/session_info.dart';
import 'package:music_room_app/providers/auth_provider.dart';

//* Settings section listing active sessions with the ability to revoke them.
//* Backed by GET / DELETE /auth/sessions/:id.
class ActiveSessionsSection extends StatefulWidget {
  const ActiveSessionsSection({super.key});

  @override
  State<ActiveSessionsSection> createState() => _ActiveSessionsSectionState();
}

class _ActiveSessionsSectionState extends State<ActiveSessionsSection> {
  late Future<List<SessionInfo>> _future;
  final Set<String> _revoking = {};

  @override
  void initState() {
    super.initState();
    _future = context.read<AuthProvider>().listSessions();
  }

  void _reload() {
    setState(() {
      _future = context.read<AuthProvider>().listSessions();
    });
  }

  Future<void> _revoke(String id) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _revoking.add(id));
    try {
      await auth.revokeSession(id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Session revoked')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _revoking.remove(id));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not revoke: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active sessions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _reload,
              ),
            ],
          ),
        ),
        FutureBuilder<List<SessionInfo>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Could not load sessions.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }
            final sessions = snapshot.data ?? [];
            if (sessions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('No active sessions.'),
              );
            }
            return Column(
              children: sessions.map((s) {
                final revoking = _revoking.contains(s.id);
                return ListTile(
                  leading: const Icon(Icons.devices),
                  title: Text(s.label),
                  subtitle: Text(
                    [
                      if (s.ip != null && s.ip!.isNotEmpty) s.ip!,
                      'since ${_formatDate(s.createdAt)}',
                    ].join(' • '),
                  ),
                  trailing: revoking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.logout),
                          tooltip: 'Revoke',
                          onPressed: () => _revoke(s.id),
                        ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
