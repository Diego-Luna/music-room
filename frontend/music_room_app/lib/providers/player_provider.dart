import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:music_room_app/core/audio/audio_player_service.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/account_device.dart';
import 'package:music_room_app/models/music_control_delegation.dart';
import 'package:music_room_app/core/repositories/device_repository.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';

class PlayerProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  final RoomsProvider _roomsProvider;
  final DeviceRepository _deviceRepository;
  final AudioPlayer _audioPlayer;
  final AudioPlayerService _audio;

  List<AccountDevice> devices = [];
  List<MusicControlDelegation> controlledDevices = [];
  String? activeDelegationId;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Track? _currentTrack;
  bool _isPlaying = false;
  String? _error;

  PlayerProvider({
    required AuthProvider authProvider,
    required RoomsProvider roomsProvider,
    required DeviceRepository deviceRepository,
    AudioPlayer? audioPlayer,
    AudioPlayerService? audioService,
  }) : _authProvider = authProvider,
       _roomsProvider = roomsProvider,
       _deviceRepository = deviceRepository,
       _audioPlayer = audioPlayer ?? AudioPlayer(),
       _audio =
           audioService ?? (throw UnimplementedError('Provide audioService')) {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
    // For just_audio:
    _audio.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _audio.durationStream.listen((d) {
      if (d != null) {
        _duration = d;
        notifyListeners();
      }
    });
    _audio.playingStream.listen((p) {
      _isPlaying = p;
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

  Future<void> fetchDevices() async {
    try {
      devices = await _deviceRepository.getDevices();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch devices: $e';
      notifyListeners();
    }
  }

  Future<void> fetchControlledDevices() async {
    try {
      controlledDevices = await _deviceRepository.getControlledDevices();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch controlled devices: $e';
      notifyListeners();
    }
  }

  void setActiveDelegation(String delegationId) {
    activeDelegationId = delegationId;
    notifyListeners();
  }

  // * Delegate remote commands
  Future<void> sendPlayCommand({List<String>? uris}) async {
    if (activeDelegationId != null) {
      try {
        await _deviceRepository.playPlayback(activeDelegationId!, uris: uris);
      } catch (e) {
        _error = 'Failed to send play command: $e';
        notifyListeners();
      }
    }
  }

  Future<void> sendPauseCommand() async {
    if (activeDelegationId != null) {
      try {
        await _deviceRepository.pausePlayback(activeDelegationId!);
      } catch (e) {
        _error = 'Failed to send pause command: $e';
        notifyListeners();
      }
    }
  }

  Future<void> sendNextCommand() async {
    if (activeDelegationId != null) {
      try {
        await _deviceRepository.nextTrack(activeDelegationId!);
      } catch (e) {
        _error = 'Failed to send next command: $e';
        notifyListeners();
      }
    }
  }

  Future<void> sendPreviousCommand() async {
    if (activeDelegationId != null) {
      try {
        await _deviceRepository.previousTrack(activeDelegationId!);
      } catch (e) {
        _error = 'Failed to send previous command: $e';
        notifyListeners();
      }
    }
  }

  Future<void> sendVolumeCommand(int percent) async {
    if (activeDelegationId != null) {
      try {
        await _deviceRepository.setVolume(activeDelegationId!, percent);
      } catch (e) {
        _error = 'Failed to send volume command: $e';
        notifyListeners();
      }
    }
  }

  // * Owner command receiver
  void handlePlaybackCommand(Map<String, dynamic> data) async {
    final action = data['action'] as String?;
    final trackUri = data['trackUri'] as String?;

    try {
      switch (action) {
        case 'play':
          if (trackUri != null) {
            await _audioPlayer.play(UrlSource(trackUri));
          } else {
            await _audioPlayer.resume();
          }
          break;
        case 'pause':
          await _audioPlayer.pause();
          break;
        case 'stop':
          await _audioPlayer.stop();
          break;
        case 'volume':
          final vol = (data['percent'] as num?)?.toDouble() ?? 50.0;
          await _audioPlayer.setVolume(vol / 100.0);
          break;
      }
    } catch (e) {
      _error = 'Playback command failed: $e';
      notifyListeners();
    }
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
    _audioPlayer.dispose();
    _audio.dispose();
    super.dispose();
  }
}
