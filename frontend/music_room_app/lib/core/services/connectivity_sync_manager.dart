import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/models/offline_action.dart';
import 'package:music_room_app/models/track.dart';

// * One queued action that the server permanently rejected during sync,
// * carrying a human-readable cause so the UI can tell the user why.
class SyncDiscard {
  final String label;
  final String reason;
  const SyncDiscard({required this.label, required this.reason});
}

class ConnectivitySyncManager {
  final RoomRepository _remote;
  final OfflineCache _cache;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

  final StreamController<List<SyncDiscard>> _discardController =
      StreamController<List<SyncDiscard>>.broadcast();

  // * Emits, after each sync run, the actions the server permanently rejected
  // * (with their cause). Empty rejections are never emitted.
  Stream<List<SyncDiscard>> get discards => _discardController.stream;

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

    final List<SyncDiscard> rejected = [];

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
          } else if (action.type == 'addTrack' ||
              action.type == 'addPlaylistTrack') {
            final track = Track.fromJson(
              Map<String, dynamic>.from(action.payload),
            );
            await _remote.addPlaylistTrack(action.roomId, track);
          } else if (action.type == 'addVoteTrack') {
            final track = Track.fromJson(
              Map<String, dynamic>.from(action.payload),
            );
            await _remote.addVoteTrack(action.roomId, track);
          } else if (action.type == 'removePlaylistTrack') {
            final trackId = action.payload['trackId'] as String;
            await _remote.removePlaylistTrack(action.roomId, trackId);
          } else if (action.type == 'move') {
            final trackId = action.payload['trackId'] as String;
            final newPosition = action.payload['newPosition'] as String;
            await _remote.movePlaylistTrack(
              action.roomId,
              trackId,
              newPosition,
            );
          }
          // * Success -> Remove from queue
          await _cache.removeAction(action.id);
        } catch (e) {
          final status = _statusCodeOf(e);
          final isPermanent =
              status != null && status >= 400 && status < 500 && status != 401;
          // ! 401 (auth), 5xx and network errors are transient -> pause & retry.
          if (!isPermanent) break;

          // * Permanent client error: discard so one bad action can't freeze
          // * the whole queue. 409 (already applied) and 404 on a removal
          // * (already gone) reach the desired end-state -> stay silent.
          // * Anything else was genuinely rejected -> report it to the user.
          final isRemoval = action.type.startsWith('remove');
          final idempotentSuccess =
              status == 409 || (status == 404 && isRemoval);
          if (!idempotentSuccess) {
            rejected.add(
              SyncDiscard(
                label: _labelFor(action.type),
                reason: _reasonFor(e, status),
              ),
            );
          }
          await _cache.removeAction(action.id);
        }
      }

      if (rejected.isNotEmpty) {
        _discardController.add(List.unmodifiable(rejected));
      }

      // * Queue finished -> refresh room metadata from server. The list
      // * endpoint does NOT return tracks, so saving as-is would wipe the
      // * cached track lists. Preserve them when the snapshot has none.
      final rooms = await _remote.getRooms();
      // * getRooms() is the full, unfiltered set -> safe to purge ghosts
      // * (rooms deleted elsewhere) from the cache.
      await _cache.deleteRoomsExcept(rooms.map((r) => r.id).toSet());
      final merged = rooms.map((room) {
        if (room.tracks.isNotEmpty) return room;
        final cached = _cache.getRoomById(room.id);
        return cached != null ? room.copyWith(tracks: cached.tracks) : room;
      }).toList();
      await _cache.saveRooms(merged);
    } catch (_) {
      // * Silent fallback on errors
    } finally {
      _isSyncing = false;
    }
  }

  // * Extracts the HTTP status from a thrown error. DioException carries it
  // * directly; for other errors we parse a "status code of XXX" hint.
  int? _statusCodeOf(Object e) {
    if (e is DioException) return e.response?.statusCode;
    final match = RegExp(r'status code of (\d{3})').firstMatch(e.toString());
    return match != null ? int.parse(match.group(1)!) : null;
  }

  // * Short label of the action type for user-facing messages.
  String _labelFor(String type) {
    switch (type) {
      case 'vote':
        return 'Vote';
      case 'addTrack':
      case 'addPlaylistTrack':
        return 'Add to playlist';
      case 'addVoteTrack':
        return 'Track suggestion';
      case 'removePlaylistTrack':
        return 'Remove from playlist';
      case 'move':
        return 'Reorder';
      default:
        return 'Change';
    }
  }

  // * Precise cause, preferring the backend message (e.g. "Voting is closed
  // * for this room", "Premium subscription required"), then a fallback.
  String _reasonFor(Object e, int? status) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        if (message is List && message.isNotEmpty) {
          return message.first.toString();
        }
        return message.toString();
      }
    }
    switch (status) {
      case 403:
        return 'Not allowed (session closed or no permission)';
      case 404:
        return 'No longer exists';
      case 400:
      case 422:
        return 'Invalid request';
      default:
        return 'Rejected by the server';
    }
  }
}
