import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/models/room.dart';

void main() {
  test('Room.fromJson maps delegateUserId to currentControllerId', () {
    final json = {
      'id': 'room-1',
      'name': 'My Room',
      'ownerId': 'owner-123',
      'kind': 'DELEGATE',
      'visibility': 'PUBLIC',
      'tracks': [],
      'delegateUserId': 'dj-456',
      'createdAt': '2026-05-23T12:00:00.000Z',
    };
    final room = Room.fromJson(json);
    expect(room.currentControllerId, equals('dj-456'));
  });
}
