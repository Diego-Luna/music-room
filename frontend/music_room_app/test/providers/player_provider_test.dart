import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockRoomsProvider extends Mock implements RoomsProvider {}

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
        title: 'Song',
        artist: 'Artist',
        durationSeconds: 180,
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
          title: 'Song',
          artist: 'Artist',
          durationSeconds: 180,
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
        title: 'Song',
        artist: 'Artist',
        durationSeconds: 180,
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

    test('pause() pauses playback if permission exists', () {
      when(() => mockRoomsProvider.currentActiveRoom).thenReturn(null);

      playerProvider.pause();

      expect(playerProvider.isPlaying, false);
    });
  });
}
