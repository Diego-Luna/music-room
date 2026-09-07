import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';
import 'package:music_room_app/pages/events/widgets/invite_friend_dialog.dart';
import 'package:music_room_app/widgets/track_search_sheet.dart';

class MockFriendsRepository extends Mock implements FriendsRepository {}

void main() {
  group('Design Overflow Resilience Tests', () {
    testWidgets(
      'PlaceholderCard handles ultra-long titles and subtitles without RenderFlex overflow on narrow screens',
      (tester) async {
        // Narrow screen: 320px width (iPhone SE 1st gen / ultra compact Android)
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const ultraLongTitle =
            'A very very very extremely long playlist or room title that would normally overflow any unconstrained text widget in a row';
        const ultraLongSubtitle =
            'Invited by Someone with an equally long and convoluted name to join this private room with many options and configurations';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: PlaceholderCard(
                  title: ultraLongTitle,
                  subtitle: ultraLongSubtitle,
                  leading: Icon(Icons.music_note),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // No exceptions thrown, widget is rendered
        expect(find.byType(PlaceholderCard), findsOneWidget);
        // Verify overflow didn't break Flutter rendering
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'InviteFriendDialog header wraps long room names without RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockFriendsRepo = MockFriendsRepository();
        when(() => mockFriendsRepo.getFriends()).thenAnswer((_) async => []);

        final friendsProvider = FriendsProvider(repository: mockFriendsRepo);

        final longNamedRoom = Room(
          id: 'room-long',
          name:
              'Super Extra Incredibly Gigantic Party Fest Room Name That Stretches Beyond Viewport Bounds',
          ownerId: 'user-1',
          isPublic: true,
          kind: RoomKind.vote,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<FriendsProvider>.value(
            value: friendsProvider,
            child: MaterialApp(
              home: Scaffold(body: InviteFriendDialog(room: longNamedRoom)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(InviteFriendDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'NeumorphicIconButton renders 1, 2, and 3+ digit badges gracefully without distortion or crash',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  NeumorphicIconButton(
                    icon: Icons.notifications,
                    badgeCount: 3,
                  ),
                  NeumorphicIconButton(
                    icon: Icons.notifications,
                    badgeCount: 42,
                  ),
                  NeumorphicIconButton(
                    icon: Icons.notifications,
                    badgeCount: 150,
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('3'), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
        expect(find.text('99+'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TrackSearchSheet header renders without overflow on narrow viewport',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TrackSearchSheet(
                title: 'Extremely Long Search Tracks Modal Sheet Header Title',
                onSelected: (track) async {},
                confirmationBuilder: (track) => 'Added',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(TrackSearchSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
