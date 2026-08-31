import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/repositories/offline_friends_repository.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/offline_action.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/core/services/connectivity_sync_manager.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

class MockOfflineCache extends Mock implements OfflineCache {}

class MockApiClient extends Mock implements ApiClient {}

class MockFriendsCache extends Mock implements OfflineFriendsRepository {}

class MockConnectivity extends Mock implements Connectivity {}

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
    registerFallbackValue(<String>{});
  });

  setUp(() {
    mockRemote = MockRoomRepository();
    mockCache = MockOfflineCache();
    syncManager = ConnectivitySyncManager(
      remoteRepository: mockRemote,
      cache: mockCache,
    );
    // * Called after every successful drain; harmless default for all tests.
    when(() => mockCache.deleteRoomsExcept(any())).thenAnswer((_) async {});
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

  test(
    'should route addVoteTrack actions to the vote endpoint, not the playlist one',
    () async {
      final track = Track(
        id: 't1',
        providerId: 'p1',
        title: 'Song',
        artist: 'Artist',
        durationMs: 1000,
      );
      final action = OfflineAction(
        id: 'addVote-r1-p1-1',
        roomId: 'r1',
        type: 'addVoteTrack',
        payload: track.toJson(),
        createdAt: DateTime.now(),
      );

      when(() => mockCache.getPendingActions()).thenReturn([action]);
      when(
        () => mockRemote.addVoteTrack('r1', any()),
      ).thenAnswer((_) async => track);
      when(
        () => mockCache.removeAction('addVote-r1-p1-1'),
      ).thenAnswer((_) async {});
      when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
      when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

      await syncManager.syncQueue();

      verify(() => mockRemote.addVoteTrack('r1', any())).called(1);
      verifyNever(() => mockRemote.addPlaylistTrack(any(), any()));
      verify(() => mockCache.removeAction('addVote-r1-p1-1')).called(1);
    },
  );

  test(
    'discards stale move actions without replaying them (reorder is online-only)',
    () async {
      final action = OfflineAction(
        id: 'move-r1-t1-1',
        roomId: 'r1',
        type: 'move',
        payload: {'trackId': 't1', 'newPosition': '2'},
        createdAt: DateTime.now(),
      );

      when(() => mockCache.getPendingActions()).thenReturn([action]);
      when(
        () => mockCache.removeAction('move-r1-t1-1'),
      ).thenAnswer((_) async {});
      when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
      when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

      await syncManager.syncQueue();

      // Reordering is never queued/replayed anymore; the stale action is just
      // dropped from the queue.
      verifyNever(
        () => mockRemote.movePlaylistTrack(
          any(),
          any(),
          afterTrackId: any(named: 'afterTrackId'),
          beforeTrackId: any(named: 'beforeTrackId'),
        ),
      );
      verify(() => mockCache.removeAction('move-r1-t1-1')).called(1);
    },
  );

  test(
    'should send queued playlist removals to the remote on reconnect',
    () async {
      final action = OfflineAction(
        id: 'removePlaylist-r1-t1-1',
        roomId: 'r1',
        type: 'removePlaylistTrack',
        payload: {'trackId': 't1'},
        createdAt: DateTime.now(),
      );

      when(() => mockCache.getPendingActions()).thenReturn([action]);
      when(
        () => mockRemote.removePlaylistTrack('r1', 't1'),
      ).thenAnswer((_) async {});
      when(
        () => mockCache.removeAction('removePlaylist-r1-t1-1'),
      ).thenAnswer((_) async {});
      when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
      when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

      await syncManager.syncQueue();

      verify(() => mockRemote.removePlaylistTrack('r1', 't1')).called(1);
      verify(() => mockCache.removeAction('removePlaylist-r1-t1-1')).called(1);
    },
  );

  test(
    'should discard (not block) a 404 removal and keep draining the queue',
    () async {
      // * a1 already removed by someone else -> backend returns 404.
      // * a2 is a valid vote that must still be processed afterwards.
      final a1 = OfflineAction(
        id: 'removePlaylist-r1-t1-1',
        roomId: 'r1',
        type: 'removePlaylistTrack',
        payload: {'trackId': 't1'},
        createdAt: DateTime.now(),
      );
      final a2 = OfflineAction(
        id: 'vote-r1-t2-2',
        roomId: 'r1',
        type: 'vote',
        payload: {'trackId': 't2', 'value': 1},
        createdAt: DateTime.now(),
      );

      when(() => mockCache.getPendingActions()).thenReturn([a1, a2]);
      when(
        () => mockRemote.removePlaylistTrack('r1', 't1'),
      ).thenThrow(Exception('DioException: status code of 404 Not Found'));
      when(
        () => mockRemote.voteForTrack('r1', 't2', 1),
      ).thenAnswer((_) async {});
      when(() => mockCache.removeAction(any())).thenAnswer((_) async {});
      when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
      when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

      await syncManager.syncQueue();

      // * 404 action discarded, queue not blocked, next action still ran.
      verify(() => mockCache.removeAction('removePlaylist-r1-t1-1')).called(1);
      verify(() => mockRemote.voteForTrack('r1', 't2', 1)).called(1);
      verify(() => mockCache.removeAction('vote-r1-t2-2')).called(1);
    },
  );

  test(
    'should discard (not block) a 403 forbidden action and keep draining',
    () async {
      // * a1 rejected by the backend (e.g. non-premium delete) -> 403.
      // * a2 must still be processed: one forbidden action cannot freeze all.
      final a1 = OfflineAction(
        id: 'removePlaylist-r1-t1-1',
        roomId: 'r1',
        type: 'removePlaylistTrack',
        payload: {'trackId': 't1'},
        createdAt: DateTime.now(),
      );
      final a2 = OfflineAction(
        id: 'vote-r1-t2-2',
        roomId: 'r1',
        type: 'vote',
        payload: {'trackId': 't2', 'value': 1},
        createdAt: DateTime.now(),
      );

      when(() => mockCache.getPendingActions()).thenReturn([a1, a2]);
      when(() => mockRemote.removePlaylistTrack('r1', 't1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/rooms/r1/playlist/t1'),
          response: Response(
            requestOptions: RequestOptions(path: '/rooms/r1/playlist/t1'),
            statusCode: 403,
          ),
        ),
      );
      when(
        () => mockRemote.voteForTrack('r1', 't2', 1),
      ).thenAnswer((_) async {});
      when(() => mockCache.removeAction(any())).thenAnswer((_) async {});
      when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
      when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

      await syncManager.syncQueue();

      verify(() => mockCache.removeAction('removePlaylist-r1-t1-1')).called(1);
      verify(() => mockRemote.voteForTrack('r1', 't2', 1)).called(1);
      verify(() => mockCache.removeAction('vote-r1-t2-2')).called(1);
    },
  );

  test('should pause (not discard) on a transient 500 server error', () async {
    final a1 = OfflineAction(
      id: 'vote-r1-t1-1',
      roomId: 'r1',
      type: 'vote',
      payload: {'trackId': 't1', 'value': 1},
      createdAt: DateTime.now(),
    );

    when(() => mockCache.getPendingActions()).thenReturn([a1]);
    when(() => mockRemote.voteForTrack('r1', 't1', 1)).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/rooms/r1/tracks/t1/vote'),
        response: Response(
          requestOptions: RequestOptions(path: '/rooms/r1/tracks/t1/vote'),
          statusCode: 500,
        ),
      ),
    );
    when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
    when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

    await syncManager.syncQueue();

    // * 500 is transient: keep the action queued for a later retry.
    verifyNever(() => mockCache.removeAction('vote-r1-t1-1'));
  });

  test(
    'snapshot must preserve cached tracks when the list endpoint returns none',
    () async {
      // * getRooms (list endpoint) returns rooms WITHOUT tracks.
      final roomNoTracks = Room(id: 'r1', name: 'R1', ownerId: 'o1');
      // * but the cache already holds the populated room.
      final cachedRoom = Room(
        id: 'r1',
        name: 'R1',
        ownerId: 'o1',
        tracks: [
          Track(
            id: 't1',
            providerId: 'p1',
            title: 'Cached',
            artist: 'A',
            durationMs: 1000,
          ),
        ],
      );

      when(() => mockCache.getPendingActions()).thenReturn([]);
      when(() => mockRemote.getRooms()).thenAnswer((_) async => [roomNoTracks]);
      when(() => mockCache.getRoomById('r1')).thenReturn(cachedRoom);
      when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

      await syncManager.syncQueue();

      final captured = verify(() => mockCache.saveRooms(captureAny())).captured;
      final List<Room> saved = (captured.first as List).cast<Room>();
      expect(saved.single.tracks, hasLength(1));
      expect(saved.single.tracks.first.id, equals('t1'));
    },
  );

  test(
    'emits a discard report with the backend cause when an action is rejected',
    () async {
      final a1 = OfflineAction(
        id: 'removePlaylist-r1-t1-1',
        roomId: 'r1',
        type: 'removePlaylistTrack',
        payload: {'trackId': 't1'},
        createdAt: DateTime.now(),
      );

      when(() => mockCache.getPendingActions()).thenReturn([a1]);
      when(() => mockRemote.removePlaylistTrack('r1', 't1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/rooms/r1/playlist/t1'),
          response: Response(
            requestOptions: RequestOptions(path: '/rooms/r1/playlist/t1'),
            statusCode: 403,
            data: {'message': 'Premium subscription required'},
          ),
        ),
      );
      when(() => mockCache.removeAction(any())).thenAnswer((_) async {});
      when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
      when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

      expectLater(
        syncManager.discards,
        emits(
          predicate<List<SyncDiscard>>(
            (d) =>
                d.length == 1 &&
                d.first.label == 'Remove from playlist' &&
                d.first.reason == 'Premium subscription required',
          ),
        ),
      );

      await syncManager.syncQueue();
    },
  );

  test(
    'stays silent (no notification) for a 404 on a removal — already gone',
    () async {
      final a1 = OfflineAction(
        id: 'removePlaylist-r1-t1-1',
        roomId: 'r1',
        type: 'removePlaylistTrack',
        payload: {'trackId': 't1'},
        createdAt: DateTime.now(),
      );

      when(() => mockCache.getPendingActions()).thenReturn([a1]);
      when(() => mockRemote.removePlaylistTrack('r1', 't1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/rooms/r1/playlist/t1'),
          response: Response(
            requestOptions: RequestOptions(path: '/rooms/r1/playlist/t1'),
            statusCode: 404,
          ),
        ),
      );
      when(() => mockCache.removeAction(any())).thenAnswer((_) async {});
      when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
      when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

      final reports = <List<SyncDiscard>>[];
      final sub = syncManager.discards.listen(reports.add);

      await syncManager.syncQueue();
      await pumpEventQueue();

      expect(reports, isEmpty);
      await sub.cancel();
    },
  );

  test('purges ghost rooms using the full server room set', () async {
    final r1 = Room(id: 'r1', name: 'R1', ownerId: 'o1');
    when(() => mockCache.getPendingActions()).thenReturn([]);
    when(() => mockRemote.getRooms()).thenAnswer((_) async => [r1]);
    when(() => mockCache.getRoomById(any())).thenReturn(null);
    when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

    await syncManager.syncQueue();

    final captured = verify(
      () => mockCache.deleteRoomsExcept(captureAny()),
    ).captured;
    expect(captured.single, equals(<String>{'r1'}));
  });

  test('GET /sync after drain refreshes the friends cache', () async {
    final api = MockApiClient();
    final friends = MockFriendsCache();
    registerFallbackValue(<FriendshipDto>[]);
    when(() => mockCache.getPendingActions()).thenReturn([]);
    when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
    when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});
    when(() => friends.applySnapshot(any(), any())).thenAnswer((_) async {});
    when(() => api.get(ApiConfig.sync)).thenAnswer(
      (_) async => Response(
        data: {
          'me': {'id': 'me1'},
          'friendships': [
            {
              'id': 'fs1',
              'requesterId': 'me1',
              'addresseeId': 'u2',
              'status': 'ACCEPTED',
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
          ],
        },
        requestOptions: RequestOptions(path: ApiConfig.sync),
        statusCode: 200,
      ),
    );

    final wired = ConnectivitySyncManager(
      remoteRepository: mockRemote,
      cache: mockCache,
      apiClient: api,
      friendsCache: friends,
    );
    await wired.syncQueue();

    verify(() => api.get(ApiConfig.sync)).called(1);
    final captured = verify(
      () => friends.applySnapshot(captureAny(), captureAny()),
    ).captured;
    expect(captured[0], 'me1');
    expect((captured[1] as List<FriendshipDto>).single.addresseeId, 'u2');
  });

  test('startMonitoring drains the queue when already online (cold start)',
      () async {
    final connectivity = MockConnectivity();
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => const Stream.empty());

    final action = OfflineAction(
      id: 'a1',
      roomId: 'r1',
      type: 'vote',
      payload: {'trackId': 't1', 'value': 1},
      createdAt: DateTime.now(),
    );
    when(() => mockCache.getPendingActions()).thenReturn([action]);
    when(() => mockRemote.voteForTrack('r1', 't1', 1)).thenAnswer((_) async {});
    when(() => mockCache.removeAction('a1')).thenAnswer((_) async {});
    when(() => mockRemote.getRooms()).thenAnswer((_) async => []);
    when(() => mockCache.saveRooms(any())).thenAnswer((_) async {});

    final manager = ConnectivitySyncManager(
      remoteRepository: mockRemote,
      cache: mockCache,
      connectivity: connectivity,
    );
    manager.startMonitoring();
    await pumpEventQueue();

    verify(() => mockRemote.voteForTrack('r1', 't1', 1)).called(1);
    manager.stopMonitoring();
  });

  test('syncQueue is a no-op when there is no session (Start / Login)',
      () async {
    when(() => mockCache.getPendingActions()).thenReturn([]);

    final manager = ConnectivitySyncManager(
      remoteRepository: mockRemote,
      cache: mockCache,
      hasSession: () async => false,
    );
    await manager.syncQueue();

    verifyNever(() => mockRemote.getRooms());
    verifyNever(() => mockCache.getPendingActions());
  });
}
