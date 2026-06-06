import 'package:just_audio/just_audio.dart';

/// Thin abstraction over the audio backend.
///
/// Keeps [PlayerProvider] unit-testable (tests inject a fake instead of the
/// real plugin) and leaves the playback library swappable. The app uses the
/// [just_audio]-backed [JustAudioPlayerService]; it streams the 30-second
/// Deezer preview MP3 carried by `Track.previewUrl`.
abstract class AudioPlayerService {
  /// Current playback position.
  Stream<Duration> get positionStream;

  /// Loaded clip duration (null until known).
  Stream<Duration?> get durationStream;

  /// True while audio is actually playing.
  Stream<bool> get playingStream;

  /// Fires when the clip reaches its end.
  Stream<void> get completedStream;

  /// Loads [url] and starts playback from the beginning.
  Future<void> play(String url);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

/// [just_audio]-backed implementation used in the running app.
class JustAudioPlayerService implements AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<void> get completedStream => _player.processingStateStream
      .where((state) => state == ProcessingState.completed);

  @override
  Future<void> play(String url) async {
    await _player.setUrl(url);
    await _player.seek(Duration.zero);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
