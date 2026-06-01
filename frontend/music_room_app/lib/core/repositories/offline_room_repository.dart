import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/offline_action.dart';

class OfflineRoomRepository implements RoomRepository {
  final RoomRepository _remote;
  final OfflineCache _cache;

  OfflineRoomRepository({
    required RoomRepository remoteRepository,
    required OfflineCache cache,
  }) : _remote = remoteRepository,
       _cache = cache;

  @override
  Future<List<Room>> getRooms({RoomKind? kind}) async {
    try {
      final rooms = await _remote.getRooms(kind: kind);
      await _cache.saveRooms(rooms);
      return rooms;
    } catch (_) {
      // * Offline fallback
      final cached = _cache.getRooms();
      if (kind != null) {
        return cached.where((r) => r.kind == kind).toList();
      }
      return cached;
    }
  }

  @override
  Future<Room> getRoomById(String id) async {
    try {
      final room = await _remote.getRoomById(id);
      await _cache.saveRoom(room);
      return room;
    } catch (_) {
      final cached = _cache.getRoomById(id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<void> voteForTrack(
    String roomId,
    String trackId,
    int value, {
    double? lat,
    double? lng,
  }) async {
    try {
      await _remote.voteForTrack(roomId, trackId, value, lat: lat, lng: lng);
    } catch (e) {
      // * Optimistic vote update locally
      final room = _cache.getRoomById(roomId);
      if (room != null) {
        final updatedTracks = room.tracks.map((t) {
          if (t.id == trackId) {
            final currentScore = t.score;
            return t.copyWith(score: currentScore + value);
          }
          return t;
        }).toList();
        await _cache.saveRoom(room.copyWith(tracks: updatedTracks));
      }

      // * Queue action
      final action = OfflineAction(
        id: 'vote-$roomId-$trackId-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'vote',
        payload: {'trackId': trackId, 'value': value, 'lat': ?lat, 'lng': ?lng},
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
    }
  }

  @override
  Future<Track> addPlaylistTrack(String roomId, Track track) async {
    try {
      return await _remote.addPlaylistTrack(roomId, track);
    } catch (e) {
      // * Optimistic add locally
      final room = _cache.getRoomById(roomId);
      if (room != null) {
        final updatedTracks = List<Track>.from(room.tracks)..add(track);
        await _cache.saveRoom(room.copyWith(tracks: updatedTracks));
      }

      // * Queue action
      final action = OfflineAction(
        id: 'addPlaylist-$roomId-${track.providerId}-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'addTrack',
        payload: track.toJson(),
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
      return track;
    }
  }

  // * Fallbacks for Room creation / manipulation (usually disabled offline, but kept for signature)
  @override
  Future<Room> createRoom({
    required String name,
    required RoomKind kind,
    required bool isPublic,
  }) => _remote.createRoom(name: name, kind: kind, isPublic: isPublic);

  @override
  Future<void> deleteRoom(String id) => _remote.deleteRoom(id);

  @override
  Future<void> joinRoom(String id) => _remote.joinRoom(id);

  @override
  Future<void> leaveRoom(String id) => _remote.leaveRoom(id);

  @override
  Future<List<Track>> getVoteTracks(String roomId) async {
    try {
      final tracks = await _remote.getVoteTracks(roomId);
      final room = _cache.getRoomById(roomId);
      if (room != null) await _cache.saveRoom(room.copyWith(tracks: tracks));
      return tracks;
    } catch (_) {
      return _cache.getRoomById(roomId)?.tracks ?? [];
    }
  }

  @override
  Future<Track> addVoteTrack(String roomId, Track track) async {
    try {
      return await _remote.addVoteTrack(roomId, track);
    } catch (_) {
      // * Queues in offline actions
      final action = OfflineAction(
        id: 'addVote-$roomId-${track.providerId}-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'addTrack',
        payload: track.toJson(),
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
      return track;
    }
  }

  @override
  Future<void> removeVoteTrack(String roomId, String trackId) =>
      _remote.removeVoteTrack(roomId, trackId);

  @override
  Future<List<Track>> getPlaylistTracks(String roomId) async {
    try {
      final tracks = await _remote.getPlaylistTracks(roomId);
      final room = _cache.getRoomById(roomId);
      if (room != null) await _cache.saveRoom(room.copyWith(tracks: tracks));
      return tracks;
    } catch (_) {
      return _cache.getRoomById(roomId)?.tracks ?? [];
    }
  }

  @override
  Future<void> movePlaylistTrack(
    String roomId,
    String trackId,
    String newPosition,
  ) async {
    try {
      await _remote.movePlaylistTrack(roomId, trackId, newPosition);
    } catch (_) {
      // ? Moves are not handled dynamically offline, but can be enqueued if needed
      final action = OfflineAction(
        id: 'move-$roomId-$trackId-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'move',
        payload: {'trackId': trackId, 'newPosition': newPosition},
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
    }
  }

  @override
  Future<void> removePlaylistTrack(String roomId, String trackId) =>
      _remote.removePlaylistTrack(roomId, trackId);

  @override
  Future<void> delegateRoomControl(String roomId, String userId) =>
      _remote.delegateRoomControl(roomId, userId);

  @override
  Future<void> revokeRoomControl(String roomId) =>
      _remote.revokeRoomControl(roomId);
}
