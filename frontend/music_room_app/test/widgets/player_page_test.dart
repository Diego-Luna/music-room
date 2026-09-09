import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/audio/audio_player_service.dart';
import 'package:music_room_app/core/repositories/device_repository.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/pages/player/pages/player_page.dart';
import 'package:music_room_app/pages/player/widgets/player_progress_bar.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockRoomsProvider extends Mock implements RoomsProvider {}

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockEventsProvider extends Mock implements EventsProvider {}

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
  Future<void> play(String url) async => calls.add('play:$url');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> setVolume(double volume) async => calls.add('volume:$volume');
  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inSeconds}');
  @override
  Future<void> dispose() async {
    await completedController.close();
  }

  void triggerCompleted() {
    completedController.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerProvider playerProvider;
  late MockAuthProvider mockAuthProvider;
  late MockRoomsProvider mockRoomsProvider;
  late MockDeviceRepository mockDeviceRepository;
  late MockEventsProvider mockEventsProvider;
  late FakeAudioPlayerService fakeAudio;

  final testTrack = Track(
    id: 'track-preview-1',
    providerId: 'spotify:track:1',
    title: 'Sunflower',
    artist: 'Post Malone, Swae Lee',
    durationMs: 180000,
    previewUrl: 'https://example.com/sunflower_preview.mp3',
  );

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockRoomsProvider = MockRoomsProvider();
    mockDeviceRepository = MockDeviceRepository();
    mockEventsProvider = MockEventsProvider();
    fakeAudio = FakeAudioPlayerService();

    final user = User(
      id: 'user-1',
      email: 'user1@test.com',
      displayName: 'Diego',
    );
    when(() => mockAuthProvider.user).thenReturn(user);
    when(() => mockRoomsProvider.currentActiveRoom).thenReturn(null);

    playerProvider = PlayerProvider(
      authProvider: mockAuthProvider,
      roomsProvider: mockRoomsProvider,
      deviceRepository: mockDeviceRepository,
      audioService: fakeAudio,
      getLocalDeviceId: () async => 'test-device',
    );
    addTearDown(() => playerProvider.pause());
  });

  Widget buildTestApp({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerProvider>.value(value: playerProvider),
        ChangeNotifierProvider<EventsProvider>.value(value: mockEventsProvider),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: child),
    );
  }

  group('PlayerProgressBar Tests', () {
    testWidgets(
      'renders 30-second fixed duration with initial 0:00 and -0:30',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            child: const Scaffold(
              body: Center(
                child: SizedBox(width: 300, child: PlayerProgressBar()),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('0:00'), findsOneWidget);
        expect(find.text('-0:30'), findsOneWidget);
      },
    );

    testWidgets('displays updated elapsed and remaining times on seek', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(
            body: Center(
              child: SizedBox(width: 300, child: PlayerProgressBar()),
            ),
          ),
        ),
      );
      await tester.pump();

      // Seek to 12 seconds
      await playerProvider.seek(const Duration(seconds: 12));
      await tester.pumpAndSettle();

      expect(find.text('0:12'), findsOneWidget);
      expect(find.text('-0:18'), findsOneWidget);
    });

    testWidgets('tapping progress bar seeks to calculated position', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(
            body: Center(
              child: SizedBox(width: 300, child: PlayerProgressBar()),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap in the middle of the 300px bar (150px = 50% = 15s)
      final sliderFinder = find.byKey(const Key('player_progress_bar_slider'));
      await tester.tap(sliderFinder);
      await tester.pumpAndSettle();

      expect(playerProvider.position.inSeconds, equals(15));
      expect(fakeAudio.calls, contains('seek:15'));
    });
  });

  group('PlayerPage Layout & Overflow Resilience Tests', () {
    testWidgets(
      'PlayerPage renders without RenderFlex overflow on small screen (320x568)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        playerProvider.playTrack(testTrack);

        await tester.pumpWidget(buildTestApp(child: const PlayerPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Should render Sunflower track info
        expect(find.text('Sunflower'), findsOneWidget);
        expect(find.text('Post Malone, Swae Lee'), findsOneWidget);

        // Must not have any RenderFlex overflow exceptions
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PlayerPage renders without RenderFlex overflow on compact screen (360x600)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        playerProvider.playTrack(testTrack);

        await tester.pumpWidget(buildTestApp(child: const PlayerPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Midi 3D Beatpad and button are completely removed from PlayerPage',
      (tester) async {
        playerProvider.playTrack(testTrack);

        await tester.pumpWidget(buildTestApp(child: const PlayerPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Grid view button for MPC is absent
        expect(find.byIcon(Icons.grid_view_rounded), findsNothing);
        expect(find.text('MPC BEATPAD'), findsNothing);
        expect(find.text('3D Interactive Beat Machine'), findsNothing);
      },
    );

    testWidgets('Playback controls toggle play/pause state', (tester) async {
      playerProvider.playTrack(testTrack);

      await tester.pumpWidget(buildTestApp(child: const PlayerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(playerProvider.isPlaying, isTrue);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Tap pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(playerProvider.isPlaying, isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('renders Image.network when track.artworkUrl is present', (
      tester,
    ) async {
      final trackWithArtwork = Track(
        id: 'track-preview-artwork',
        providerId: 'spotify:track:artwork',
        title: 'Sunflower',
        artist: 'Post Malone, Swae Lee',
        durationMs: 180000,
        previewUrl: 'https://example.com/sunflower_preview.mp3',
        artworkUrl: 'https://example.com/sunflower.jpg',
      );

      playerProvider.playTrack(trackWithArtwork);

      await tester.pumpWidget(buildTestApp(child: const PlayerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final imageFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url ==
                'https://example.com/sunflower.jpg',
      );
      expect(imageFinder, findsOneWidget);
    });
  });
}
