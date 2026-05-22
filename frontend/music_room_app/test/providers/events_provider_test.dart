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

      expect(eventsProvider.events, equals([voteRoom]));
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
  });
}
