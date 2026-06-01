import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/offline_action.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/core/services/connectivity_sync_manager.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

class MockOfflineCache extends Mock implements OfflineCache {}

void main() {
  late ConnectivitySyncManager syncManager;
  late MockRoomRepository mockRemote;
  late MockOfflineCache mockCache;

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
    syncManager = ConnectivitySyncManager(
      remoteRepository: mockRemote,
      cache: mockCache,
    );
  });

  test(
    'should process pending action queue and delete completed ones',
    () async {
      final action = OfflineAction(
        id: 'a1',
        roomId: 'r1',
        type: 'vote',
        payload: {'trackId': 't1', 'value': 1},
        createdAt: DateTime.now(),
      );

      when(() => mockCache.getPendingActions()).thenReturn([action]);
      when(
        () => mockRemote.voteForTrack('r1', 't1', 1),
      ).thenAnswer((_) async {});
      when(() => mockCache.removeAction('a1')).thenAnswer((_) async {});
      when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
      when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

      await syncManager.syncQueue();

      verify(() => mockRemote.voteForTrack('r1', 't1', 1)).called(1);
      verify(() => mockCache.removeAction('a1')).called(1);
    },
  );
}
