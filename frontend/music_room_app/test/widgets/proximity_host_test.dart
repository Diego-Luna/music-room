import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/config/location_config.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/widgets/proximity_host.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  final venue = Room(
    id: 'paris',
    name: 'Paris Party',
    ownerId: 'u1',
    kind: RoomKind.vote,
    isPublic: true,
    description: 'Electronic night',
    voteLocationLat: 48.8566,
    voteLocationLng: 2.3522,
    voteLocationRadiusM: 500,
  );

  setUp(LocationConfig.resetForTest);
  tearDown(LocationConfig.resetForTest);

  testWidgets(
    'entering a public event zone opens the approach sheet from the app builder',
    (tester) async {
      final repository = MockRoomRepository();
      when(
        () => repository.getRooms(kind: RoomKind.vote),
      ).thenAnswer((_) async => [venue]);
      when(() => repository.getVoteTracks(any())).thenAnswer((_) async => []);
      final events = EventsProvider(repository: repository);
      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => ProximityHost(
            events: events,
            navigatorKey: navigatorKey,
            child: child!,
          ),
        ),
      );

      LocationConfig.setForTest(lat: 48.8566, lng: 2.3522);
      await events.fetchEvents();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nearby event'), findsOneWidget);
      expect(find.text('Paris Party'), findsOneWidget);
    },
  );
}
