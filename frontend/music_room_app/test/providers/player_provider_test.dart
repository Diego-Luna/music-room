import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:music_room_app/core/audio/audio_player_service.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/account_device.dart';
import 'package:music_room_app/models/music_control_delegation.dart';
import 'package:music_room_app/core/repositories/device_repository.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockRoomsProvider extends Mock implements RoomsProvider {}

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockAudioPlayer extends Mock implements AudioPlayer {}

class FakeSource extends Fake implements Source {}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerProvider playerProvider;
  late MockAuthProvider mockAuthProvider;
  late MockRoomsProvider mockRoomsProvider;
  late MockDeviceRepository mockDeviceRepository;
  late MockAudioPlayer mockAudioPlayer;

  setUpAll(() {
    registerFallbackValue(FakeSource());
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockRoomsProvider = MockRoomsProvider();
    mockDeviceRepository = MockDeviceRepository();
    mockAudioPlayer = MockAudioPlayer();

    final defaultUser = User(
      id: 'user-1',
      email: 'user1@test.com',
      displayName: 'User 1',
    );
    when(() => mockAuthProvider.user).thenReturn(defaultUser);

    // * Mock AudioPlayer streams and futures
    when(
      () => mockAudioPlayer.onPlayerStateChanged,
    ).thenAnswer((_) => const Stream<PlayerState>.empty());
    when(() => mockAudioPlayer.dispose()).thenAnswer((_) async => {});
    when(() => mockAudioPlayer.play(any())).thenAnswer((_) async => {});
    when(() => mockAudioPlayer.resume()).thenAnswer((_) async => {});
    when(() => mockAudioPlayer.pause()).thenAnswer((_) async => {});
    when(() => mockAudioPlayer.stop()).thenAnswer((_) async => {});
    when(() => mockAudioPlayer.setVolume(any())).thenAnswer((_) async => {});

    playerProvider = PlayerProvider(
      authProvider: mockAuthProvider,
      roomsProvider: mockRoomsProvider,
      deviceRepository: mockDeviceRepository,
      audioPlayer: mockAudioPlayer,
      audioService: FakeAudioPlayerService(),
    );
  });

  group('Model Serialization Tests', () {
    test('MusicControlDelegation toJson/fromJson matches', () {
      final delegationJson = {
        'id': 'del-1',
        'ownerId': 'owner-123',
        'deviceId': 'device-456',
        'delegateUserId': 'delegate-789',
        'grantedAt': '2026-06-06T12:00:00.000Z',
      };

      final delegation = MusicControlDelegation.fromJson(delegationJson);
      expect(delegation.id, equals('del-1'));
      expect(delegation.ownerId, equals('owner-123'));
      expect(delegation.deviceId, equals('device-456'));
      expect(delegation.delegateUserId, equals('delegate-789'));
      expect(
        delegation.grantedAt,
        equals(DateTime.parse('2026-06-06T12:00:00.000Z')),
      );

      final serialized = delegation.toJson();
      expect(serialized['id'], equals('del-1'));
      expect(serialized['ownerId'], equals('owner-123'));
      expect(serialized['deviceId'], equals('device-456'));
      expect(serialized['delegateUserId'], equals('delegate-789'));
      expect(serialized['grantedAt'], equals('2026-06-06T12:00:00.000Z'));
    });

    test('AccountDevice toJson/fromJson matches with delegation', () {
      final deviceJson = {
        'deviceId': 'device-456',
        'userAgent': 'Dart-SDK/3.0',
        'lastSeenAt': '2026-06-06T13:00:00.000Z',
        'delegation': {
          'id': 'del-1',
          'ownerId': 'owner-123',
          'deviceId': 'device-456',
          'delegateUserId': 'delegate-789',
          'grantedAt': '2026-06-06T12:00:00.000Z',
        },
      };

      final device = AccountDevice.fromJson(deviceJson);
      expect(device.deviceId, equals('device-456'));
      expect(device.userAgent, equals('Dart-SDK/3.0'));
      expect(
        device.lastSeenAt,
        equals(DateTime.parse('2026-06-06T13:00:00.000Z')),
      );
      expect(device.delegation, isNotNull);
      expect(device.delegation?.id, equals('del-1'));

      final serialized = device.toJson();
      expect(serialized['deviceId'], equals('device-456'));
      expect(serialized['userAgent'], equals('Dart-SDK/3.0'));
      expect(serialized['lastSeenAt'], equals('2026-06-06T13:00:00.000Z'));
      expect(serialized['delegation'], isMap);
    });
  });

  group('PlayerProvider Tests', () {
    test('Initial state is correct', () {
      expect(playerProvider.currentTrack, isNull);
      expect(playerProvider.isPlaying, false);
      expect(playerProvider.error, isNull);
      expect(playerProvider.devices, isEmpty);
      expect(playerProvider.controlledDevices, isEmpty);
      expect(playerProvider.activeDelegationId, isNull);
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
      'handleDelegationGranted fetches controlled devices after debounce',
      () async {
        final mockControlled = [
          MusicControlDelegation(
            id: 'del-1',
            ownerId: 'owner-1',
            deviceId: 'dev-1',
            delegateUserId: 'delegate-1',
            grantedAt: DateTime.now(),
          ),
        ];
        when(
          () => mockDeviceRepository.getControlledDevices(),
        ).thenAnswer((_) async => mockControlled);

        playerProvider.handleDelegationGranted('dev-1', 'owner-1');

        expect(playerProvider.controlledDevices, isEmpty);

        await Future.delayed(const Duration(milliseconds: 1600));

        expect(playerProvider.controlledDevices, equals(mockControlled));
      },
    );

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
      playerProvider.handlePlaybackVolumeChanged(0.5);
    });

    test('fetchDevices updates devices list on success', () async {
      final mockDevices = [
        AccountDevice(deviceId: 'device-1', userAgent: 'userAgent-1'),
      ];
      when(
        () => mockDeviceRepository.getDevices(),
      ).thenAnswer((_) async => mockDevices);

      await playerProvider.fetchDevices();

      expect(playerProvider.devices, equals(mockDevices));
      expect(playerProvider.error, isNull);
    });

    test('fetchDevices sets error on repository failure', () async {
      when(
        () => mockDeviceRepository.getDevices(),
      ).thenThrow(Exception('API Error'));

      await playerProvider.fetchDevices();

      expect(playerProvider.devices, isEmpty);
      expect(playerProvider.error, contains('Failed to fetch devices'));
    });

    test('fetchControlledDevices updates list on success', () async {
      final mockControlled = [
        MusicControlDelegation(
          id: 'del-1',
          ownerId: 'owner-1',
          deviceId: 'dev-1',
          delegateUserId: 'delegate-1',
          grantedAt: DateTime.now(),
        ),
      ];
      when(
        () => mockDeviceRepository.getControlledDevices(),
      ).thenAnswer((_) async => mockControlled);

      await playerProvider.fetchControlledDevices();

      expect(playerProvider.controlledDevices, equals(mockControlled));
      expect(playerProvider.error, isNull);
    });

    test('setActiveDelegation updates activeDelegationId', () {
      playerProvider.setActiveDelegation('del-xyz');
      expect(playerProvider.activeDelegationId, equals('del-xyz'));
    });

    test(
      'sendPlayCommand calls repository with active delegation id',
      () async {
        playerProvider.setActiveDelegation('del-xyz');
        when(
          () => mockDeviceRepository.playPlayback(
            'del-xyz',
            uris: any(named: 'uris'),
          ),
        ).thenAnswer((_) async => {});

        await playerProvider.sendPlayCommand(uris: ['spotify:track:123']);

        verify(
          () => mockDeviceRepository.playPlayback(
            'del-xyz',
            uris: ['spotify:track:123'],
          ),
        ).called(1);
      },
    );

    test(
      'sendPauseCommand calls repository with active delegation id',
      () async {
        playerProvider.setActiveDelegation('del-xyz');
        when(
          () => mockDeviceRepository.pausePlayback('del-xyz'),
        ).thenAnswer((_) async => {});

        await playerProvider.sendPauseCommand();

        verify(() => mockDeviceRepository.pausePlayback('del-xyz')).called(1);
      },
    );

    test(
      'sendNextCommand calls repository with active delegation id',
      () async {
        playerProvider.setActiveDelegation('del-xyz');
        when(
          () => mockDeviceRepository.nextTrack('del-xyz'),
        ).thenAnswer((_) async => {});

        await playerProvider.sendNextCommand();

        verify(() => mockDeviceRepository.nextTrack('del-xyz')).called(1);
      },
    );

    test(
      'sendPreviousCommand calls repository with active delegation id',
      () async {
        playerProvider.setActiveDelegation('del-xyz');
        when(
          () => mockDeviceRepository.previousTrack('del-xyz'),
        ).thenAnswer((_) async => {});

        await playerProvider.sendPreviousCommand();

        verify(() => mockDeviceRepository.previousTrack('del-xyz')).called(1);
      },
    );

    test(
      'sendVolumeCommand calls repository with active delegation id',
      () async {
        playerProvider.setActiveDelegation('del-xyz');
        when(
          () => mockDeviceRepository.setVolume('del-xyz', 80),
        ).thenAnswer((_) async => {});

        await playerProvider.sendVolumeCommand(80);

        verify(() => mockDeviceRepository.setVolume('del-xyz', 80)).called(1);
      },
    );

    group('Owner Command Handling', () {
      test(
        'handlePlaybackCommand play with trackUri calls audioPlayer.play',
        () async {
          playerProvider.handlePlaybackCommand({
            'action': 'play',
            'trackUri': 'http://example.com/song.mp3',
          });

          verify(
            () => mockAudioPlayer.play(
              any(
                that: isA<UrlSource>().having(
                  (s) => s.url,
                  'url',
                  'http://example.com/song.mp3',
                ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'handlePlaybackCommand play without trackUri calls audioPlayer.resume',
        () async {
          playerProvider.handlePlaybackCommand({'action': 'play'});

          verify(() => mockAudioPlayer.resume()).called(1);
        },
      );

      test('handlePlaybackCommand pause calls audioPlayer.pause', () async {
        playerProvider.handlePlaybackCommand({'action': 'pause'});

        verify(() => mockAudioPlayer.pause()).called(1);
      });

      test('handlePlaybackCommand stop calls audioPlayer.stop', () async {
        playerProvider.handlePlaybackCommand({'action': 'stop'});

        verify(() => mockAudioPlayer.stop()).called(1);
      });

      test(
        'handlePlaybackCommand volume calls audioPlayer.setVolume with double value',
        () async {
          playerProvider.handlePlaybackCommand({
            'action': 'volume',
            'percent': 80,
          });

          verify(() => mockAudioPlayer.setVolume(0.8)).called(1);
        },
      );
    });
  });
}
