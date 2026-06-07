import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/models/room.dart';

void main() {
  test('Room.fromJson maps basic fields correctly', () {
    final json = {
      'id': 'room-1',
      'name': 'My Room',
      'ownerId': 'owner-123',
      'kind': 'PLAYLIST',
      'visibility': 'PUBLIC',
      'tracks': [],
      'createdAt': '2026-05-23T12:00:00.000Z',
    };
    final room = Room.fromJson(json);
    expect(room.id, equals('room-1'));
    expect(room.name, equals('My Room'));
    expect(room.ownerId, equals('owner-123'));
    expect(room.kind, equals(RoomKind.playlist));
  });
}
