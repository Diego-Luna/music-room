import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/audio/audio_player_service.dart';
import 'package:music_room_app/core/repositories/device_repository.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/widgets/mini_player.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockRoomsProvider extends Mock implements RoomsProvider {}

class MockDeviceRepository extends Mock implements DeviceRepository {}

class FakeAudioPlayerService implements AudioPlayerService {
  final List<String> calls = [];
  final StreamController<void> completedController =
      StreamController<void>.broadcast();

  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<void> get completedStream => completedController.stream;
  @override
  Future<void> play(
    String url, {
    Duration position = Duration.zero,
    bool autoplay = true,
  }) async => calls.add('play:$url');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inMilliseconds}');
  @override
  Future<void> dispose() async => completedController.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerProvider player;
  late FakeAudioPlayerService audio;

  final first = Track(
    id: 't-1',
    providerId: 'p1',
    title: 'Sunflower',
    artist: 'Post Malone',
    durationMs: 30000,
    previewUrl: 'https://example.com/1.mp3',
  );
  final second = Track(
    id: 't-2',
    providerId: 'p2',
    title: 'Circles',
    artist: 'Post Malone',
    durationMs: 30000,
    previewUrl: 'https://example.com/2.mp3',
  );

  setUp(() {
    audio = FakeAudioPlayerService();
    final auth = MockAuthProvider();
    final rooms = MockRoomsProvider();
    when(
      () => auth.user,
    ).thenReturn(User(id: 'u', email: 'u@test.com', displayName: 'User'));
    when(() => rooms.currentActiveRoom).thenReturn(null);
    player = PlayerProvider(
      authProvider: auth,
      roomsProvider: rooms,
      deviceRepository: MockDeviceRepository(),
      audioService: audio,
      getLocalDeviceId: () async => 'device',
    );
    addTearDown(player.dispose);
  });

  Future<void> pumpBar(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: MiniPlayer()),
        ),
        GoRoute(
          path: routePlayer,
          builder: (_, _) => const Scaffold(body: Text('Full player')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerProvider>.value(
        value: player,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('stays hidden until a track is playing', (tester) async {
    await pumpBar(tester);
    expect(find.byKey(const Key('mini_player')), findsNothing);

    player.playTrack(first, queue: [first, second], index: 0);
    await tester.pump();

    expect(find.byKey(const Key('mini_player')), findsOneWidget);
    expect(find.text('Sunflower'), findsOneWidget);
    expect(find.text('Post Malone'), findsOneWidget);
  });

  testWidgets('pause, play, next and open the full player', (tester) async {
    await pumpBar(tester);
    player.playTrack(first, queue: [first, second], index: 0);
    await tester.pump();

    await tester.tap(find.byKey(const Key('mini_player_play')));
    await tester.pump();
    expect(player.isPlaying, isFalse);
    expect(audio.calls, contains('pause'));

    await tester.tap(find.byKey(const Key('mini_player_play')));
    await tester.pump();
    expect(player.isPlaying, isTrue);

    await tester.tap(find.byKey(const Key('mini_player_previous')));
    await tester.pump();
    expect(player.currentTrack?.id, 't-1');
    expect(player.position, Duration.zero);
    expect(audio.calls, contains('seek:0'));

    await tester.tap(find.byKey(const Key('mini_player_next')));
    await tester.pump();
    expect(player.currentTrack?.id, 't-2');

    await tester.tap(find.byKey(const Key('mini_player_open')));
    await tester.pumpAndSettle();
    expect(find.text('Full player'), findsOneWidget);
  });

  testWidgets('left arrow restarts after 3s and skips back before that', (
    tester,
  ) async {
    await pumpBar(tester);
    player.playTrack(second, queue: [first, second], index: 1);
    await tester.pump();

    await tester.tap(find.byKey(const Key('mini_player_previous')));
    await tester.pump();
    expect(player.currentTrack?.id, 't-1');

    player.playTrack(second, queue: [first, second], index: 1);
    await tester.pump();
    await player.seek(const Duration(seconds: 3));
    await tester.pump();

    await tester.tap(find.byKey(const Key('mini_player_previous')));
    await tester.pump();
    expect(player.currentTrack?.id, 't-2');
    expect(player.position, Duration.zero);
  });

  testWidgets('does not overflow at phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpBar(tester);
    player.playTrack(first);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Sunflower'), findsOneWidget);
  });
}
