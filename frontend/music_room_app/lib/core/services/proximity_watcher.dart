import 'package:music_room_app/config/location_config.dart';
import 'package:music_room_app/core/services/proximity_service.dart';
import 'package:music_room_app/providers/events_provider.dart';

/// App-wide geofence listener (VI.2). iBeacon analogue: when the current
/// position enters a public geo event, callers get [onNearby] once per stay.
class ProximityWatcher {
  ProximityWatcher({required EventsProvider events}) : _events = events;

  static ProximityWatcher? instance;

  final EventsProvider _events;
  final Set<String> _insideIds = {};
  void Function(NearbyEvent hit)? onNearby;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    instance = this;
    _events.addListener(_scan);
    LocationConfig.listenable.addListener(_scan);
    _scan();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _events.removeListener(_scan);
    LocationConfig.listenable.removeListener(_scan);
    if (instance == this) instance = null;
  }

  /// Show the approach again for [roomId] (Events demo button).
  void replay(String roomId) {
    _insideIds.remove(roomId);
    _scan();
  }

  void _scan() {
    final position = LocationConfig.current;
    if (position == null) {
      _insideIds.clear();
      return;
    }

    final hits = ProximityService.findNearbyPublicEvents(
      position: position,
      events: _events.events,
    );
    final hitIds = hits.map((h) => h.room.id).toSet();
    _insideIds.removeWhere((id) => !hitIds.contains(id));

    for (final hit in hits) {
      if (_insideIds.contains(hit.room.id)) continue;
      _insideIds.add(hit.room.id);
      onNearby?.call(hit);
      break;
    }
  }
}
