import 'package:flutter/material.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

// * Manages PLAYLIST-kind rooms
// * Its importnat for the collaborative ordered queues
class PlaylistsProvider extends ChangeNotifier {
  final RoomRepository _repository;
  List<Room> _playlists = [];
  bool _isLoading = false;
  String? _error;

  PlaylistsProvider({required RoomRepository repository})
    : _repository = repository;

  List<Room> get playlists => _playlists;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void>? _fetchPlaylistsFuture;
  int _fetchGeneration = 0;

  Future<void> fetchPlaylists({bool force = false}) async {
    if (_fetchPlaylistsFuture != null && !force) {
      return _fetchPlaylistsFuture!;
    }
    final generation = ++_fetchGeneration;
    final future = _doFetchPlaylists(generation);
    _fetchPlaylistsFuture = future;
    try {
      await future;
    } finally {
      if (_fetchPlaylistsFuture == future) {
        _fetchPlaylistsFuture = null;
      }
    }
  }

  Future<void> _doFetchPlaylists(int generation) async {
    if (generation != _fetchGeneration) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rooms = await _repository.getRooms(kind: RoomKind.playlist);
      if (generation != _fetchGeneration) return;
      final playlistRooms = rooms
          .where((room) => room.kind == RoomKind.playlist)
          .toList();
      final populatedRooms = await Future.wait(
        playlistRooms.map((playlistRoom) async {
          try {
            final tracks = await _repository.getPlaylistTracks(playlistRoom.id);
            return playlistRoom.copyWith(tracks: tracks);
          } catch (_) {
            return playlistRoom;
          }
        }),
      );
      if (generation != _fetchGeneration) return;
      _playlists = populatedRooms;
    } catch (e) {
      if (generation != _fetchGeneration) return;
      _error = e.toString();
    } finally {
      if (generation != _fetchGeneration) return;
      _isLoading = false;
      notifyListeners();
    }
  }

  // * Create a PLAYLIST-kind room. [editAccess] is the edit license:
  // * 'EVERYONE' (anyone with access can edit) or 'INVITED_ONLY'.
  Future<Room> createPlaylist({
    required String name,
    String? description,
    required bool isPublic,
    required String editAccess,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final created = _asOwner(
        await _repository.createRoom(
          name: name,
          kind: RoomKind.playlist,
          isPublic: isPublic,
          description: description,
          editAccess: editAccess,
        ),
      );
      _playlists = [
        created,
        ..._playlists.where((playlist) => playlist.id != created.id),
      ];
      notifyListeners();
      await fetchPlaylists(force: true);
      if (!_playlists.any((playlist) => playlist.id == created.id)) {
        _playlists = [created, ..._playlists];
      }
      return created;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // * The running API's create payload has no myRole. Without this stamp the
  // * new room matches no shelf until a later list refresh replaces it.
  Room _asOwner(Room room) =>
      room.myRole == 'OWNER' ? room : room.copyWith(myRole: 'OWNER');

  // * Invite a friend to a (private) playlist — POST /rooms/:id/invitations.
  // * Throws on failure so the dialog can surface the backend message.
  Future<void> inviteFriend(String roomId, String userId) async {
    await _repository.inviteToRoom(roomId, userId);
  }

  // * Delete a PLAYLIST-kind room (owner only — the backend enforces this and
  // * returns 403 otherwise). Removes it from the local list on success and
  // * rethrows on failure so the caller can surface the error and stay put.
  Future<void> deletePlaylist(String roomId) async {
    try {
      await _repository.deleteRoom(roomId);
      _playlists = _playlists.where((p) => p.id != roomId).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // * Owner/admin edits a playlist room's settings. Rethrows so the UI can
  //   surface the reason (e.g. Premium gate).
  Future<void> updatePlaylist(
    String roomId, {
    String? name,
    String? description,
    bool? isPublic,
    String? editAccess,
  }) async {
    try {
      final updated = await _repository.updateRoom(
        roomId,
        name: name,
        description: description,
        isPublic: isPublic,
        editAccess: editAccess,
      );
      final idx = _playlists.indexWhere((p) => p.id == roomId);
      if (idx != -1) {
        // Preserve the already-loaded tracks (update returns the room only).
        _playlists[idx] = updated.copyWith(tracks: _playlists[idx].tracks);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addTrack(String roomId, Track track) async {
    _error = null;
    try {
      await _repository.addPlaylistTrack(roomId, track);
      await fetchPlaylists(force: true);
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeTrack(String roomId, String trackId) async {
    _error = null;
    try {
      await _repository.removePlaylistTrack(roomId, trackId);
      await fetchPlaylists(force: true);
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  // * Reorder a track next to an anchor (exactly one of after/before). Rethrows
  //   so the UI can revert its optimistic order and surface the reason (e.g.
  //   Premium-gated). Always refetches to reconcile with the server order.
  Future<void> moveTrack(
    String roomId,
    String trackId, {
    String? afterTrackId,
    String? beforeTrackId,
  }) async {
    try {
      await _repository.movePlaylistTrack(
        roomId,
        trackId,
        afterTrackId: afterTrackId,
        beforeTrackId: beforeTrackId,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      await fetchPlaylists(force: true);
    }
  }

  // * Handler methods for socket events
  void handleTrackAdded(Track track) {
    final targetId = track.roomId;
    if (targetId == null) return;
    for (var i = 0; i < _playlists.length; i++) {
      final room = _playlists[i];
      if (room.id != targetId) continue;
      if (room.tracks.any((t) => t.id == track.id)) continue;
      final updatedTracks = List<Track>.from(room.tracks)..add(track);
      _playlists[i] = room.copyWith(tracks: updatedTracks);
    }
    notifyListeners();
  }

  void handleTrackMoved(String roomId, String trackId, String newPosition) {
    for (var i = 0; i < _playlists.length; i++) {
      final room = _playlists[i];
      if (room.id != roomId) continue;
      final idx = room.tracks.indexWhere((t) => t.id == trackId);
      if (idx != -1) {
        final updatedTrack = room.tracks[idx].copyWith(position: newPosition);
        final updatedTracks = List<Track>.from(room.tracks)
          ..[idx] = updatedTrack;
        updatedTracks.sort(
          (a, b) => (a.position ?? '').compareTo(b.position ?? ''),
        );
        _playlists[i] = room.copyWith(tracks: updatedTracks);
      }
    }
    notifyListeners();
  }

  void handleTrackRemoved(String trackId) {
    for (var i = 0; i < _playlists.length; i++) {
      final room = _playlists[i];
      if (room.tracks.any((t) => t.id == trackId)) {
        final updatedTracks = room.tracks
            .where((t) => t.id != trackId)
            .toList();
        _playlists[i] = room.copyWith(tracks: updatedTracks);
      }
    }
    notifyListeners();
  }

  /// V.6: reset user-scoped state on logout.
  void clear() {
    _playlists = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
