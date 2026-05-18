import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/mock_api_repository.dart';
import 'package:music_room_app/models/event.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/providers/events_provider.dart';

class MockMockApiRepository extends Mock implements MockApiRepository {}

class FakeTrack extends Fake implements Track {}

void main() {
  late EventsProvider eventsProvider;
  late MockMockApiRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTrack());
  });

  setUp(() {
    mockRepository = MockMockApiRepository();
    eventsProvider = EventsProvider(repository: mockRepository);
  });

  group('EventsProvider Tests', () {
    test('Initial state is empty and not loading', () {
      expect(eventsProvider.events, isEmpty);
      expect(eventsProvider.isLoading, false);
      expect(eventsProvider.error, isNull);
    });

    test('fetchEvents sets events on success', () async {
      final mockEvents = [
        Event(id: 'event-1', name: 'Party', ownerId: 'user-1', tracks: []),
      ];

      when(
        () => mockRepository.getEvents(),
      ).thenAnswer((_) async => mockEvents);

      await eventsProvider.fetchEvents();

      expect(eventsProvider.events, equals(mockEvents));
      expect(eventsProvider.isLoading, false);
      expect(eventsProvider.error, isNull);
    });

    test('fetchEvents sets error on failure', () async {
      when(
        () => mockRepository.getEvents(),
      ).thenThrow(Exception('Network Error'));

      await eventsProvider.fetchEvents();

      expect(eventsProvider.events, isEmpty);
      expect(eventsProvider.isLoading, false);
      expect(eventsProvider.error, contains('Network Error'));
    });

    test('voteForTrack calls repository and reloads events', () async {
      when(
        () => mockRepository.voteForTrack(any(), any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockRepository.getEvents()).thenAnswer((_) async => []);

      await eventsProvider.voteForTrack('event-1', 'track-1', true);

      verify(
        () => mockRepository.voteForTrack('event-1', 'track-1', true),
      ).called(1);
      verify(() => mockRepository.getEvents()).called(1);
    });

    test('suggestTrack calls repository and reloads events', () async {
      final track = Track(
        id: 't-1',
        title: 'Song',
        artist: 'Artist',
        durationSeconds: 180,
      );
      when(
        () => mockRepository.suggestTrack(any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockRepository.getEvents()).thenAnswer((_) async => []);

      await eventsProvider.suggestTrack('event-1', track);

      verify(() => mockRepository.suggestTrack('event-1', any())).called(1);
      verify(() => mockRepository.getEvents()).called(1);
    });
  });
}
