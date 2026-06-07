import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/providers/playlists_provider.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

class FakeTrack extends Fake implements Track {}

void main() {
  late PlaylistsProvider playlistsProvider;
  late MockRoomRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTrack());
  });

  setUp(() {
    mockRepository = MockRoomRepository();
    playlistsProvider = PlaylistsProvider(repository: mockRepository);
    when(
      () => mockRepository.getPlaylistTracks(any()),
    ).thenAnswer((_) async => []);
  });

  group('PlaylistsProvider Tests', () {
    test('Initial state is empty and not loading', () {
      expect(playlistsProvider.playlists, isEmpty);
      expect(playlistsProvider.isLoading, false);
      expect(playlistsProvider.error, isNull);
    });

    test('fetchPlaylists returns only PLAYLIST rooms', () async {
      final playlistRoom = Room(
        id: 'room-pl-1',
        name: 'My List',
        ownerId: 'user-1',
        kind: RoomKind.playlist,
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenAnswer((_) async => [playlistRoom]);

      await playlistsProvider.fetchPlaylists();

      expect(playlistsProvider.playlists.first.id, equals(playlistRoom.id));
      expect(playlistsProvider.playlists.first.name, equals(playlistRoom.name));
      expect(playlistsProvider.isLoading, false);
      expect(playlistsProvider.error, isNull);
    });

    test('fetchPlaylists sets error on failure', () async {
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenThrow(Exception('API Error'));

      await playlistsProvider.fetchPlaylists();

      expect(playlistsProvider.playlists, isEmpty);
      expect(playlistsProvider.isLoading, false);
      expect(playlistsProvider.error, contains('API Error'));
    });

    test('addTrack calls repository and reloads playlists', () async {
      final track = Track(
        id: 'uuid-1',
        providerId: 'spotify:track:1',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
      );
      when(
        () => mockRepository.addPlaylistTrack(any(), any()),
      ).thenAnswer((_) async => track);
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenAnswer((_) async => []);

      await playlistsProvider.addTrack('room-pl-1', track);

      verify(
        () => mockRepository.addPlaylistTrack('room-pl-1', any()),
      ).called(1);
      verify(() => mockRepository.getRooms(kind: RoomKind.playlist)).called(1);
    });

    test('removeTrack calls repository and reloads playlists', () async {
      when(
        () => mockRepository.removePlaylistTrack(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenAnswer((_) async => []);

      await playlistsProvider.removeTrack('room-pl-1', 'uuid-1');

      verify(
        () => mockRepository.removePlaylistTrack('room-pl-1', 'uuid-1'),
      ).called(1);
      verify(() => mockRepository.getRooms(kind: RoomKind.playlist)).called(1);
    });

    test('deletePlaylist removes the room from state on success', () async {
      final room = Room(
        id: 'room-pl-1',
        name: 'My List',
        ownerId: 'user-1',
        kind: RoomKind.playlist,
        tracks: [],
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenAnswer((_) async => [room]);
      when(() => mockRepository.deleteRoom(any())).thenAnswer((_) async {});

      await playlistsProvider.fetchPlaylists();
      expect(playlistsProvider.playlists, isNotEmpty);

      await playlistsProvider.deletePlaylist('room-pl-1');

      verify(() => mockRepository.deleteRoom('room-pl-1')).called(1);
      expect(playlistsProvider.playlists, isEmpty);
    });

    test('deletePlaylist rethrows and keeps state on failure', () async {
      final room = Room(
        id: 'room-pl-1',
        name: 'My List',
        ownerId: 'user-1',
        kind: RoomKind.playlist,
        tracks: [],
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenAnswer((_) async => [room]);
      when(
        () => mockRepository.deleteRoom(any()),
      ).thenThrow(Exception('Forbidden'));

      await playlistsProvider.fetchPlaylists();

      await expectLater(
        playlistsProvider.deletePlaylist('room-pl-1'),
        throwsException,
      );
      expect(playlistsProvider.playlists, isNotEmpty);
      expect(playlistsProvider.error, contains('Forbidden'));
    });

    test('moveTrack calls repository with anchor and reloads playlists', () async {
      when(
        () => mockRepository.movePlaylistTrack(
          any(),
          any(),
          afterTrackId: any(named: 'afterTrackId'),
          beforeTrackId: any(named: 'beforeTrackId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenAnswer((_) async => []);

      await playlistsProvider.moveTrack(
        'room-pl-1',
        'uuid-1',
        afterTrackId: 'uuid-0',
      );

      verify(
        () => mockRepository.movePlaylistTrack(
          'room-pl-1',
          'uuid-1',
          afterTrackId: 'uuid-0',
          beforeTrackId: null,
        ),
      ).called(1);
      verify(() => mockRepository.getRooms(kind: RoomKind.playlist)).called(1);
    });

    test('handleTrackAdded adds track to playlists in state', () async {
      final room = Room(
        id: 'room-1',
        name: 'Playlist Room',
        ownerId: 'owner-1',
        kind: RoomKind.playlist,
        tracks: [],
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenAnswer((_) async => [room]);

      await playlistsProvider.fetchPlaylists();
      expect(playlistsProvider.playlists.first.tracks, isEmpty);

      final track = Track(
        id: 'track-1',
        providerId: 'p-1',
        provider: 'spotify',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
      );
      playlistsProvider.handleTrackAdded(track);
      expect(
        playlistsProvider.playlists.first.tracks.first.id,
        equals('track-1'),
      );
    });

    test(
      'handleTrackMoved updates track position and sorts/reorders',
      () async {
        final track = Track(
          id: 'track-1',
          providerId: 'p-1',
          provider: 'spotify',
          title: 'Song',
          artist: 'Artist',
          durationMs: 180000,
          position: 'a',
        );
        final room = Room(
          id: 'room-1',
          name: 'Playlist Room',
          ownerId: 'owner-1',
          kind: RoomKind.playlist,
          tracks: [track],
        );
        when(
          () => mockRepository.getRooms(kind: RoomKind.playlist),
        ).thenAnswer((_) async => [room]);
        when(
          () => mockRepository.getPlaylistTracks('room-1'),
        ).thenAnswer((_) async => [track]);

        await playlistsProvider.fetchPlaylists();
        expect(
          playlistsProvider.playlists.first.tracks.first.position,
          equals('a'),
        );

        playlistsProvider.handleTrackMoved('room-1', 'track-1', 'b');
        expect(
          playlistsProvider.playlists.first.tracks.first.position,
          equals('b'),
        );
      },
    );

    test('handleTrackRemoved removes track from playlists in state', () async {
      final track = Track(
        id: 'track-1',
        providerId: 'p-1',
        provider: 'spotify',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
      );
      final room = Room(
        id: 'room-1',
        name: 'Playlist Room',
        ownerId: 'owner-1',
        kind: RoomKind.playlist,
        tracks: [track],
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenAnswer((_) async => [room]);
      when(
        () => mockRepository.getPlaylistTracks('room-1'),
      ).thenAnswer((_) async => [track]);

      await playlistsProvider.fetchPlaylists();
      expect(playlistsProvider.playlists.first.tracks, isNotEmpty);

      playlistsProvider.handleTrackRemoved('track-1');
      expect(playlistsProvider.playlists.first.tracks, isEmpty);
    });
  });
}
