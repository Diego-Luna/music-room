import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/providers/events_provider.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  test('EventsProvider tracks voted track IDs', () async {
    final repo = MockRoomRepository();
    when(() => repo.voteForTrack(any(), any(), any())).thenAnswer((_) async {});
    when(
      () => repo.getRooms(kind: any(named: 'kind')),
    ).thenAnswer((_) async => []);

    final provider = EventsProvider(repository: repo);

    expect(provider.votedTrackIds, isEmpty);
    await provider.voteForTrack('room1', 'track1', 1);
    expect(provider.votedTrackIds.contains('track1'), isTrue);
  });
}
