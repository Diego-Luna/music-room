import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/providers/rooms_provider.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  late RoomsProvider roomsProvider;
  late MockRoomRepository mockRepository;

  setUp(() {
    mockRepository = MockRoomRepository();
    roomsProvider = RoomsProvider(repository: mockRepository);
  });

  group('RoomsProvider Tests', () {
    test('Initial state is empty and not loading', () {
      expect(roomsProvider.rooms, isEmpty);
      expect(roomsProvider.currentActiveRoom, isNull);
      expect(roomsProvider.isLoading, false);
      expect(roomsProvider.error, isNull);
    });

    test('fetchRooms sets rooms on success', () async {
      final mockRooms = [
        Room(id: 'room-1', name: 'Chill Room', ownerId: 'user-1'),
      ];
      when(() => mockRepository.getRooms()).thenAnswer((_) async => mockRooms);

      await roomsProvider.fetchRooms();

      expect(roomsProvider.rooms, equals(mockRooms));
      expect(roomsProvider.isLoading, false);
      expect(roomsProvider.error, isNull);
    });

    test('fetchRooms sets error on failure', () async {
      when(() => mockRepository.getRooms()).thenThrow(Exception('API Error'));

      await roomsProvider.fetchRooms();

      expect(roomsProvider.rooms, isEmpty);
      expect(roomsProvider.isLoading, false);
      expect(roomsProvider.error, contains('API Error'));
    });

    test(
      'handleDelegateUpdated updates current active room controller',
      () async {
        final mockRoom = Room(
          id: 'room-1',
          name: 'Rock Room',
          ownerId: 'user-1',
          currentControllerId: null,
        );
        roomsProvider.selectRoom(mockRoom);
        expect(roomsProvider.currentActiveRoom?.currentControllerId, isNull);

        roomsProvider.handleDelegateUpdated('room-1', 'delegate-123');
        expect(
          roomsProvider.currentActiveRoom?.currentControllerId,
          equals('delegate-123'),
        );
      },
    );

    test('handleDJRoleGranted updates delegate controller', () async {
      final mockRoom = Room(
        id: 'room-1',
        name: 'Rock Room',
        ownerId: 'user-1',
        currentControllerId: null,
      );
      roomsProvider.selectRoom(mockRoom);
      expect(roomsProvider.currentActiveRoom?.currentControllerId, isNull);

      roomsProvider.handleDJRoleGranted('room-1', 'dj-456');
      expect(
        roomsProvider.currentActiveRoom?.currentControllerId,
        equals('dj-456'),
      );
    });

    test('handleMemberJoined triggers notifications/listeners', () async {
      var notified = false;
      roomsProvider.addListener(() {
        notified = true;
      });
      roomsProvider.handleMemberJoined('room-1', 'user-2');
      expect(notified, isTrue);
    });

    test('handleMemberLeft triggers notifications/listeners', () async {
      var notified = false;
      roomsProvider.addListener(() {
        notified = true;
      });
      roomsProvider.handleMemberLeft('room-1', 'user-2');
      expect(notified, isTrue);
    });
  });
}
