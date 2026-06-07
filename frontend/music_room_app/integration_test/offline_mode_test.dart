// Integration test driving the REAL PlaylistDetailPage through the offline
// stack: real PlaylistsProvider -> OfflineRoomRepository -> OfflineCache (Hive),
// with a simulated connectivity. The heavy SocketProvider / PlayerProvider are
// faked because the page only *reads* them (presence + playback), which are not
// part of the offline behaviour under test.
//
// Run: flutter test integration_test/offline_mode_test.dart
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:music_room_app/config/offline_cache.dart';
import 'package:music_room_app/core/repositories/offline_room_repository.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/services/connectivity_sync_manager.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/pages/playlists/pages/playlist_detail_page.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/socket_provider.dart';

class MockRemote extends Mock implements RoomRepository {}

class FakeSocketProvider extends Mock implements SocketProvider {}

class FakePlayerProvider extends Mock implements PlayerProvider {}

// * Toggleable connectivity: flip [online] to simulate going offline / back.
class FakeConnectivity implements Connectivity {
  bool online;
  FakeConnectivity({required this.online});

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      online ? [ConnectivityResult.wifi] : [ConnectivityResult.none];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Track _track(String id, String title) => Track(
  id: id,
  providerId: 'p-$id',
  title: title,
  artist: 'Artist $id',
  durationMs: 1000,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late Box<Map> roomsBox;
  late Box<Map> actionsBox;
  late OfflineCache cache;
  late FakeConnectivity connectivity;
  late MockRemote remote;
  late OfflineRoomRepository repo;
  late PlaylistsProvider playlistsProvider;

  setUpAll(() {
    registerFallbackValue(_track('fb', 'fb'));
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('offline_it');
    Hive.init(tmp.path);
    roomsBox = await Hive.openBox<Map>('it_rooms');
    actionsBox = await Hive.openBox<Map>('it_actions');
    cache = OfflineCache.test(roomsBox: roomsBox, actionsBox: actionsBox);

    connectivity = FakeConnectivity(online: false);
    remote = MockRemote();
    repo = OfflineRoomRepository(
      remoteRepository: remote,
      cache: cache,
      connectivity: connectivity,
    );
    playlistsProvider = PlaylistsProvider(repository: repo);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pumpDetailPage(WidgetTester tester, Room playlist) async {
    final socket = FakeSocketProvider();
    when(() => socket.isConnected).thenReturn(false);
    when(() => socket.joinRoom(any())).thenReturn(null);
    when(() => socket.leaveRoom(any())).thenReturn(null);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/detail',
          builder: (_, _) => const PlaylistDetailPage(),
        ),
        GoRoute(path: routePlayer, builder: (_, _) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaylistsProvider>.value(
            value: playlistsProvider,
          ),
          ChangeNotifierProvider<SocketProvider>.value(value: socket),
          ChangeNotifierProvider<PlayerProvider>.value(
            value: FakePlayerProvider(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );

    router.go('/detail', extra: {'playlist': playlist});
    await tester.pumpAndSettle();
  }

  testWidgets(
    'offline: deleting a playlist track updates the UI and queues it for sync',
    (tester) async {
      final playlist = Room(
        id: 'r1',
        name: 'Road Trip',
        ownerId: 'o1',
        kind: RoomKind.playlist,
        tracks: [_track('tA', 'Song A'), _track('tB', 'Song B')],
      );
      // * Seed the offline cache so fetchPlaylists() reads it after the delete.
      await cache.saveRoom(playlist);

      await pumpDetailPage(tester, playlist);

      // Both tracks render from the real page.
      expect(find.text('Song A'), findsOneWidget);
      expect(find.text('Song B'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsNWidgets(2));

      // Tap delete on the first track (Song A) while offline.
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      // Optimistic UI: Song A is gone immediately, Song B stays.
      expect(find.text('Song A'), findsNothing);
      expect(find.text('Song B'), findsOneWidget);

      // The deletion was queued offline (never hit the network).
      verifyNever(() => remote.removePlaylistTrack(any(), any()));
      final pending = cache.getPendingActions();
      expect(pending, hasLength(1));
      expect(pending.single.type, equals('removePlaylistTrack'));
      expect(pending.single.payload['trackId'], equals('tA'));

      // Reconnect -> the sync manager drains the queue to the real endpoint.
      connectivity.online = true;
      when(
        () => remote.removePlaylistTrack('r1', 'tA'),
      ).thenAnswer((_) async {});
      when(
        () => remote.getRooms(),
      ).thenAnswer((_) async => [playlist.copyWith(tracks: [_track('tB', 'Song B')])]);

      final syncManager = ConnectivitySyncManager(
        remoteRepository: remote,
        cache: cache,
      );
      await syncManager.syncQueue();

      verify(() => remote.removePlaylistTrack('r1', 'tA')).called(1);
      expect(cache.getPendingActions(), isEmpty);
    },
  );

  testWidgets(
    'offline: the playlist renders its tracks from the cache (no network)',
    (tester) async {
      final cachedPlaylist = Room(
        id: 'r2',
        name: 'Chill',
        ownerId: 'o1',
        kind: RoomKind.playlist,
        tracks: [_track('t1', 'Cached Track')],
      );
      await cache.saveRoom(cachedPlaylist);

      // Load from cache (offline) before showing the page.
      await playlistsProvider.fetchPlaylists();

      // Mount with an EMPTY extra playlist: the page must show the cached one.
      final emptyShell = Room(
        id: 'r2',
        name: 'Chill',
        ownerId: 'o1',
        kind: RoomKind.playlist,
      );
      await pumpDetailPage(tester, emptyShell);

      expect(find.text('Cached Track'), findsOneWidget);
      verifyNever(() => remote.getPlaylistTracks(any()));
    },
  );
}
