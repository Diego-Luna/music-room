import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/pages/playlists/pages/playlists_page.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  late PlaylistsProvider provider;
  late MockRoomRepository repository;

  setUp(() {
    repository = MockRoomRepository();
    provider = PlaylistsProvider(repository: repository);
  });

  testWidgets('PlaylistsPage shows search bar and filters items correctly', (
    tester,
  ) async {
    final mockPlaylists = [
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

    when(
      () => repository.getRooms(kind: RoomKind.playlist),
    ).thenAnswer((_) async => mockPlaylists);
    when(() => repository.getPlaylistTracks(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<PlaylistsProvider>.value(
          value: provider,
          child: const PlaylistsPage(),
        ),
      ),
    );

    // Fetch playlists
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('playlists_search_bar')), findsOneWidget);
    expect(find.text('Rock Classics'), findsOneWidget);
    expect(find.text('Jazz Beats'), findsOneWidget);

    // Enter search text "jazz"
    await tester.enterText(
      find.byKey(const Key('neumorphic_search_text_field')),
      'jazz',
    );
    await tester.pumpAndSettle();

    // Verify "Rock Classics" is filtered out, but "Jazz Beats" is visible
    expect(find.text('Rock Classics'), findsNothing);
    expect(find.text('Jazz Beats'), findsOneWidget);

    // Enter non-matching search text
    await tester.enterText(
      find.byKey(const Key('neumorphic_search_text_field')),
      'Pop',
    );
    await tester.pumpAndSettle();

    expect(find.text('Rock Classics'), findsNothing);
    expect(find.text('Jazz Beats'), findsNothing);
    expect(find.text('No results found'), findsOneWidget);
  });
}
