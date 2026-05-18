import 'package:flutter/material.dart';
import 'package:music_room_app/core/repositories/mock_api_repository.dart';
import 'package:music_room_app/models/playlist.dart';
import 'package:music_room_app/models/track.dart';

class PlaylistsProvider extends ChangeNotifier {
  final MockApiRepository _repository;
  List<Playlist> _playlists = [];
  bool _isLoading = false;
  String? _error;

  PlaylistsProvider({required MockApiRepository repository})
    : _repository = repository;

  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchPlaylists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _playlists = await _repository.getPlaylists();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTrack(String playlistId, Track track) async {
    try {
      await _repository.addTrackToPlaylist(playlistId, track);
      _playlists = await _repository.getPlaylists();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    try {
      await _repository.removeTrackFromPlaylist(playlistId, trackId);
      _playlists = await _repository.getPlaylists();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
