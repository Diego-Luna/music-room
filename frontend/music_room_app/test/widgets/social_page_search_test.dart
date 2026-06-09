import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/pages/social/pages/social_page.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

// * Test data factories
List<Room> _mockPlaylists() => [
  Room(
    id: '1',
    name: 'Rock Classics',
    description: 'Old school anthems',
    ownerId: 'user1',
    kind: RoomKind.playlist,
  ),
  Room(
    id: '2',
    name: 'Jazz Beats',
    description: 'Smooth instrumental tunes',
    ownerId: 'user1',
    kind: RoomKind.playlist,
  ),
];

List<Room> _mockEvents() => [
  Room(
    id: '3',
    name: 'Friday Rave',
    description: 'Electronic party session',
    ownerId: 'user1',
    kind: RoomKind.vote,
  ),
  Room(
    id: '4',
    name: 'Sunday Picnic',
    description: 'Chill lo-fi vibes',
    ownerId: 'user1',
    kind: RoomKind.vote,
  ),
];

// * Stubs the repository with mock playlists and events
void _stubRepository(MockRoomRepository repository) {
  when(
    () => repository.getRooms(kind: RoomKind.playlist),
  ).thenAnswer((_) async => _mockPlaylists());
  when(
    () => repository.getRooms(kind: RoomKind.vote),
  ).thenAnswer((_) async => _mockEvents());
  when(() => repository.getPlaylistTracks(any())).thenAnswer((_) async => []);
  when(() => repository.getVoteTracks(any())).thenAnswer((_) async => []);
}

// * Builds the widget tree for SocialPage with mocked providers
Future<void> _pumpSocialPage(
  WidgetTester tester,
  PlaylistsProvider playlistsProvider,
  EventsProvider eventsProvider,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaylistsProvider>.value(
            value: playlistsProvider,
          ),
          ChangeNotifierProvider<EventsProvider>.value(value: eventsProvider),
        ],
        child: const SocialPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late PlaylistsProvider playlistsProvider;
  late EventsProvider eventsProvider;
  late MockRoomRepository repository;

  setUp(() {
    repository = MockRoomRepository();
    playlistsProvider = PlaylistsProvider(repository: repository);
    eventsProvider = EventsProvider(repository: repository);
  });

  testWidgets('SocialPage switches tabs and filters correctly', (tester) async {
    _stubRepository(repository);
    await _pumpSocialPage(tester, playlistsProvider, eventsProvider);

    // * Step 1: Assert Playlists are shown by default
    expect(find.byKey(const Key('social_search_bar')), findsOneWidget);
    expect(find.text('Rock Classics'), findsOneWidget);
    expect(find.text('Jazz Beats'), findsOneWidget);
    expect(find.text('Friday Rave'), findsNothing);

    // * Step 2: Perform search on Playlists
    await tester.enterText(
      find.byKey(const Key('neumorphic_search_text_field')),
      'jazz',
    );
    await tester.pumpAndSettle();
    expect(find.text('Rock Classics'), findsNothing);
    expect(find.text('Jazz Beats'), findsOneWidget);

    // * Step 3: Switch to Events tab
    await tester.tap(find.byKey(const Key('events_tab_button')));
    await tester.pumpAndSettle();

    // ! Search query should be cleared on tab switch
    expect(find.text('Friday Rave'), findsOneWidget);
    expect(find.text('Sunday Picnic'), findsOneWidget);
    expect(find.text('Jazz Beats'), findsNothing);

    // * Step 4: Perform search on Events
    await tester.enterText(
      find.byKey(const Key('neumorphic_search_text_field')),
      'rave',
    );
    await tester.pumpAndSettle();
    expect(find.text('Sunday Picnic'), findsNothing);
    expect(find.text('Friday Rave'), findsOneWidget);
  });
}
