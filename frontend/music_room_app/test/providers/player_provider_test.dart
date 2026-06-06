import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/audio/audio_player_service.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockRoomsProvider extends Mock implements RoomsProvider {}

/// No-op audio backend so the provider's logic is tested without the plugin.
class FakeAudioPlayerService implements AudioPlayerService {
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<void> get completedStream => const Stream.empty();
  @override
  Future<void> play(String url) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  late PlayerProvider playerProvider;
  late MockAuthProvider mockAuthProvider;
  late MockRoomsProvider mockRoomsProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockRoomsProvider = MockRoomsProvider();
    playerProvider = PlayerProvider(
      authProvider: mockAuthProvider,
      roomsProvider: mockRoomsProvider,
      audioService: FakeAudioPlayerService(),
    );
  });

  group('PlayerProvider Tests', () {
    test('Initial state is correct', () {
      expect(playerProvider.currentTrack, isNull);
      expect(playerProvider.isPlaying, false);
      expect(playerProvider.error, isNull);
    });

    test('playTrack() changes state if no active room (has permission)', () {
      final track = Track(
        id: 't-1',
        providerId: 'spotify:track:1',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
        previewUrl: 'https://example.com/preview.mp3',
      );
      when(() => mockRoomsProvider.currentActiveRoom).thenReturn(null);

      playerProvider.playTrack(track);

      expect(playerProvider.currentTrack, equals(track));
      expect(playerProvider.isPlaying, true);
      expect(playerProvider.error, isNull);
    });

    test(
      'playTrack() sets error if in room but current user is not controller',
      () {
        final track = Track(
          id: 't-1',
          providerId: 'spotify:track:1',
          title: 'Song',
          artist: 'Artist',
          durationMs: 180000,
        );
        final room = Room(
          id: 'r-1',
          name: 'Room',
          ownerId: 'user-1',
          currentControllerId: 'user-1',
        );
        final currentUser = User(
          id: 'user-2',
          email: 'user2@test.com',
          displayName: 'User 2',
        );

        when(() => mockRoomsProvider.currentActiveRoom).thenReturn(room);
        when(() => mockAuthProvider.user).thenReturn(currentUser);

        playerProvider.playTrack(track);

        expect(playerProvider.isPlaying, false);
        expect(playerProvider.error, contains('do not have permission'));
      },
    );

    test('playTrack() succeeds if in room and user is controller', () {
      final track = Track(
        id: 't-1',
        providerId: 'spotify:track:1',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
        previewUrl: 'https://example.com/preview.mp3',
      );
      final room = Room(
        id: 'r-1',
        name: 'Room',
        ownerId: 'user-1',
        currentControllerId: 'user-2',
      );
      final currentUser = User(
        id: 'user-2',
        email: 'user2@test.com',
        displayName: 'User 2',
      );

      when(() => mockRoomsProvider.currentActiveRoom).thenReturn(room);
      when(() => mockAuthProvider.user).thenReturn(currentUser);

      playerProvider.playTrack(track);

      expect(playerProvider.currentTrack, equals(track));
      expect(playerProvider.isPlaying, true);
      expect(playerProvider.error, isNull);
    });

    test('playTrack() sets error when track has no preview url', () {
      final track = Track(
        id: 't-2',
        providerId: 'p-2',
        title: 'No Preview',
        artist: 'Artist',
        durationMs: 180000,
      );
      when(() => mockRoomsProvider.currentActiveRoom).thenReturn(null);

      playerProvider.playTrack(track);

      expect(playerProvider.currentTrack, equals(track));
      expect(playerProvider.isPlaying, false);
      expect(playerProvider.error, contains('No 30-second preview'));
    });

    test('pause() pauses playback if permission exists', () {
      when(() => mockRoomsProvider.currentActiveRoom).thenReturn(null);

      playerProvider.pause();

      expect(playerProvider.isPlaying, false);
    });

    test(
      'handlePlaybackPlayed updates current track and sets playing to true',
      () {
        final track = Track(
          id: 'track-1',
          providerId: 'p-1',
          provider: 'spotify',
          title: 'Song',
          artist: 'Artist',
          durationMs: 180000,
        );
        playerProvider.handlePlaybackPlayed(track);
        expect(playerProvider.currentTrack?.id, equals('track-1'));
        expect(playerProvider.isPlaying, isTrue);
        expect(playerProvider.error, isNull);
      },
    );

    test('handlePlaybackPaused sets playing to false', () {
      final track = Track(
        id: 'track-1',
        providerId: 'p-1',
        provider: 'spotify',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
      );
      playerProvider.handlePlaybackPlayed(track);
      expect(playerProvider.isPlaying, isTrue);

      playerProvider.handlePlaybackPaused();
      expect(playerProvider.isPlaying, isFalse);
      expect(playerProvider.error, isNull);
    });

    test(
      'handlePlaybackSkipped updates current track and sets playing to true',
      () {
        final track = Track(
          id: 'track-1',
          providerId: 'p-1',
          provider: 'spotify',
          title: 'Song',
          artist: 'Artist',
          durationMs: 180000,
        );
        playerProvider.handlePlaybackSkipped(track);
        expect(playerProvider.currentTrack?.id, equals('track-1'));
        expect(playerProvider.isPlaying, isTrue);
        expect(playerProvider.error, isNull);
      },
    );

    test('handlePlaybackVolumeChanged executes without errors', () {
      // Just verify call completes successfully
      playerProvider.handlePlaybackVolumeChanged(0.5);
    });
  });
}
