import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room_app/core/audio/audio_player_service.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';

class PlayerProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  final RoomsProvider _roomsProvider;
  final AudioPlayerService _audio;

  Track? _currentTrack;
  bool _isPlaying = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<void> _completedSub;

  PlayerProvider({
    required AuthProvider authProvider,
    required RoomsProvider roomsProvider,
    AudioPlayerService? audioService,
  }) : _authProvider = authProvider,
       _roomsProvider = roomsProvider,
       _audio = audioService ?? JustAudioPlayerService() {
    _positionSub = _audio.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durationSub = _audio.durationStream.listen((d) {
      if (d != null) {
        _duration = d;
        notifyListeners();
      }
    });
    _playingSub = _audio.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });
    _completedSub = _audio.completedStream.listen((_) {
      _isPlaying = false;
      _position = Duration.zero;
      notifyListeners();
    });
  }

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  String? get error => _error;
  Duration get position => _position;
  Duration get duration => _duration;

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
    final preview = track.previewUrl;
    if (preview == null || preview.isEmpty) {
      // We only have audio for tracks that carry a Deezer preview URL
      // (fresh search results). Surface it rather than fake playback.
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _error = 'No 30-second preview available for this track.';
      notifyListeners();
      return;
    }
    _isPlaying = true; // optimistic; the playing stream confirms shortly after
    _position = Duration.zero;
    notifyListeners();
    unawaited(_startPlayback(preview));
  }

  Future<void> _startPlayback(String url) async {
    try {
      await _audio.play(url);
    } catch (_) {
      _isPlaying = false;
      _error = 'Could not play this track.';
      notifyListeners();
    }
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
      unawaited(_audio.resume());
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
    unawaited(_audio.pause());
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // * Handler methods for socket events — a remote controller drove playback,
  //   so we mirror the state and play the same preview locally when available.
  void handlePlaybackPlayed(Track track) {
    _currentTrack = track;
    _isPlaying = true;
    _error = null;
    _position = Duration.zero;
    notifyListeners();
    final preview = track.previewUrl;
    if (preview != null && preview.isNotEmpty) {
      unawaited(_startPlayback(preview));
    }
  }

  void handlePlaybackPaused() {
    _isPlaying = false;
    _error = null;
    notifyListeners();
    unawaited(_audio.pause());
  }

  void handlePlaybackSkipped(Track track) {
    handlePlaybackPlayed(track);
  }

  void handlePlaybackVolumeChanged(double volume) {
    // * Local player volume adjustment logic
  }

  @override
  void dispose() {
    _positionSub.cancel();
    _durationSub.cancel();
    _playingSub.cancel();
    _completedSub.cancel();
    _audio.dispose();
    super.dispose();
  }
}
