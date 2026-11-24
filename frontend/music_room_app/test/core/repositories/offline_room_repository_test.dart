import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/repositories/offline_room_repository.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/offline_action.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

class MockOfflineCache extends Mock implements OfflineCache {}

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late OfflineRoomRepository repo;
  late MockRoomRepository mockRemote;
  late MockOfflineCache mockCache;
  late MockConnectivity connectivity;

  setUpAll(() {
    registerFallbackValue(Room(id: 'dummy', name: 'dummy', ownerId: 'dummy'));
    registerFallbackValue(
      Track(
        id: 'dummy',
        providerId: 'dummy',
        title: 'dummy',
        artist: 'dummy',
        durationMs: 0,
      ),
    );
    registerFallbackValue(
      OfflineAction(
        id: 'dummy',
        roomId: 'dummy',
        type: 'dummy',
        payload: {},
        createdAt: DateTime.now(),
      ),
    );
  });

  setUp(() {
    mockRemote = MockRoomRepository();
    mockCache = MockOfflineCache();
    connectivity = MockConnectivity();
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    repo = OfflineRoomRepository(
      remoteRepository: mockRemote,
      cache: mockCache,
      connectivity: connectivity,
    );
  });

  test('should return cached rooms when remote API fails', () async {
    // * Arrange
    when(
      () => mockRemote.getRooms(kind: any(named: 'kind')),
    ).thenThrow(Exception('No internet'));
    final room = Room(id: 'r1', name: 'Cached', ownerId: 'u1');
    when(() => mockCache.getRooms()).thenReturn([room]);

    // * Act
    final result = await repo.getRooms();

    // * Assert
    expect(result.length, 1);
    expect(result[0].name, 'Cached');
    verify(() => mockCache.getRooms()).called(1);
  });

  test(
    'should queue vote action and update cache optimistically when voteForTrack fails',
    () async {
      // * Arrange
      when(
        () => mockRemote.voteForTrack(
          any(),
          any(),
          any(),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
        ),
      ).thenThrow(Exception('No internet'));

      final track = Track(
        id: 't1',
        providerId: 'p1',
        title: 'Song',
        artist: 'Artist',
        durationMs: 120,
        score: 5,
      );
      final room = Room(id: 'r1', name: 'Room', ownerId: 'u1', tracks: [track]);

      when(() => mockCache.getRoomById('r1')).thenReturn(room);
      when(() => mockCache.saveRoom(any())).thenAnswer((_) async {});
      when(() => mockCache.enqueueAction(any())).thenAnswer((_) async {});

      // * Act
      await repo.voteForTrack('r1', 't1', 1);

      // * Assert
      verify(() => mockCache.enqueueAction(any())).called(1);
      verify(() => mockCache.saveRoom(any())).called(1);
    },
  );

  DioException _httpError(int statusCode) {
    final options = RequestOptions(path: '/rooms');
    return DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: statusCode),
    );
  }

  test('a 429 from the server is not replaced by the cache', () async {
    when(
      () => mockRemote.getRooms(kind: any(named: 'kind')),
    ).thenThrow(_httpError(429));

    await expectLater(repo.getRooms(), throwsA(isA<DioException>()));
    verifyNever(() => mockCache.getRooms());
  });

  test('deleting a room the server already removed drops the local copy', () async {
    when(() => mockRemote.deleteRoom('r1')).thenThrow(_httpError(404));
    when(() => mockCache.deleteRoom('r1')).thenAnswer((_) async {});

    await repo.deleteRoom('r1');

    verify(() => mockCache.deleteRoom('r1')).called(1);
  });
}
