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
      _playlists = await _repository.getRooms(kind: RoomKind.playlist);
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
      _playlists = await _repository.getRooms(kind: RoomKind.playlist);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeTrack(String roomId, String trackId) async {
    try {
      await _repository.removePlaylistTrack(roomId, trackId);
      _playlists = await _repository.getRooms(kind: RoomKind.playlist);
      notifyListeners();
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
      _playlists = await _repository.getRooms(kind: RoomKind.playlist);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
