import 'package:flutter/material.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';

class PlayerProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  final RoomsProvider _roomsProvider;

  Track? _currentTrack;
  bool _isPlaying = false;
  String? _error;

  PlayerProvider({
    required AuthProvider authProvider,
    required RoomsProvider roomsProvider,
  }) : _authProvider = authProvider,
       _roomsProvider = roomsProvider;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  String? get error => _error;

  bool get hasControlPermission {
    final activeRoom = _roomsProvider.currentActiveRoom;
    if (activeRoom == null) return true;
    final currentUser = _authProvider.user;
    if (currentUser == null) return false;
    return activeRoom.currentControllerId == currentUser.id;
  }

  void playTrack(Track track) {
    _error = null;
    if (!hasControlPermission) {
      _error = 'You do not have permission to control the player in this room.';
      notifyListeners();
      return;
    }
    _currentTrack = track;
    _isPlaying = true;
    notifyListeners();
  }

  void resume() {
    _error = null;
    if (!hasControlPermission) {
      _error = 'You do not have permission to control the player in this room.';
      notifyListeners();
      return;
    }
    if (_currentTrack != null) {
      _isPlaying = true;
      notifyListeners();
    }
  }

  void pause() {
    _error = null;
    if (!hasControlPermission) {
      _error = 'You do not have permission to control the player in this room.';
      notifyListeners();
      return;
    }
    _isPlaying = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
