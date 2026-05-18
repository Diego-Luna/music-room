import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/mock_api_repository.dart';
import 'package:music_room_app/models/playlist.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/providers/playlists_provider.dart';

class MockMockApiRepository extends Mock implements MockApiRepository {}

class FakeTrack extends Fake implements Track {}

void main() {
  late PlaylistsProvider playlistsProvider;
  late MockMockApiRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTrack());
  });

  setUp(() {
    mockRepository = MockMockApiRepository();
    playlistsProvider = PlaylistsProvider(repository: mockRepository);
  });

  group('PlaylistsProvider Tests', () {
    test('Initial state is empty and not loading', () {
      expect(playlistsProvider.playlists, isEmpty);
      expect(playlistsProvider.isLoading, false);
      expect(playlistsProvider.error, isNull);
    });

    test('fetchPlaylists sets playlists on success', () async {
      final mockPlaylists = [
        Playlist(id: 'pl-1', name: 'My List', ownerId: 'user-1'),
      ];

      when(
        () => mockRepository.getPlaylists(),
      ).thenAnswer((_) async => mockPlaylists);

      await playlistsProvider.fetchPlaylists();

      expect(playlistsProvider.playlists, equals(mockPlaylists));
      expect(playlistsProvider.isLoading, false);
      expect(playlistsProvider.error, isNull);
    });

    test('fetchPlaylists sets error on failure', () async {
      when(
        () => mockRepository.getPlaylists(),
      ).thenThrow(Exception('API Error'));

      await playlistsProvider.fetchPlaylists();

      expect(playlistsProvider.playlists, isEmpty);
      expect(playlistsProvider.isLoading, false);
      expect(playlistsProvider.error, contains('API Error'));
    });

    test('addTrack calls repository and reloads playlists', () async {
      final track = Track(
        id: 't-1',
        title: 'Song',
        artist: 'Artist',
        durationSeconds: 180,
      );
      when(
        () => mockRepository.addTrackToPlaylist(any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockRepository.getPlaylists()).thenAnswer((_) async => []);

      await playlistsProvider.addTrack('pl-1', track);

      verify(() => mockRepository.addTrackToPlaylist('pl-1', any())).called(1);
      verify(() => mockRepository.getPlaylists()).called(1);
    });

    test('removeTrack calls repository and reloads playlists', () async {
      when(
        () => mockRepository.removeTrackFromPlaylist(any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockRepository.getPlaylists()).thenAnswer((_) async => []);

      await playlistsProvider.removeTrack('pl-1', 't-1');

      verify(
        () => mockRepository.removeTrackFromPlaylist('pl-1', 't-1'),
      ).called(1);
      verify(() => mockRepository.getPlaylists()).called(1);
    });
  });
}
