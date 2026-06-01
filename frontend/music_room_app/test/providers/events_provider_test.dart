import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/providers/events_provider.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

class FakeTrack extends Fake implements Track {}

void main() {
  late EventsProvider eventsProvider;
  late MockRoomRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTrack());
  });

  setUp(() {
    mockRepository = MockRoomRepository();
    eventsProvider = EventsProvider(repository: mockRepository);
    when(() => mockRepository.getVoteTracks(any())).thenAnswer((_) async => []);
  });

  group('EventsProvider Tests', () {
    test('Initial state is empty and not loading', () {
      expect(eventsProvider.events, isEmpty);
      expect(eventsProvider.isLoading, false);
      expect(eventsProvider.error, isNull);
    });

    test('fetchEvents returns only VOTE rooms', () async {
      final voteRoom = Room(
        id: 'room-1',
        name: 'Party',
        ownerId: 'user-1',
        kind: RoomKind.vote,
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => [voteRoom]);

      await eventsProvider.fetchEvents();

      expect(eventsProvider.events.first.id, equals(voteRoom.id));
      expect(eventsProvider.events.first.name, equals(voteRoom.name));
      expect(eventsProvider.isLoading, false);
      expect(eventsProvider.error, isNull);
    });

    test('fetchEvents sets error on failure', () async {
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenThrow(Exception('Network Error'));

      await eventsProvider.fetchEvents();

      expect(eventsProvider.events, isEmpty);
      expect(eventsProvider.isLoading, false);
      expect(eventsProvider.error, contains('Network Error'));
    });

    test('voteForTrack calls repository and reloads events', () async {
      when(
        () => mockRepository.voteForTrack(any(), any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => []);

      await eventsProvider.voteForTrack('room-1', 'track-1', 1);

      verify(
        () => mockRepository.voteForTrack('room-1', 'track-1', 1),
      ).called(1);
      verify(() => mockRepository.getRooms(kind: RoomKind.vote)).called(1);
    });

    test('suggestTrack calls repository and reloads events', () async {
      final track = Track(
        id: 'uuid-1',
        providerId: 'spotify:track:1',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
      );
      when(
        () => mockRepository.addVoteTrack(any(), any()),
      ).thenAnswer((_) async => track);
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => []);

      await eventsProvider.suggestTrack('room-1', track);

      verify(() => mockRepository.addVoteTrack('room-1', any())).called(1);
      verify(() => mockRepository.getRooms(kind: RoomKind.vote)).called(1);
    });

    test('handleTrackAdded adds track to matching rooms in state', () async {
      final room = Room(
        id: 'room-1',
        name: 'Event Room',
        ownerId: 'owner-1',
        kind: RoomKind.vote,
        tracks: [],
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => [room]);

      await eventsProvider.fetchEvents();
      expect(eventsProvider.events.first.tracks, isEmpty);

      final track = Track(
        id: 'track-1',
        providerId: 'p-1',
        provider: 'spotify',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
      );
      eventsProvider.handleTrackAdded(track);
      expect(eventsProvider.events.first.tracks.first.id, equals('track-1'));
    });

    test('handleTrackVoted updates score and sorts tracks', () async {
      final track = Track(
        id: 'track-1',
        providerId: 'p-1',
        provider: 'spotify',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
        score: 1,
      );
      final room = Room(
        id: 'room-1',
        name: 'Event Room',
        ownerId: 'owner-1',
        kind: RoomKind.vote,
        tracks: [track],
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => [room]);
      when(
        () => mockRepository.getVoteTracks('room-1'),
      ).thenAnswer((_) async => [track]);
      await eventsProvider.fetchEvents();
      expect(eventsProvider.events.first.tracks.first.score, equals(1));

      eventsProvider.handleTrackVoted('track-1', 5, 10);
      expect(eventsProvider.events.first.tracks.first.score, equals(5));
    });

    test('handleTrackRemoved removes track from rooms', () async {
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
        name: 'Event Room',
        ownerId: 'owner-1',
        kind: RoomKind.vote,
        tracks: [track],
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => [room]);
      when(
        () => mockRepository.getVoteTracks('room-1'),
      ).thenAnswer((_) async => [track]);
      await eventsProvider.fetchEvents();
      expect(eventsProvider.events.first.tracks, isNotEmpty);

      eventsProvider.handleTrackRemoved('track-1');
      expect(eventsProvider.events.first.tracks, isEmpty);
    });
  });
}
