import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/models/room.dart';

class MockBox<T> extends Mock implements Box<T> {}

void main() {
  late OfflineCache cache;
  late MockBox<Map> mockRoomsBox;
  late MockBox<Map> mockActionsBox;

  setUp(() {
    mockRoomsBox = MockBox<Map>();
    mockActionsBox = MockBox<Map>();
    cache = OfflineCache.test(
      roomsBox: mockRoomsBox,
      actionsBox: mockActionsBox,
    );
  });

  test('should get and save rooms to cached_rooms box', () async {
    final room = Room(id: 'r1', name: 'Test Room', ownerId: 'u1');
    when(() => mockRoomsBox.values).thenReturn([room.toJson()]);
    when(() => mockRoomsBox.put(any(), any())).thenAnswer((_) async {});

    await cache.saveRooms([room]);
    final list = cache.getRooms();

    expect(list.length, 1);
    expect(list[0].id, 'r1');
    verify(() => mockRoomsBox.put('r1', any())).called(1);
  });

  test('deleteRoomsExcept removes only the rooms absent from keepIds', () async {
    when(() => mockRoomsBox.keys).thenReturn(['r1', 'r2', 'r3']);
    when(() => mockRoomsBox.delete(any())).thenAnswer((_) async {});

    await cache.deleteRoomsExcept({'r1', 'r3'});

    // * r2 is a ghost (deleted server-side) -> dropped; r1/r3 kept.
    verify(() => mockRoomsBox.delete('r2')).called(1);
    verifyNever(() => mockRoomsBox.delete('r1'));
    verifyNever(() => mockRoomsBox.delete('r3'));
  });
}
