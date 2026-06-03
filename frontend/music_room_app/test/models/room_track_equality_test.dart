import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

void main() {
  test('Room equality is based on id', () {
    final room1 = Room(id: '1', name: 'A', ownerId: 'o1');
    final room2 = Room(id: '1', name: 'B', ownerId: 'o2');
    expect(room1, equals(room2));
    expect(room1.hashCode, equals(room2.hashCode));
  });

  test('Track equality is based on id', () {
    final track1 = Track(
      id: '1',
      providerId: 'p1',
      title: 'A',
      artist: 'A',
      durationMs: 1,
    );
    final track2 = Track(
      id: '1',
      providerId: 'p2',
      title: 'B',
      artist: 'B',
      durationMs: 2,
    );
    expect(track1, equals(track2));
    expect(track1.hashCode, equals(track2.hashCode));
  });
}
