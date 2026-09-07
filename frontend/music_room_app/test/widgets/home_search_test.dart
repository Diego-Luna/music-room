import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/pages/home/pages/home_page.dart';
import 'package:music_room_app/pages/home/widgets/home_search_results.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

class MockPlaylistsProvider extends Mock implements PlaylistsProvider {}

class MockEventsProvider extends Mock implements EventsProvider {}

class MockPlayerProvider extends Mock implements PlayerProvider {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      Track(
        id: 'fallback',
        providerId: 'fallback',
        title: 'fallback',
        artist: 'fallback',
        durationMs: 30000,
      ),
    );
  });

  group('HomeSearchResults Widget Tests', () {
    testWidgets('renders loading state when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSearchResults(
              query: 'rock',
              tracks: const [],
              isLoading: true,
              onTrackTap: (track, index) {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders error message when errorMessage is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSearchResults(
              query: 'rock',
              tracks: const [],
              isLoading: false,
              errorMessage: 'Search failed. Make sure you are online.',
              onTrackTap: (track, index) {},
            ),
          ),
        ),
      );

      expect(
        find.text('Search failed. Make sure you are online.'),
        findsOneWidget,
      );
    });

    testWidgets('renders empty prompt when tracks are empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSearchResults(
              query: 'unknown-song-xyz',
              tracks: const [],
              isLoading: false,
              onTrackTap: (track, index) {},
            ),
          ),
        ),
      );

      expect(
        find.text('No songs found for "unknown-song-xyz"'),
        findsOneWidget,
      );
    });

    testWidgets('renders track items and triggers onTrackTap when tapped', (
      tester,
    ) async {
      final testTracks = [
        Track(
          id: 'track-1',
          providerId: 'deezer-1',
          title: 'Get Lucky',
          artist: 'Daft Punk',
          durationMs: 248000,
        ),
      ];

      Track? tappedTrack;
      int? tappedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSearchResults(
              query: 'Daft',
              tracks: testTracks,
              isLoading: false,
              onTrackTap: (track, index) {
                tappedTrack = track;
                tappedIndex = index;
              },
            ),
          ),
        ),
      );

      expect(find.text('Get Lucky'), findsOneWidget);
      expect(find.text('Daft Punk • 4:08'), findsOneWidget);

      await tester.tap(find.text('Get Lucky'));
      await tester.pump();

      expect(tappedTrack?.id, equals('track-1'));
      expect(tappedIndex, equals(0));
    });
  });

  group('HomePage Search Integration Tests', () {
    late MockRoomRepository mockRepo;
    late MockPlaylistsProvider mockPlaylists;
    late MockEventsProvider mockEvents;
    late MockPlayerProvider mockPlayer;

    setUp(() {
      mockRepo = MockRoomRepository();
      mockPlaylists = MockPlaylistsProvider();
      mockEvents = MockEventsProvider();
      mockPlayer = MockPlayerProvider();

      when(() => mockPlaylists.playlists).thenReturn([]);
      when(() => mockPlaylists.fetchPlaylists()).thenAnswer((_) async {});
      when(() => mockEvents.events).thenReturn([]);
      when(() => mockEvents.fetchEvents()).thenAnswer((_) async {});
    });

    testWidgets(
      'typing query in search bar searches tracks and displays results',
      (tester) async {
        final searchResults = [
          Track(
            id: 'deezer-101',
            providerId: '101',
            title: 'One More Time',
            artist: 'Daft Punk',
            durationMs: 320000,
          ),
        ];

        when(
          () => mockRepo.searchTracks('Daft'),
        ).thenAnswer((_) async => searchResults);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PlaylistsProvider>.value(
                value: mockPlaylists,
              ),
              ChangeNotifierProvider<EventsProvider>.value(value: mockEvents),
              ChangeNotifierProvider<PlayerProvider>.value(value: mockPlayer),
            ],
            child: MaterialApp(home: HomePage(repository: mockRepo)),
          ),
        );

        await tester.pump();

        // Verify search bar is visible
        final searchField = find.byKey(
          const Key('neumorphic_search_text_field'),
        );
        expect(searchField, findsOneWidget);

        // Enter text into search field
        await tester.enterText(searchField, 'Daft');
        await tester.pump();

        // Wait for debounce timer (350ms) to fire and future to complete
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        verify(() => mockRepo.searchTracks('Daft')).called(1);
        expect(find.text('One More Time'), findsOneWidget);
        expect(find.text('Daft Punk • 5:20'), findsOneWidget);
      },
    );

    testWidgets('tapping a search result plays track and navigates to player', (
      tester,
    ) async {
      final searchResults = [
        Track(
          id: 'deezer-101',
          providerId: '101',
          title: 'One More Time',
          artist: 'Daft Punk',
          durationMs: 320000,
        ),
      ];

      when(
        () => mockRepo.searchTracks('Daft'),
      ).thenAnswer((_) async => searchResults);
      when(
        () => mockPlayer.playTrack(
          any(),
          queue: any(named: 'queue'),
          index: any(named: 'index'),
        ),
      ).thenReturn(null);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => HomePage(repository: mockRepo),
          ),
          GoRoute(
            path: '/player',
            builder: (context, state) =>
                const Scaffold(body: Text('Player Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PlaylistsProvider>.value(
              value: mockPlaylists,
            ),
            ChangeNotifierProvider<EventsProvider>.value(value: mockEvents),
            ChangeNotifierProvider<PlayerProvider>.value(value: mockPlayer),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump();

      final searchField = find.byKey(const Key('neumorphic_search_text_field'));
      await tester.enterText(searchField, 'Daft');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('One More Time'), findsOneWidget);

      await tester.tap(find.text('One More Time'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(
        () => mockPlayer.playTrack(
          any(that: predicate<Track>((t) => t.id == 'deezer-101')),
          queue: any(named: 'queue'),
          index: 0,
        ),
      ).called(1);

      expect(find.text('Player Screen'), findsOneWidget);
    });

    testWidgets('clearing search field restores default home view', (
      tester,
    ) async {
      when(() => mockRepo.searchTracks('Daft')).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PlaylistsProvider>.value(
              value: mockPlaylists,
            ),
            ChangeNotifierProvider<EventsProvider>.value(value: mockEvents),
            ChangeNotifierProvider<PlayerProvider>.value(value: mockPlayer),
          ],
          child: MaterialApp(home: HomePage(repository: mockRepo)),
        ),
      );

      await tester.pump();

      final searchField = find.byKey(const Key('neumorphic_search_text_field'));
      await tester.enterText(searchField, 'Daft');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('No songs found for "Daft"'), findsOneWidget);

      // Clear the search field
      await tester.enterText(searchField, '');
      await tester.pump();

      expect(find.text('No songs found for "Daft"'), findsNothing);
    });
  });
}
