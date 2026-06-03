import 'package:flutter/material.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
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

  Future<void> fetchPlaylists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rooms = await _repository.getRooms(kind: RoomKind.playlist);
      final playlistRooms = rooms
          .where((room) => room.kind == RoomKind.playlist)
          .toList();
      final populatedRooms = await Future.wait(
        playlistRooms.map((playlistRoom) async {
          final tracks = await _repository.getPlaylistTracks(playlistRoom.id);
          return playlistRoom.copyWith(tracks: tracks);
        }),
      );
      _playlists = populatedRooms;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTrack(String roomId, Track track) async {
    try {
      await _repository.addPlaylistTrack(roomId, track);
      await fetchPlaylists();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeTrack(String roomId, String trackId) async {
    try {
      await _repository.removePlaylistTrack(roomId, trackId);
      await fetchPlaylists();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> moveTrack(
    String roomId,
    String trackId,
    String newPosition,
  ) async {
    try {
      await _repository.movePlaylistTrack(roomId, trackId, newPosition);
      await fetchPlaylists();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // * Handler methods for socket events
  void handleTrackAdded(Track track) {
    for (var i = 0; i < _playlists.length; i++) {
      final room = _playlists[i];
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
}
