import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/config/location_config.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/services/proximity_service.dart';
import 'package:music_room_app/core/services/proximity_watcher.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/providers/events_provider.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  late MockRoomRepository repository;
  late EventsProvider events;
  late ProximityWatcher watcher;
  late List<NearbyEvent> hits;

  final venue = Room(
    id: 'paris',
    name: 'Paris Party',
    ownerId: 'u1',
    kind: RoomKind.vote,
    isPublic: true,
    description: 'Electronic night',
    voteLocationLat: 48.8566,
    voteLocationLng: 2.3522,
    voteLocationRadiusM: 500,
  );

  setUp(() {
    LocationConfig.resetForTest();
    repository = MockRoomRepository();
    events = EventsProvider(repository: repository);
    hits = [];
    watcher = ProximityWatcher(events: events)..onNearby = hits.add;
    when(
      () => repository.getRooms(kind: RoomKind.vote),
    ).thenAnswer((_) async => [venue]);
    when(() => repository.getVoteTracks(any())).thenAnswer((_) async => []);
  });

  tearDown(() {
    watcher.stop();
    LocationConfig.resetForTest();
  });

  test('announces a public geo event when position enters the zone', () async {
    LocationConfig.setForTest(lat: 48.8566, lng: 2.3522);
    watcher.start();
    expect(hits, isEmpty);

    await events.fetchEvents();
    expect(hits, hasLength(1));
    expect(hits.first.room.id, 'paris');
    expect(hits.first.distanceMeters, lessThan(1));
  });

  test('does not re-announce while still inside the same zone', () async {
    LocationConfig.setForTest(lat: 48.8566, lng: 2.3522);
    watcher.start();
    await events.fetchEvents();
    expect(hits, hasLength(1));

    await events.fetchEvents();
    expect(hits, hasLength(1));
  });

  test('re-announces after leaving and re-entering', () async {
    LocationConfig.setForTest(lat: 48.8566, lng: 2.3522);
    watcher.start();
    await events.fetchEvents();
    expect(hits, hasLength(1));

    LocationConfig.setForTest(lat: 0, lng: 0);
    expect(hits, hasLength(1));

    LocationConfig.setForTest(lat: 48.8566, lng: 2.3522);
    expect(hits, hasLength(2));
  });

  test('replay shows the same venue again without moving', () async {
    LocationConfig.setForTest(lat: 48.8566, lng: 2.3522);
    watcher.start();
    await events.fetchEvents();
    watcher.replay('paris');
    expect(hits, hasLength(2));
  });
}
