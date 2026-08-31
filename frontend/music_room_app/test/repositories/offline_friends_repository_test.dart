import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/core/repositories/offline_friends_repository.dart';
import 'package:music_room_app/models/friendship.dart';

class MockFriendsRepository extends Mock implements FriendsRepository {}

class MockConnectivity extends Mock implements Connectivity {}

class MockBox<T> extends Mock implements Box<T> {}

FriendDto _friend(String id) => FriendDto(friendshipId: 'fs-$id', friendId: id);

void main() {
  late MockFriendsRepository remote;
  late MockConnectivity connectivity;
  late MockBox<Map> box;
  late OfflineFriendsRepository repo;

  setUp(() {
    remote = MockFriendsRepository();
    connectivity = MockConnectivity();
    box = MockBox<Map>();
    repo = OfflineFriendsRepository(
      remoteRepository: remote,
      connectivity: connectivity,
      cacheBox: box,
    );
  });

  test('getFriends fetches from remote and caches it when online', () async {
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => remote.getFriends()).thenAnswer((_) async => [_friend('u1')]);
    when(() => box.put(any(), any())).thenAnswer((_) async {});

    final result = await repo.getFriends();

    expect(result.single.friendId, equals('u1'));
    verify(() => box.put('friends', any())).called(1);
  });

  test('getFriends serves the cached list when offline', () async {
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => box.get('friends')).thenReturn({
      'list': [_friend('u1').toJson(), _friend('u2').toJson()],
    });

    final result = await repo.getFriends();

    expect(result.map((f) => f.friendId), containsAll(['u1', 'u2']));
    // * Offline -> remote must never be contacted.
    verifyNever(() => remote.getFriends());
  });

  test('getFriends falls back to cache when the remote call throws', () async {
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => remote.getFriends()).thenThrow(Exception('network timeout'));
    when(() => box.get('friends')).thenReturn({
      'list': [_friend('u9').toJson()],
    });

    final result = await repo.getFriends();

    expect(result.single.friendId, equals('u9'));
  });

  test(
    'applySnapshot splits friendships into friends / incoming / outgoing',
    () async {
      when(() => box.put(any(), any())).thenAnswer((_) async {});
      final now = DateTime.parse('2026-01-01T00:00:00.000Z');

      await repo.applySnapshot('me', [
        FriendshipDto(
          id: 'fs-acc',
          requesterId: 'me',
          addresseeId: 'u2',
          status: 'ACCEPTED',
          createdAt: now,
        ),
        FriendshipDto(
          id: 'fs-in',
          requesterId: 'u3',
          addresseeId: 'me',
          status: 'PENDING',
          createdAt: now,
        ),
        FriendshipDto(
          id: 'fs-out',
          requesterId: 'me',
          addresseeId: 'u4',
          status: 'PENDING',
          createdAt: now,
        ),
      ]);

      final friendsPut =
          verify(() => box.put('friends', captureAny())).captured.single as Map;
      expect((friendsPut['list'] as List).single['friendId'], 'u2');

      final incomingPut =
          verify(() => box.put('incoming', captureAny())).captured.single
              as Map;
      expect((incomingPut['list'] as List).single['id'], 'fs-in');

      final outgoingPut =
          verify(() => box.put('outgoing', captureAny())).captured.single
              as Map;
      expect((outgoingPut['list'] as List).single['id'], 'fs-out');
    },
  );
}
