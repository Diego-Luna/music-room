import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/models/offline_action.dart';
import 'package:music_room_app/models/track.dart';

class ConnectivitySyncManager {
  final RoomRepository _remote;
  final OfflineCache _cache;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

  ConnectivitySyncManager({
    required RoomRepository remoteRepository,
    required OfflineCache cache,
    Connectivity? connectivity,
  }) : _remote = remoteRepository,
       _cache = cache,
       _connectivity = connectivity ?? Connectivity();

  // * Start listening to connectivity events in foreground
  void startMonitoring() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // * React if transition leads to internet connectivity options
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && !_isSyncing) {
        syncQueue();
      }
    });
  }

  void stopMonitoring() {
    _subscription?.cancel();
  }

  Future<void> syncQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final List<OfflineAction> actions = _cache.getPendingActions();
      for (final OfflineAction action in actions) {
        try {
          if (action.type == 'vote') {
            final trackId = action.payload['trackId'] as String;
            final value = action.payload['value'] as int;
            final lat = action.payload['lat'] as double?;
            final lng = action.payload['lng'] as double?;
            await _remote.voteForTrack(
              action.roomId,
              trackId,
              value,
              lat: lat,
              lng: lng,
            );
          } else if (action.type == 'addTrack') {
            final track = Track.fromJson(
              Map<String, dynamic>.from(action.payload),
            );
            await _remote.addPlaylistTrack(action.roomId, track);
          }
          // * Success -> Remove from queue
          await _cache.removeAction(action.id);
        } catch (e) {
          // ! If conflict (409) is returned, discard it as idempotent success
          if (e.toString().contains('409') ||
              e.toString().contains('Conflict')) {
            await _cache.removeAction(action.id);
          } else {
            // ! Real network error -> pause processing queue
            break;
          }
        }
      }

      // * Queue finished successfully -> pull snapshot to refresh cache
      final rooms = await _remote.getRooms();
      await _cache.saveRooms(rooms);
    } catch (_) {
      // * Silent fallback on errors
    } finally {
      _isSyncing = false;
    }
  }
}
