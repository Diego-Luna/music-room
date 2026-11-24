import 'dart:async';

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

    test('a fetch started before create does not drop the new event', () async {
      final created = Room(
        id: 'event-new',
        name: 'Just created',
        ownerId: 'user-1',
        kind: RoomKind.vote,
      );
      final firstList = Completer<List<Room>>();
      var calls = 0;
      when(() => mockRepository.getRooms(kind: RoomKind.vote)).thenAnswer((_) {
        calls++;
        if (calls == 1) return firstList.future;
        return Future.value([created]);
      });
      when(
        () => mockRepository.createRoom(
          name: any(named: 'name'),
          kind: RoomKind.vote,
          isPublic: any(named: 'isPublic'),
          description: any(named: 'description'),
          voteAccess: any(named: 'voteAccess'),
          voteWindow: any(named: 'voteWindow'),
          voteStartsAt: any(named: 'voteStartsAt'),
          voteEndsAt: any(named: 'voteEndsAt'),
          voteLocationLat: any(named: 'voteLocationLat'),
          voteLocationLng: any(named: 'voteLocationLng'),
          voteLocationRadiusM: any(named: 'voteLocationRadiusM'),
        ),
      ).thenAnswer((_) async => created);

      final initial = eventsProvider.fetchEvents();
      await Future<void>.delayed(Duration.zero);

      final creating = eventsProvider.createEvent(
        name: 'Just created',
        description: 'mine',
        isPublic: true,
        voteAccess: 'EVERYONE',
        voteWindow: 'ALWAYS',
      );
      await creating;
      expect(eventsProvider.events.map((event) => event.id), ['event-new']);

      firstList.complete(<Room>[]);
      await initial;
      expect(eventsProvider.events.map((event) => event.id), ['event-new']);
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
        () => mockRepository.voteForTrack(
          any(),
          any(),
          any(),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => []);

      await eventsProvider.voteForTrack('room-1', 'track-1', 1);

      verify(
        () => mockRepository.voteForTrack(
          'room-1',
          'track-1',
          1,
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
        ),
      ).called(1);
      verify(() => mockRepository.getRooms(kind: RoomKind.vote)).called(1);
    });

    test('voteForTrack forwards explicit lat/lng', () async {
      when(
        () => mockRepository.voteForTrack(
          any(),
          any(),
          any(),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => []);

      await eventsProvider.voteForTrack(
        'room-1',
        'track-1',
        1,
        lat: 48.85,
        lng: 2.35,
      );

      verify(
        () => mockRepository.voteForTrack(
          'room-1',
          'track-1',
          1,
          lat: 48.85,
          lng: 2.35,
        ),
      ).called(1);
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

    test('deleteEvent removes the event from state on success', () async {
      final room = Room(
        id: 'room-1',
        name: 'Party',
        ownerId: 'user-1',
        kind: RoomKind.vote,
      );
      when(
        () => mockRepository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => [room]);
      await eventsProvider.fetchEvents();
      expect(eventsProvider.events, hasLength(1));
      expect(eventsProvider.selectedEvent?.id, equals('room-1'));

      when(() => mockRepository.deleteRoom('room-1')).thenAnswer((_) async {});
      await eventsProvider.deleteEvent('room-1');

      verify(() => mockRepository.deleteRoom('room-1')).called(1);
      expect(eventsProvider.events, isEmpty);
      expect(eventsProvider.selectedEvent, isNull);
    });

    test('deleteEvent rethrows and sets error on failure', () async {
      when(
        () => mockRepository.deleteRoom('room-1'),
      ).thenThrow(Exception('Forbidden'));

      await expectLater(
        () => eventsProvider.deleteEvent('room-1'),
        throwsA(isA<Exception>()),
      );
      expect(eventsProvider.error, contains('Forbidden'));
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
        roomId: 'room-1',
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

    test('loadEvent opens one event and its queue from its id', () async {
      final room = Room(
        id: 'room-9',
        name: 'Reload',
        ownerId: 'user-1',
        kind: RoomKind.vote,
      );
      final track = Track(
        id: 'track-9',
        providerId: 'p9',
        title: 'Song',
        artist: 'Artist',
        durationMs: 30000,
      );
      when(
        () => mockRepository.getRoomById('room-9'),
      ).thenAnswer((_) async => room);
      when(
        () => mockRepository.getVoteTracks('room-9'),
      ).thenAnswer((_) async => [track]);

      final loaded = await eventsProvider.loadEvent('room-9');

      expect(loaded.tracks.single.id, 'track-9');
      expect(eventsProvider.selectedEvent?.id, 'room-9');
      expect(eventsProvider.events.single.name, 'Reload');
    });

    test('loadEvent rejects a room that is not an event', () async {
      when(() => mockRepository.getRoomById('room-9')).thenAnswer(
        (_) async => Room(
          id: 'room-9',
          name: 'Playlist',
          ownerId: 'user-1',
          kind: RoomKind.playlist,
        ),
      );

      expect(
        () => eventsProvider.loadEvent('room-9'),
        throwsA(isA<Exception>()),
      );
      expect(eventsProvider.events, isEmpty);
    });
  });
}
