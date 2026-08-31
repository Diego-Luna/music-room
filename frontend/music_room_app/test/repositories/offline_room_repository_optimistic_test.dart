import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:music_room_app/core/repositories/offline_room_repository.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/offline_action.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

class MockOfflineCache extends Mock implements OfflineCache {}

class MockConnectivity extends Mock implements Connectivity {}

class FakeOfflineAction extends Fake implements OfflineAction {}

class FakeRoom extends Fake implements Room {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeOfflineAction());
    registerFallbackValue(FakeRoom());
    registerFallbackValue(RoomKind.playlist);
  });

  test('searchTracks throws when offline', () async {
    final remote = MockRoomRepository();
    final cache = MockOfflineCache();
    final connectivity = MockConnectivity();

    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.none]);

    final repo = OfflineRoomRepository(
      remoteRepository: remote,
      cache: cache,
      connectivity: connectivity,
    );

    expect(() => repo.searchTracks('test'), throwsA(isA<Exception>()));
  });

  test(
    'voteForTrack optimistically updates cache and sorts tracks by score',
    () async {
      final remote = MockRoomRepository();
      final cache = MockOfflineCache();
      final connectivity = MockConnectivity();

      final track1 = Track(
        id: 't1',
        providerId: 'p1',
        title: 'Song 1',
        artist: 'Artist 1',
        durationMs: 1000,
        score: 5,
      );
      final track2 = Track(
        id: 't2',
        providerId: 'p2',
        title: 'Song 2',
        artist: 'Artist 2',
        durationMs: 1000,
        score: 2,
      );
      final room = Room(
        id: 'r1',
        name: 'Room 1',
        ownerId: 'o1',
        tracks: [track1, track2],
      );

      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);
      when(() => cache.getRoomById('r1')).thenReturn(room);
      when(() => cache.saveRoom(any())).thenAnswer((_) async {});
      when(() => cache.enqueueAction(any())).thenAnswer((_) async {});

      final repo = OfflineRoomRepository(
        remoteRepository: remote,
        cache: cache,
        connectivity: connectivity,
      );

      await repo.voteForTrack(
        'r1',
        't2',
        5,
      ); // t2 score becomes 7, so it should be first in sorted list

      final capturedRooms = verify(() => cache.saveRoom(captureAny())).captured;
      final Room savedRoom = capturedRooms.first as Room;
      expect(savedRoom.tracks[0].id, equals('t2')); // sorted first
      expect(savedRoom.tracks[0].score, equals(7));
      expect(savedRoom.tracks[1].id, equals('t1')); // sorted second
    },
  );

  test('addVoteTrack optimistically adds track to cache', () async {
    final remote = MockRoomRepository();
    final cache = MockOfflineCache();
    final connectivity = MockConnectivity();

    final room = Room(id: 'r1', name: 'Room 1', ownerId: 'o1', tracks: []);
    final newTrack = Track(
      id: 't3',
      providerId: 'p3',
      title: 'Song 3',
      artist: 'Artist 3',
      durationMs: 1000,
    );

    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => cache.getRoomById('r1')).thenReturn(room);
    when(() => cache.saveRoom(any())).thenAnswer((_) async {});
    when(() => cache.enqueueAction(any())).thenAnswer((_) async {});

    final repo = OfflineRoomRepository(
      remoteRepository: remote,
      cache: cache,
      connectivity: connectivity,
    );

    await repo.addVoteTrack('r1', newTrack);

    final capturedRooms = verify(() => cache.saveRoom(captureAny())).captured;
    final Room savedRoom = capturedRooms.first as Room;
    expect(savedRoom.tracks, hasLength(1));
    expect(savedRoom.tracks.first.id, equals('t3'));

    // * Must queue a vote-specific action so resync hits the vote endpoint,
    // * not the playlist one (regression guard).
    final capturedActions = verify(
      () => cache.enqueueAction(captureAny()),
    ).captured;
    final OfflineAction queued = capturedActions.first as OfflineAction;
    expect(queued.type, equals('addVoteTrack'));
  });

  test(
    'removePlaylistTrack offline removes from cache and queues action',
    () async {
      final remote = MockRoomRepository();
      final cache = MockOfflineCache();
      final connectivity = MockConnectivity();

      final keep = Track(
        id: 't1',
        providerId: 'p1',
        title: 'Keep',
        artist: 'A1',
        durationMs: 1000,
      );
      final remove = Track(
        id: 't2',
        providerId: 'p2',
        title: 'Remove',
        artist: 'A2',
        durationMs: 1000,
      );
      final room = Room(
        id: 'r1',
        name: 'Room 1',
        ownerId: 'o1',
        tracks: [keep, remove],
      );

      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);
      when(() => cache.getRoomById('r1')).thenReturn(room);
      when(() => cache.saveRoom(any())).thenAnswer((_) async {});
      when(() => cache.enqueueAction(any())).thenAnswer((_) async {});

      final repo = OfflineRoomRepository(
        remoteRepository: remote,
        cache: cache,
        connectivity: connectivity,
      );

      await repo.removePlaylistTrack('r1', 't2');

      // * Optimistic removal: track gone from cached room immediately.
      final capturedRooms = verify(() => cache.saveRoom(captureAny())).captured;
      final Room savedRoom = capturedRooms.first as Room;
      expect(savedRoom.tracks, hasLength(1));
      expect(savedRoom.tracks.first.id, equals('t1'));

      // * Queued for resync (so the deletion is not lost on reconnect).
      final capturedActions = verify(
        () => cache.enqueueAction(captureAny()),
      ).captured;
      final OfflineAction queued = capturedActions.first as OfflineAction;
      expect(queued.type, equals('removePlaylistTrack'));
      expect(queued.payload['trackId'], equals('t2'));

      // * Must not hit the network while offline.
      verifyNever(() => remote.removePlaylistTrack(any(), any()));
    },
  );

  test('createRoom throws when offline and never hits the network', () async {
    final remote = MockRoomRepository();
    final cache = MockOfflineCache();
    final connectivity = MockConnectivity();
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.none]);

    final repo = OfflineRoomRepository(
      remoteRepository: remote,
      cache: cache,
      connectivity: connectivity,
    );

    await expectLater(
      repo.createRoom(name: 'New', kind: RoomKind.playlist, isPublic: true),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('offline'),
        ),
      ),
    );
    verifyNever(
      () => remote.createRoom(
        name: any(named: 'name'),
        kind: any(named: 'kind'),
        isPublic: any(named: 'isPublic'),
      ),
    );
  });
}
