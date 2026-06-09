import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/pages/events/pages/events_page.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  late EventsProvider provider;
  late MockRoomRepository repository;

  setUp(() {
    repository = MockRoomRepository();
    provider = EventsProvider(repository: repository);
  });

  testWidgets('EventsPage shows search bar and filters items correctly', (
    tester,
  ) async {
    final mockEvents = [
      Room(
        id: '1',
        name: 'Friday Rave',
        description: 'Electronic party session',
        ownerId: 'user1',
        kind: RoomKind.vote,
      ),
      Room(
        id: '2',
        name: 'Sunday Picnic',
        description: 'Chill lo-fi vibes',
        ownerId: 'user1',
        kind: RoomKind.vote,
      ),
    ];

    when(
      () => repository.getRooms(kind: RoomKind.vote),
    ).thenAnswer((_) async => mockEvents);
    when(() => repository.getVoteTracks(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EventsProvider>.value(
          value: provider,
          child: const EventsPage(),
        ),
      ),
    );

    // Fetch events
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('events_search_bar')), findsOneWidget);
    expect(find.text('Friday Rave'), findsOneWidget);
    expect(find.text('Sunday Picnic'), findsOneWidget);

    // Enter search text "rave"
    await tester.enterText(
      find.byKey(const Key('neumorphic_search_text_field')),
      'rave',
    );
    await tester.pumpAndSettle();

    // Verify "Sunday Picnic" is filtered out, but "Friday Rave" is visible
    expect(find.text('Sunday Picnic'), findsNothing);
    expect(find.text('Friday Rave'), findsOneWidget);

    // Enter non-matching search text
    await tester.enterText(
      find.byKey(const Key('neumorphic_search_text_field')),
      'Karaoke',
    );
    await tester.pumpAndSettle();

    expect(find.text('Friday Rave'), findsNothing);
    expect(find.text('Sunday Picnic'), findsNothing);
    expect(find.text('No results found'), findsOneWidget);
  });
}
