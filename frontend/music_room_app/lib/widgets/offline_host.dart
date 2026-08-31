import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';

/// VI.4 — persistent bar when the device reports no network.
/// The rest of the tree stays usable: cached rooms / friends, queued votes
/// and playlist edits. Search, create, members, reorder stay online-only.
class OfflineHost extends StatefulWidget {
  final Widget child;
  final Connectivity? connectivity;

  const OfflineHost({super.key, required this.child, this.connectivity});

  @override
  State<OfflineHost> createState() => _OfflineHostState();
}

class _OfflineHostState extends State<OfflineHost> {
  late final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _connectivity = widget.connectivity ?? Connectivity();
    _connectivity.checkConnectivity().then(_apply);
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _apply(List<ConnectivityResult> results) {
    final offline = !results.any((r) => r != ConnectivityResult.none);
    if (!mounted || offline == _offline) return;
    setState(() => _offline = offline);
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return widget.child;

    final theme = Theme.of(context);
    return Column(
      children: [
        Material(
          color: theme.colorScheme.secondaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.md,
                vertical: AppDimens.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: AppDimens.lg,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Text(
                      'Offline — cached playlists and votes. Changes sync when you reconnect.',
                      key: const Key('offline_banner'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
