import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/pages/friends/pages/friends_page.dart';
import 'package:mocktail/mocktail.dart';

class MockFriendsRepository extends Mock implements FriendsRepository {}

void main() {
  late FriendsProvider provider;
  late MockFriendsRepository repository;

  setUp(() {
    repository = MockFriendsRepository();
    provider = FriendsProvider(repository: repository);

    when(() => repository.getFriends()).thenAnswer((_) async => []);
    when(() => repository.getIncomingRequests()).thenAnswer((_) async => []);
    when(() => repository.getOutgoingRequests()).thenAnswer((_) async => []);
  });

  testWidgets('FriendsPage renders correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<FriendsProvider>.value(
          value: provider,
          child: const FriendsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Friends'), findsOneWidget);
    expect(find.byIcon(Icons.people_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
  });
}
