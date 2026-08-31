import 'package:flutter/material.dart';
import 'package:music_room_app/core/globals.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/services/proximity_service.dart';
import 'package:music_room_app/core/services/proximity_watcher.dart';
import 'package:music_room_app/pages/events/widgets/proximity_approach_sheet.dart';
import 'package:music_room_app/providers/events_provider.dart';

/// Starts [ProximityWatcher] and presents the VI.2 approach sheet anywhere
/// in the app when the user enters a public event's venue zone.
class ProximityHost extends StatefulWidget {
  final Widget child;
  final EventsProvider events;

  const ProximityHost({super.key, required this.events, required this.child});

  @override
  State<ProximityHost> createState() => _ProximityHostState();
}

class _ProximityHostState extends State<ProximityHost> {
  late final ProximityWatcher _watcher;

  @override
  void initState() {
    super.initState();
    _watcher = ProximityWatcher(events: widget.events)..onNearby = _announce;
    _watcher.start();
  }

  @override
  void dispose() {
    _watcher.stop();
    super.dispose();
  }

  void _announce(NearbyEvent hit) {
    final ctx = rootScaffoldMessengerKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    ProximityApproachSheet.show(
      ctx,
      nearby: hit,
      onOpen: () {
        widget.events.selectEvent(hit.room);
        AppRouter.router.go(
          '$routeEvents/$routeEventDetail',
          extra: {'event': hit.room},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
