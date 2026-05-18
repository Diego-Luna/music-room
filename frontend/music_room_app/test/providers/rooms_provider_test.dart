import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/mock_api_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/providers/rooms_provider.dart';

class MockMockApiRepository extends Mock implements MockApiRepository {}

void main() {
  late RoomsProvider roomsProvider;
  late MockMockApiRepository mockRepository;

  setUp(() {
    mockRepository = MockMockApiRepository();
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

    test('delegateControl calls repository and updates active room', () async {
      final mockRoom = Room(
        id: 'room-1',
        name: 'Rock Room',
        ownerId: 'user-1',
        currentControllerId: 'user-2',
      );

      when(
        () => mockRepository.delegateRoomControl(any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockRepository.getRooms()).thenAnswer((_) async => [mockRoom]);

      roomsProvider.selectRoom(mockRoom);
      await roomsProvider.delegateControl('room-1', 'user-2');

      verify(
        () => mockRepository.delegateRoomControl('room-1', 'user-2'),
      ).called(1);
      expect(
        roomsProvider.currentActiveRoom?.currentControllerId,
        equals('user-2'),
      );
    });

    test(
      'revokeControl calls repository and updates active room controller to owner',
      () async {
        final mockRoom = Room(
          id: 'room-1',
          name: 'Rock Room',
          ownerId: 'user-1',
          currentControllerId: 'user-1',
        );

        when(
          () => mockRepository.revokeRoomControl(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockRepository.getRooms(),
        ).thenAnswer((_) async => [mockRoom]);

        roomsProvider.selectRoom(mockRoom);
        await roomsProvider.revokeControl('room-1');

        verify(() => mockRepository.revokeRoomControl('room-1')).called(1);
        expect(
          roomsProvider.currentActiveRoom?.currentControllerId,
          equals('user-1'),
        );
      },
    );
  });
}
