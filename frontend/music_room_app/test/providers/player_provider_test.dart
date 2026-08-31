import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

/// Recording audio backend so owner-command tests assert just_audio calls.
class FakeAudioPlayerService implements AudioPlayerService {
  final List<String> calls = [];

  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<void> get completedStream => const Stream.empty();
  @override
  Future<void> play(String url) async => calls.add('play:$url');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> setVolume(double volume) async => calls.add('volume:$volume');
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerProvider playerProvider;
  late MockAuthProvider mockAuthProvider;
  late MockRoomsProvider mockRoomsProvider;
  late MockDeviceRepository mockDeviceRepository;
  late FakeAudioPlayerService fakeAudio;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockRoomsProvider = MockRoomsProvider();
    mockDeviceRepository = MockDeviceRepository();
    fakeAudio = FakeAudioPlayerService();

    final defaultUser = User(
      id: 'user-1',
      email: 'user1@test.com',
      displayName: 'User 1',
    );
    when(() => mockAuthProvider.user).thenReturn(defaultUser);

    playerProvider = PlayerProvider(
      authProvider: mockAuthProvider,
      roomsProvider: mockRoomsProvider,
      deviceRepository: mockDeviceRepository,
      audioService: fakeAudio,
      getLocalDeviceId: () async => 'local-device',
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

    test(
      'handleDelegationRevoked drops the device and clears active delegation '
      'when we were driving it',
      () {
        playerProvider.controlledDevices = [
          MusicControlDelegation(
            id: 'del-1',
            ownerId: 'owner-1',
            deviceId: 'dev-1',
            delegateUserId: 'delegate-1',
            grantedAt: DateTime.now(),
          ),
          MusicControlDelegation(
            id: 'del-2',
            ownerId: 'owner-2',
            deviceId: 'dev-2',
            delegateUserId: 'delegate-1',
            grantedAt: DateTime.now(),
          ),
        ];
        playerProvider.setActiveDelegation('del-1');

        playerProvider.handleDelegationRevoked('dev-1', 'owner-1');

        expect(
          playerProvider.controlledDevices.map((d) => d.id),
          equals(['del-2']),
        );
        expect(playerProvider.activeDelegationId, isNull);
      },
    );

    test(
      'handleDelegationRevoked keeps active delegation when a different device '
      'is revoked',
      () {
        playerProvider.controlledDevices = [
          MusicControlDelegation(
            id: 'del-1',
            ownerId: 'owner-1',
            deviceId: 'dev-1',
            delegateUserId: 'delegate-1',
            grantedAt: DateTime.now(),
          ),
          MusicControlDelegation(
            id: 'del-2',
            ownerId: 'owner-2',
            deviceId: 'dev-2',
            delegateUserId: 'delegate-1',
            grantedAt: DateTime.now(),
          ),
        ];
        playerProvider.setActiveDelegation('del-2');

        playerProvider.handleDelegationRevoked('dev-1', 'owner-1');

        expect(
          playerProvider.controlledDevices.map((d) => d.id),
          equals(['del-2']),
        );
        expect(playerProvider.activeDelegationId, equals('del-2'));
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
            trackId: any(named: 'trackId'),
          ),
        ).thenAnswer((_) async => {});

        await playerProvider.sendPlayCommand();

        verify(
          () => mockDeviceRepository.playPlayback('del-xyz', trackId: null),
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
      Track queuedTrack() => Track(
        id: 't-1',
        providerId: 'p-1',
        title: 'One',
        artist: 'A',
        durationMs: 1000,
        previewUrl: 'https://example.com/1.mp3',
      );

      test('handlePlaybackCommand play without trackId resumes just_audio', () async {
        playerProvider.playTrack(queuedTrack());
        fakeAudio.calls.clear();
        await playerProvider.handlePlaybackCommand({'action': 'play'});
        expect(fakeAudio.calls, contains('resume'));
      });

      test('handlePlaybackCommand play ignores Spotify trackUri', () async {
        playerProvider.playTrack(queuedTrack());
        fakeAudio.calls.clear();
        await playerProvider.handlePlaybackCommand({
          'action': 'play',
          'trackUri': 'http://example.com/song.mp3',
        });
        expect(fakeAudio.calls, contains('resume'));
        expect(fakeAudio.calls.any((c) => c.startsWith('play:')), isFalse);
      });

      test('handlePlaybackCommand pause pauses just_audio', () async {
        playerProvider.handlePlaybackCommand({'action': 'pause'});
        await Future<void>.delayed(Duration.zero);
        expect(fakeAudio.calls, contains('pause'));
      });

      test('handlePlaybackCommand next / previous skip the queue', () async {
        final tracks = [
          Track(
            id: 't-1',
            providerId: 'p-1',
            title: 'One',
            artist: 'A',
            durationMs: 1000,
            previewUrl: 'https://example.com/1.mp3',
          ),
          Track(
            id: 't-2',
            providerId: 'p-2',
            title: 'Two',
            artist: 'A',
            durationMs: 1000,
            previewUrl: 'https://example.com/2.mp3',
          ),
        ];
        playerProvider.playTrack(tracks[0], queue: tracks, index: 0);
        fakeAudio.calls.clear();

        await playerProvider.handlePlaybackCommand({'action': 'next'});
        expect(playerProvider.currentTrack?.id, 't-2');
        expect(fakeAudio.calls, contains('play:https://example.com/2.mp3'));

        fakeAudio.calls.clear();
        await playerProvider.handlePlaybackCommand({'action': 'previous'});
        expect(playerProvider.currentTrack?.id, 't-1');
      });

      test('handlePlaybackCommand volume sets just_audio gain', () async {
        await playerProvider.handlePlaybackCommand({
          'action': 'volume',
          'percent': 80,
        });
        expect(fakeAudio.calls, contains('volume:0.8'));
      });

      test('handlePlaybackCommand ignores another deviceId', () async {
        await playerProvider.handlePlaybackCommand({
          'action': 'pause',
          'deviceId': 'other-device',
        });
        expect(fakeAudio.calls, isEmpty);
      });

      test('handlePlaybackCommand applies when deviceId matches', () async {
        await playerProvider.handlePlaybackCommand({
          'action': 'pause',
          'deviceId': 'local-device',
        });
        expect(fakeAudio.calls, contains('pause'));
      });
    });
  });
}
