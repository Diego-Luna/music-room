import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/services/connectivity_sync_manager.dart';
import 'package:music_room_app/core/services/push_token_service.dart';
import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/invitation.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/subscription_provider.dart';
import 'package:music_room_app/config/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockTokenStorage extends Mock implements TokenStorage {}
class MockRoomRepository extends Mock implements RoomRepository {}
class MockFriendsRepository extends Mock implements FriendsRepository {}
class MockOfflineCache extends Mock implements OfflineCache {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

Response<T> _ok<T>(T data) => Response<T>(
  data: data,
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
);

void main() {
  setUpAll(() {
    registerFallbackValue(RoomKind.vote);
  });

  group('Request Deduplication and In-Flight Lock Tests', () {
    test('SubscriptionProvider: Concurrent refreshTier() calls execute only once', () async {
      final api = MockApiClient();
      final provider = SubscriptionProvider(apiClient: api);
      final completer = Completer<Response<dynamic>>();

      when(() => api.get(ApiConfig.subscriptionMe)).thenAnswer((_) => completer.future);

      // Trigger 5 concurrent calls
      final futures = Future.wait([
        provider.refreshTier(),
        provider.refreshTier(),
        provider.refreshTier(),
        provider.refreshTier(),
        provider.refreshTier(),
      ]);

      completer.complete(_ok<dynamic>({'tier': 'FREE'}));
      await futures;

      verify(() => api.get(ApiConfig.subscriptionMe)).called(1);
    });

    test('PushTokenService: Concurrent registerIfNeeded() calls execute only once', () async {
      final api = MockApiClient();
      final storage = MockFlutterSecureStorage();
      final service = PushTokenService(client: api, storage: storage);
      final completer = Completer<Response<dynamic>>();

      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => 'existing-token-12345');
      when(() => api.post(ApiConfig.notificationsRegister, data: any(named: 'data')))
          .thenAnswer((_) => completer.future);

      final futures = Future.wait([
        service.registerIfNeeded(),
        service.registerIfNeeded(),
        service.registerIfNeeded(),
        service.registerIfNeeded(),
      ]);

      completer.complete(_ok<dynamic>({'registered': true}));
      await futures;

      verify(() => api.post(ApiConfig.notificationsRegister, data: any(named: 'data'))).called(1);
    });

    test('NotificationsProvider: Concurrent fetchNotifications() calls execute only once', () async {
      final roomRepo = MockRoomRepository();
      final friendsRepo = MockFriendsRepository();
      final provider = NotificationsProvider(
        roomRepository: roomRepo,
        friendsRepository: friendsRepo,
      );

      final completer = Completer<List<FriendshipDto>>();

      when(() => friendsRepo.getIncomingRequests()).thenAnswer((_) => completer.future);
      when(() => roomRepo.getInvitations()).thenAnswer((_) async => <RoomInvitationDto>[]);
      when(() => friendsRepo.getOutgoingRequests()).thenAnswer((_) async => <FriendshipDto>[]);
      when(() => roomRepo.getSentInvitations()).thenAnswer((_) async => <RoomInvitationDto>[]);

      final futures = Future.wait([
        provider.fetchNotifications(),
        provider.fetchNotifications(),
        provider.fetchNotifications(),
      ]);

      completer.complete(<FriendshipDto>[]);
      await futures;

      verify(() => friendsRepo.getIncomingRequests()).called(1);
      verify(() => roomRepo.getInvitations()).called(1);
    });

    test('EventsProvider: Concurrent fetchEvents() calls execute only once', () async {
      final repo = MockRoomRepository();
      final provider = EventsProvider(repository: repo);
      final completer = Completer<List<Room>>();

      when(() => repo.getRooms(kind: any(named: 'kind'))).thenAnswer((_) => completer.future);

      final futures = Future.wait([
        provider.fetchEvents(),
        provider.fetchEvents(),
        provider.fetchEvents(),
      ]);

      completer.complete(<Room>[]);
      await futures;

      verify(() => repo.getRooms(kind: any(named: 'kind'))).called(1);
    });

    test('PlaylistsProvider: Concurrent fetchPlaylists() calls execute only once', () async {
      final repo = MockRoomRepository();
      final provider = PlaylistsProvider(repository: repo);
      final completer = Completer<List<Room>>();

      when(() => repo.getRooms(kind: any(named: 'kind'))).thenAnswer((_) => completer.future);

      final futures = Future.wait([
        provider.fetchPlaylists(),
        provider.fetchPlaylists(),
        provider.fetchPlaylists(),
      ]);

      completer.complete(<Room>[]);
      await futures;

      verify(() => repo.getRooms(kind: any(named: 'kind'))).called(1);
    });

    test('PlaylistsProvider: createPlaylist() creates room and populates playlists without getting blocked', () async {
      final repo = MockRoomRepository();
      final provider = PlaylistsProvider(repository: repo);
      final testRoom = Room(
        id: 'playlist-123',
        name: 'New Playlist',
        kind: RoomKind.playlist,
        ownerId: 'owner-1',
        isPublic: true,
      );

      when(() => repo.createRoom(
            name: any(named: 'name'),
            kind: RoomKind.playlist,
            isPublic: any(named: 'isPublic'),
            description: any(named: 'description'),
            editAccess: any(named: 'editAccess'),
          )).thenAnswer((_) async => testRoom);

      when(() => repo.getRooms(kind: RoomKind.playlist))
          .thenAnswer((_) async => [testRoom]);
      when(() => repo.getPlaylistTracks(any()))
          .thenAnswer((_) async => []);

      final created = await provider.createPlaylist(
        name: 'New Playlist',
        isPublic: true,
        editAccess: 'EVERYONE',
      );

      expect(created.id, equals('playlist-123'));
      expect(provider.playlists, hasLength(1));
      expect(provider.playlists.first.id, equals('playlist-123'));
      verify(() => repo.createRoom(
            name: 'New Playlist',
            kind: RoomKind.playlist,
            isPublic: true,
            editAccess: 'EVERYONE',
          )).called(1);
      verify(() => repo.getRooms(kind: RoomKind.playlist)).called(1);
    });

    test('EventsProvider: createEvent() creates event and populates events without getting blocked', () async {
      final repo = MockRoomRepository();
      final provider = EventsProvider(repository: repo);
      final testEvent = Room(
        id: 'event-456',
        name: 'New Vote Event',
        kind: RoomKind.vote,
        ownerId: 'owner-1',
        isPublic: true,
      );

      when(() => repo.createRoom(
            name: any(named: 'name'),
            kind: RoomKind.vote,
            isPublic: any(named: 'isPublic'),
            description: any(named: 'description'),
            voteAccess: any(named: 'voteAccess'),
            voteWindow: any(named: 'voteWindow'),
            voteStartsAt: any(named: 'voteStartsAt'),
            voteEndsAt: any(named: 'voteEndsAt'),
            voteLocationLat: any(named: 'voteLocationLat'),
            voteLocationLng: any(named: 'voteLocationLng'),
            voteLocationRadiusM: any(named: 'voteLocationRadiusM'),
          )).thenAnswer((_) async => testEvent);

      when(() => repo.getRooms(kind: RoomKind.vote))
          .thenAnswer((_) async => [testEvent]);
      when(() => repo.getVoteTracks(any()))
          .thenAnswer((_) async => []);

      final created = await provider.createEvent(
        name: 'New Vote Event',
        description: 'Testing event creation',
        isPublic: true,
        voteAccess: 'EVERYONE',
        voteWindow: 'ALWAYS',
      );

      expect(created.id, equals('event-456'));
      expect(provider.events, hasLength(1));
      expect(provider.events.first.id, equals('event-456'));
      expect(provider.selectedEvent?.id, equals('event-456'));
      verify(() => repo.createRoom(
            name: any(named: 'name'),
            kind: RoomKind.vote,
            isPublic: any(named: 'isPublic'),
            description: any(named: 'description'),
            voteAccess: any(named: 'voteAccess'),
            voteWindow: any(named: 'voteWindow'),
          )).called(1);
      verify(() => repo.getRooms(kind: RoomKind.vote)).called(1);
    });

    test('PlaylistsProvider: fetchPlaylists(force: true) triggers fresh request', () async {
      final repo = MockRoomRepository();
      final provider = PlaylistsProvider(repository: repo);

      when(() => repo.getRooms(kind: any(named: 'kind')))
          .thenAnswer((_) async => []);

      await provider.fetchPlaylists();
      await provider.fetchPlaylists(force: true);

      verify(() => repo.getRooms(kind: any(named: 'kind'))).called(2);
    });

    test('ConnectivitySyncManager: Concurrent syncQueue() calls execute only once', () async {
      final repo = MockRoomRepository();
      final cache = MockOfflineCache();
      final manager = ConnectivitySyncManager(
        remoteRepository: repo,
        cache: cache,
        hasSession: () async => true,
      );

      final completer = Completer<List<Room>>();

      when(() => cache.getPendingActions()).thenReturn([]);
      when(() => repo.getRooms()).thenAnswer((_) => completer.future);
      when(() => cache.deleteRoomsExcept(any())).thenAnswer((_) async {});
      when(() => cache.saveRooms(any())).thenAnswer((_) async {});

      final futures = Future.wait([
        manager.syncQueue(),
        manager.syncQueue(),
        manager.syncQueue(),
      ]);

      completer.complete(<Room>[]);
      await futures;

      verify(() => repo.getRooms()).called(1);
    });

    test('AuthProvider: login() emits signedIn == true only once', () async {
      final api = MockApiClient();
      final tokenStorage = MockTokenStorage();
      final provider = AuthProvider(apiClient: api, tokenStorage: tokenStorage);

      const fakeToken =
          'header.eyJzdWIiOiIxMjMiLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20ifQ.signature';

      when(() => api.post(ApiConfig.login, data: any(named: 'data')))
          .thenAnswer((_) async => _ok<dynamic>({
                'accessToken': fakeToken,
                'refreshToken': fakeToken,
              }));
      when(() => tokenStorage.saveTokens(any(), any()))
          .thenAnswer((_) async => {});

      int signedInNotifications = 0;
      provider.addListener(() {
        if (provider.signedIn) {
          signedInNotifications++;
        }
      });

      await provider.login('test@example.com', 'password123');

      expect(provider.signedIn, isTrue);
      expect(signedInNotifications, equals(1));
    });
  });
}
