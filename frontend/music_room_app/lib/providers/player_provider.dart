import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:music_room_app/config/token_storage.dart';
import 'package:music_room_app/core/audio/audio_player_service.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/account_device.dart';
import 'package:music_room_app/models/music_control_delegation.dart';
import 'package:music_room_app/core/repositories/device_repository.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';

/// Off, then the whole queue, then the current track only.
enum PlaybackRepeat { off, all, one }

class PlayerProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  final DeviceRepository _deviceRepository;
  final AudioPlayerService _audio;
  final Future<String> Function() _getLocalDeviceId;

  List<AccountDevice> devices = [];
  List<MusicControlDelegation> controlledDevices = [];
  String? activeDelegationId;
  Timer? _delegationFetchDebounce;

  // * Bumps only when a delegation is revoked, so Devices can reload its
  //   own lists without reacting to playback ticks.
  final ValueNotifier<int> delegationRevision = ValueNotifier(0);

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // * Set when the current clip has finished and nothing follows. Freezes the
  //   bar at the end and ignores the engine's leftover "still playing" ticks
  //   until the user presses play, which restarts the clip from the beginning.
  bool _playbackCompleted = false;

  Track? _currentTrack;
  bool _isPlaying = false;
  String? _error;

  PlayerProvider({
    required AuthProvider authProvider,
    required RoomsProvider roomsProvider,
    required DeviceRepository deviceRepository,
    required AudioPlayerService audioService,
    Future<String> Function()? getLocalDeviceId,
  }) : _authProvider = authProvider,
       _deviceRepository = deviceRepository,
       _audio = audioService,
       _getLocalDeviceId =
           getLocalDeviceId ?? TokenStorage().getOrCreateDeviceId {
    _subscriptions.addAll([
      _audio.positionStream.listen((p) {
        if (_playbackCompleted) return;
        _position = p;
        notifyListeners();
      }),
      _audio.durationStream.listen((d) {
        if (d != null) {
          _duration = d;
          notifyListeners();
        }
      }),
      _audio.playingStream.listen((p) {
        // * just_audio stays "playing" after completion. Seeking back to zero
        //   in that state advances the bar with no sound. Ignore it until pause
        //   has landed and the user explicitly starts again.
        if (_playbackCompleted) return;
        _isPlaying = p;
        notifyListeners();
      }),
      _audio.completedStream.listen((_) {
        if (_repeat == PlaybackRepeat.one && _currentTrack != null) {
          _loadAndPlay(_currentTrack!);
          return;
        }
        if (hasNext) {
          playNext();
          return;
        }
        _playbackCompleted = true;
        _isPlaying = false;
        if (_duration > Duration.zero) _position = _duration;
        notifyListeners();
        unawaited(_audio.pause());
      }),
    ]);
  }

  final List<StreamSubscription> _subscriptions = [];
  final Random _random = Random();

  bool _shuffle = false;
  PlaybackRepeat _repeat = PlaybackRepeat.off;
  List<int> _shuffleOrder = [];
  int _shuffleCursor = 0;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  String? get error => _error;
  Duration get position => _position;
  Duration get duration => _duration;

  bool get hasControlPermission {
    final currentUser = _authProvider.user;
    if (currentUser == null) return false;
    return true;
  }

  // * Playback queue so the full-screen player can skip ⏮/⏭ within the list it
  //   was opened from. _voteRoomId is set only when the source is a vote room,
  //   which is what lets the player's swipe cast a real vote (vs a dead screen).
  List<Track> _queue = [];
  int _queueIndex = -1;
  String? _voteRoomId;

  String? get voteRoomId => _voteRoomId;
  bool get shuffleEnabled => _shuffle;
  PlaybackRepeat get repeatMode => _repeat;

  bool get hasNext {
    if (_queue.isEmpty || _queueIndex < 0) return false;
    if (_repeat == PlaybackRepeat.all) return true;
    if (_shuffle) return _shuffleCursor < _shuffleOrder.length - 1;
    return _queueIndex < _queue.length - 1;
  }

  bool get hasPrevious {
    if (_queue.isEmpty || _queueIndex < 0) return false;
    if (_shuffle) return _shuffleCursor > 0;
    return _queueIndex > 0;
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_shuffle) _rebuildShuffle(keepCurrent: true);
    notifyListeners();
  }

  void cycleRepeat() {
    _repeat = switch (_repeat) {
      PlaybackRepeat.off => PlaybackRepeat.all,
      PlaybackRepeat.all => PlaybackRepeat.one,
      PlaybackRepeat.one => PlaybackRepeat.off,
    };
    notifyListeners();
  }

  // * Upcoming tracks, current one kept in place. A fresh pass (repeat all)
  // * starts anywhere in the queue.
  void _rebuildShuffle({required bool keepCurrent}) {
    if (_queue.isEmpty) {
      _shuffleOrder = [];
      _shuffleCursor = 0;
      return;
    }
    final current = keepCurrent ? _queueIndex : -1;
    final rest = <int>[
      for (var i = 0; i < _queue.length; i++)
        if (i != current) i,
    ]..shuffle(_random);
    if (current >= 0 && current < _queue.length) {
      _shuffleOrder = [current, ...rest];
      _shuffleCursor = 0;
      return;
    }
    _shuffleOrder = rest;
    _shuffleCursor = 0;
    _queueIndex = _shuffleOrder.first;
  }

  // * Under 3s, the left arrow goes to the previous track. At 3s or later it
  //   restarts the one that is playing.
  static const Duration previousSkipThreshold = Duration(seconds: 3);

  void skipBackward() {
    if (_position < previousSkipThreshold && hasPrevious) {
      playPrevious();
      return;
    }
    unawaited(seek(Duration.zero));
  }

  // Play a track and optionally adopt the list it belongs to as the queue.
  // Pass voteRoomId when the track comes from a vote room (enables real voting).
  void playTrack(
    Track track, {
    List<Track>? queue,
    int? index,
    String? voteRoomId,
  }) {
    if (queue != null && index != null && index >= 0 && index < queue.length) {
      _queue = List<Track>.from(queue);
      _queueIndex = index;
    } else {
      _queue = [track];
      _queueIndex = 0;
    }
    _voteRoomId = voteRoomId;
    _playbackCompleted = false;
    if (_shuffle) _rebuildShuffle(keepCurrent: true);
    _loadAndPlay(track);
  }

  // Advance/rewind within the current queue (no-op at the bounds).
  void playNext() {
    if (_shuffle) {
      if (_shuffleCursor < _shuffleOrder.length - 1) {
        _shuffleCursor++;
        _queueIndex = _shuffleOrder[_shuffleCursor];
        _loadAndPlay(_queue[_queueIndex]);
        return;
      }
      if (_repeat == PlaybackRepeat.all && _queue.isNotEmpty) {
        _rebuildShuffle(keepCurrent: false);
        _loadAndPlay(_queue[_queueIndex]);
      }
      return;
    }
    if (_queueIndex < _queue.length - 1) {
      _queueIndex++;
      _loadAndPlay(_queue[_queueIndex]);
      return;
    }
    if (_repeat == PlaybackRepeat.all && _queue.isNotEmpty) {
      _queueIndex = 0;
      _loadAndPlay(_queue[_queueIndex]);
    }
  }

  void playPrevious() {
    if (_shuffle) {
      if (_shuffleCursor <= 0) return;
      _shuffleCursor--;
      _queueIndex = _shuffleOrder[_shuffleCursor];
      _loadAndPlay(_queue[_queueIndex]);
      return;
    }
    if (_queueIndex <= 0) return;
    _queueIndex--;
    _loadAndPlay(_queue[_queueIndex]);
  }

  void _loadAndPlay(Track track) {
    _playbackCompleted = false;
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

  Future<void> _startPlayback(
    String url, {
    Duration position = Duration.zero,
    bool autoplay = true,
  }) async {
    try {
      await _audio.play(url, position: position, autoplay: autoplay);
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
      final restart =
          _playbackCompleted || _position >= const Duration(seconds: 30);
      unawaited(_resumeFrom(restart: restart));
    }
  }

  // * A finished clip (or a playhead parked on the 30s cap) must be seeked
  //   back to zero before play(). Doing both at once leaves just_audio
  //   "playing" a completed source: the bar moves and the preview stays silent.
  Future<void> _resumeFrom({required bool restart}) async {
    if (restart) {
      await _audio.seek(Duration.zero);
      _position = Duration.zero;
    }
    _playbackCompleted = false;
    _isPlaying = true;
    notifyListeners();
    await _audio.resume();
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

  Future<void> seek(Duration position) async {
    final clamped = position > const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : (position < Duration.zero ? Duration.zero : position);
    _position = clamped;
    notifyListeners();
    await _audio.seek(clamped);
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

  // * Stops targeting a delegated device. Called when leaving the remote
  //   control surface so the local player no longer relays commands.
  void clearActiveDelegation({bool notify = true}) {
    activeDelegationId = null;
    if (notify) notifyListeners();
  }

  /// V.6: reset user-scoped playback/device state on logout.
  void clear() {
    _delegationFetchDebounce?.cancel();
    devices = [];
    controlledDevices = [];
    activeDelegationId = null;
    _currentTrack = null;
    _queue = [];
    _queueIndex = -1;
    _shuffle = false;
    _repeat = PlaybackRepeat.off;
    _shuffleOrder = [];
    _shuffleCursor = 0;
    _voteRoomId = null;
    _isPlaying = false;
    _playbackCompleted = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _error = null;
    unawaited(_audio.stop());
    notifyListeners();
  }

  void handleDelegationGranted(String deviceId, String ownerId) {
    if (_delegationFetchDebounce?.isActive ?? false) {
      _delegationFetchDebounce!.cancel();
    }
    _delegationFetchDebounce = Timer(const Duration(milliseconds: 1000), () {
      fetchControlledDevices();
    });
  }

  // * The owner revoked our control of one of their devices (symmetric with
  //   handleDelegationGranted). If we were actively driving that delegation,
  //   stop relaying, then drop it from the controlled list so it disappears.
  void handleDelegationRevoked(String deviceId, String ownerId) {
    final wasActive = controlledDevices.any(
      (d) =>
          d.deviceId == deviceId &&
          d.ownerId == ownerId &&
          d.id == activeDelegationId,
    );
    if (wasActive) activeDelegationId = null;
    controlledDevices = controlledDevices
        .where((d) => !(d.deviceId == deviceId && d.ownerId == ownerId))
        .toList();
    delegationRevision.value++;
    notifyListeners();
  }

  // * Delegate remote commands. Play with no trackId = resume on the owner.
  Future<void> sendPlayCommand({String? trackId}) async {
    if (activeDelegationId != null) {
      try {
        await _deviceRepository.playPlayback(
          activeDelegationId!,
          trackId: trackId,
        );
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

  // * Owner command receiver. Relayed over `playback:command` for this
  //   device only (`deviceId` matches local `x-device-id`). Play with no
  //   trackId resumes the just_audio player — no Spotify URIs.
  Future<void> handlePlaybackCommand(Map<String, dynamic> data) async {
    final targetDeviceId = data['deviceId'] as String?;
    if (targetDeviceId != null && targetDeviceId.isNotEmpty) {
      final localId = await _getLocalDeviceId();
      if (localId != targetDeviceId) {
        debugPrint(
          '[PlayerProvider] Ignoring playback:command because local deviceId ($localId) does not match target ($targetDeviceId)',
        );
        return;
      }
    }

    final action = data['action'] as String?;
    debugPrint(
      '[PlayerProvider] handlePlaybackCommand: action=$action, targetDeviceId=$targetDeviceId',
    );

    try {
      switch (action) {
        case 'play':
          final trackId = data['trackId'] as String?;
          if (trackId != null && trackId.isNotEmpty) {
            final idx = _queue.indexWhere((t) => t.id == trackId);
            if (idx >= 0) {
              playTrack(
                _queue[idx],
                queue: _queue,
                index: idx,
                voteRoomId: _voteRoomId,
              );
            } else {
              resume();
            }
          } else {
            resume();
          }
          break;
        case 'pause':
          pause();
          break;
        case 'stop':
          _isPlaying = false;
          notifyListeners();
          await _audio.stop();
          break;
        case 'next':
          playNext();
          break;
        case 'previous':
          playPrevious();
          break;
        case 'volume':
          final vol = (data['percent'] as num?)?.toDouble() ?? 50.0;
          await _audio.setVolume((vol / 100.0).clamp(0.0, 1.0));
          break;
      }
    } catch (e) {
      _error = 'Playback command failed: $e';
      notifyListeners();
    }
  }

  // * Handler methods for socket events — a remote controller drove playback,
  //   so we mirror the state and play the same preview locally when available.
  void handlePlaybackPlayed(
    Track track, {
    Duration position = Duration.zero,
    bool autoplay = true,
  }) {
    _currentTrack = track;
    _isPlaying = autoplay;
    _error = null;
    _position = position;
    notifyListeners();
    final preview = track.previewUrl;
    if (preview != null && preview.isNotEmpty) {
      unawaited(
        _startPlayback(preview, position: position, autoplay: autoplay),
      );
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
    _delegationFetchDebounce?.cancel();
    delegationRevision.dispose();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _audio.dispose();
    super.dispose();
  }
}
