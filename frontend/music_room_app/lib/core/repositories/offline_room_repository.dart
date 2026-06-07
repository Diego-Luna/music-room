import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/offline_action.dart';
import 'package:music_room_app/models/invitation.dart';

class OfflineRoomRepository implements RoomRepository {
  final RoomRepository _remote;
  final OfflineCache _cache;
  final Connectivity _connectivity;

  OfflineRoomRepository({
    required RoomRepository remoteRepository,
    required OfflineCache cache,
    Connectivity? connectivity,
  }) : _remote = remoteRepository,
       _cache = cache,
       _connectivity = connectivity ?? Connectivity();

  Future<bool> _isOnline() async {
    // ! Proactively check connectivity to avoid making network requests when offline.
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Room>> getRooms({RoomKind? kind}) async {
    if (!await _isOnline()) {
      // * Offline fallback
      final cached = _cache.getRooms();
      if (kind != null) {
        return cached.where((r) => r.kind == kind).toList();
      }
      return cached;
    }
    try {
      final rooms = await _remote.getRooms(kind: kind);
      await _cache.saveRooms(rooms);
      return rooms;
    } catch (_) {
      // * Offline fallback on exceptions (e.g. timeout or socket error)
      final cached = _cache.getRooms();
      if (kind != null) {
        return cached.where((r) => r.kind == kind).toList();
      }
      return cached;
    }
  }

  @override
  Future<Room> getRoomById(String id) async {
    if (!await _isOnline()) {
      final cached = _cache.getRoomById(id);
      if (cached != null) return cached;
      throw Exception('Offline: Room not found in cache');
    }
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
    if (!await _isOnline()) {
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
        updatedTracks.sort((a, b) => b.score.compareTo(a.score));
        await _cache.saveRoom(room.copyWith(tracks: updatedTracks));
      }

      // * Queue action
      final action = OfflineAction(
        id: 'vote-$roomId-$trackId-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'vote',
        payload: {'trackId': trackId, 'value': value, 'lat': lat, 'lng': lng},
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
      return;
    }

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
        updatedTracks.sort((a, b) => b.score.compareTo(a.score));
        await _cache.saveRoom(room.copyWith(tracks: updatedTracks));
      }

      // * Queue action
      final action = OfflineAction(
        id: 'vote-$roomId-$trackId-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'vote',
        payload: {'trackId': trackId, 'value': value, 'lat': lat, 'lng': lng},
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
    }
  }

  @override
  Future<Track> addPlaylistTrack(String roomId, Track track) async {
    if (!await _isOnline()) {
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
    String? description,
    String? voteAccess,
    String? voteWindow,
    DateTime? voteStartsAt,
    DateTime? voteEndsAt,
    double? voteLocationLat,
    double? voteLocationLng,
    double? voteLocationRadiusM,
  }) => _remote.createRoom(
    name: name,
    kind: kind,
    isPublic: isPublic,
    description: description,
    voteAccess: voteAccess,
    voteWindow: voteWindow,
    voteStartsAt: voteStartsAt,
    voteEndsAt: voteEndsAt,
    voteLocationLat: voteLocationLat,
    voteLocationLng: voteLocationLng,
    voteLocationRadiusM: voteLocationRadiusM,
  );

  @override
  Future<void> deleteRoom(String id) => _remote.deleteRoom(id);

  @override
  Future<void> joinRoom(String id) => _remote.joinRoom(id);

  @override
  Future<void> leaveRoom(String id) => _remote.leaveRoom(id);

  @override
  Future<void> inviteToRoom(String roomId, String userId) =>
      _remote.inviteToRoom(roomId, userId);

  @override
  Future<List<Track>> getVoteTracks(String roomId) async {
    if (!await _isOnline()) {
      return _cache.getRoomById(roomId)?.tracks ?? [];
    }
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
    if (!await _isOnline()) {
      // * Optimistic add locally
      final room = _cache.getRoomById(roomId);
      if (room != null) {
        final updatedTracks = List<Track>.from(room.tracks)..add(track);
        await _cache.saveRoom(room.copyWith(tracks: updatedTracks));
      }

      // * Queues in offline actions
      final action = OfflineAction(
        id: 'addVote-$roomId-${track.providerId}-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'addVoteTrack',
        payload: track.toJson(),
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
      return track;
    }
    try {
      return await _remote.addVoteTrack(roomId, track);
    } catch (_) {
      // * Optimistic add locally
      final room = _cache.getRoomById(roomId);
      if (room != null) {
        final updatedTracks = List<Track>.from(room.tracks)..add(track);
        await _cache.saveRoom(room.copyWith(tracks: updatedTracks));
      }

      // * Queues in offline actions
      final action = OfflineAction(
        id: 'addVote-$roomId-${track.providerId}-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'addVoteTrack',
        payload: track.toJson(),
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
      return track;
    }
  }

  @override
  Future<List<Track>> getPlaylistTracks(String roomId) async {
    if (!await _isOnline()) {
      return _cache.getRoomById(roomId)?.tracks ?? [];
    }
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
    if (!await _isOnline()) {
      final action = OfflineAction(
        id: 'move-$roomId-$trackId-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'move',
        payload: {'trackId': trackId, 'newPosition': newPosition},
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
      return;
    }
    try {
      await _remote.movePlaylistTrack(roomId, trackId, newPosition);
    } catch (_) {
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
  Future<void> removePlaylistTrack(String roomId, String trackId) async {
    if (!await _isOnline()) {
      // * Optimistic removal locally
      final room = _cache.getRoomById(roomId);
      if (room != null) {
        final updatedTracks = room.tracks
            .where((t) => t.id != trackId)
            .toList();
        await _cache.saveRoom(room.copyWith(tracks: updatedTracks));
      }

      // * Queue action
      final action = OfflineAction(
        id: 'removePlaylist-$roomId-$trackId-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'removePlaylistTrack',
        payload: {'trackId': trackId},
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
      return;
    }

    try {
      await _remote.removePlaylistTrack(roomId, trackId);
    } catch (_) {
      // * Optimistic removal locally
      final room = _cache.getRoomById(roomId);
      if (room != null) {
        final updatedTracks = room.tracks
            .where((t) => t.id != trackId)
            .toList();
        await _cache.saveRoom(room.copyWith(tracks: updatedTracks));
      }

      // * Queue action
      final action = OfflineAction(
        id: 'removePlaylist-$roomId-$trackId-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        type: 'removePlaylistTrack',
        payload: {'trackId': trackId},
        createdAt: DateTime.now(),
      );
      await _cache.enqueueAction(action);
    }
  }

  @override
  Future<List<Track>> searchTracks(String query) async {
    if (!await _isOnline()) {
      throw Exception('Search failed. Make sure you are online.');
    }
    return _remote.searchTracks(query);
  }

  @override
  Future<List<RoomInvitationDto>> getInvitations() async {
    if (!await _isOnline()) {
      throw Exception('Cannot fetch invitations while offline.');
    }
    return _remote.getInvitations();
  }

  @override
  Future<AcceptInvitationResultDto> acceptInvitation(
    String invitationId,
  ) async {
    if (!await _isOnline()) {
      throw Exception('Cannot accept invitations while offline.');
    }
    return _remote.acceptInvitation(invitationId);
  }

  @override
  Future<RoomInvitationDto> declineInvitation(String invitationId) async {
    if (!await _isOnline()) {
      throw Exception('Cannot decline invitations while offline.');
    }
    return _remote.declineInvitation(invitationId);
  }
}
