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

      expect(playlistsProvider.playlists, equals([playlistRoom]));
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

    test('moveTrack calls repository and reloads playlists', () async {
      when(
        () => mockRepository.movePlaylistTrack(any(), any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRepository.getRooms(kind: RoomKind.playlist),
      ).thenAnswer((_) async => []);

      await playlistsProvider.moveTrack('room-pl-1', 'uuid-1', 'a1V');

      verify(
        () => mockRepository.movePlaylistTrack('room-pl-1', 'uuid-1', 'a1V'),
      ).called(1);
      verify(() => mockRepository.getRooms(kind: RoomKind.playlist)).called(1);
    });
  });
}
