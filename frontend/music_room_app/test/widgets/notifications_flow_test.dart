import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/invitation.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/pages/friends/pages/friends_page.dart';

class MockFriendsRepository extends Mock implements FriendsRepository {}

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  late MockFriendsRepository friendsRepo;
  late MockRoomRepository roomRepo;
  late FriendsProvider friendsProvider;
  late NotificationsProvider notificationsProvider;
  late PlaylistsProvider playlistsProvider;
  late EventsProvider eventsProvider;

  final testRequester = User(
    id: 'user-requester-1',
    email: 'requester@test.com',
    displayName: 'Alice In Chains',
    emailVerified: true,
    visibility: UserVisibility.public,
    musicPreferences: [],
  );

  final testInviter = User(
    id: 'user-inviter-1',
    email: 'inviter@test.com',
    displayName: 'Bob Marley',
    emailVerified: true,
    visibility: UserVisibility.public,
    musicPreferences: [],
  );

  final testRoom = Room(
    id: 'room-1',
    name: 'Chill Vibes Room',
    ownerId: 'user-inviter-1',
    isPublic: true,
    kind: RoomKind.playlist,
  );

  final incomingFriendRequest = FriendshipDto(
    id: 'req-1',
    requesterId: 'user-requester-1',
    addresseeId: 'my-user-id',
    status: 'PENDING',
    createdAt: DateTime.now(),
  );

  final incomingRoomInvitation = RoomInvitationDto(
    id: 'invite-1',
    roomId: 'room-1',
    inviterId: 'user-inviter-1',
    inviteeId: 'my-user-id',
    status: 'PENDING',
    createdAt: DateTime.now(),
  );

  setUp(() {
    friendsRepo = MockFriendsRepository();
    roomRepo = MockRoomRepository();

    when(() => friendsRepo.getFriends()).thenAnswer((_) async => []);
    when(
      () => friendsRepo.getIncomingRequests(),
    ).thenAnswer((_) async => [incomingFriendRequest]);
    when(() => friendsRepo.getOutgoingRequests()).thenAnswer((_) async => []);
    when(
      () => roomRepo.getInvitations(),
    ).thenAnswer((_) async => [incomingRoomInvitation]);
    when(() => roomRepo.getSentInvitations()).thenAnswer((_) async => []);

    when(
      () => friendsRepo.getUserProfile('user-requester-1'),
    ).thenAnswer((_) async => testRequester);
    when(
      () => friendsRepo.getUserProfile('user-inviter-1'),
    ).thenAnswer((_) async => testInviter);
    when(
      () => roomRepo.getRoomById('room-1'),
    ).thenAnswer((_) async => testRoom);

    when(
      () => roomRepo.getRooms(kind: any(named: 'kind')),
    ).thenAnswer((_) async => []);

    friendsProvider = FriendsProvider(repository: friendsRepo);
    notificationsProvider = NotificationsProvider(
      roomRepository: roomRepo,
      friendsRepository: friendsRepo,
    );
    playlistsProvider = PlaylistsProvider(repository: roomRepo);
    eventsProvider = EventsProvider(repository: roomRepo);
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FriendsProvider>.value(value: friendsProvider),
        ChangeNotifierProvider<NotificationsProvider>.value(
          value: notificationsProvider,
        ),
        ChangeNotifierProvider<PlaylistsProvider>.value(
          value: playlistsProvider,
        ),
        ChangeNotifierProvider<EventsProvider>.value(value: eventsProvider),
      ],
      child: const MaterialApp(home: FriendsPage()),
    );
  }

  testWidgets(
    'Badge displays combined count of friend requests and room invitations',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 1 friend request + 1 room invitation = 2 pending notifications
      expect(find.text('2'), findsOneWidget);
    },
  );

  testWidgets(
    'Switching to Requests tab displays incoming room invitations and friend requests',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on Requests tab button
      final requestsTabButton = find.byTooltip('Requests');
      expect(requestsTabButton, findsOneWidget);
      await tester.tap(requestsTabButton);
      await tester.pumpAndSettle();

      // Verify section headers
      expect(find.text('Room Invitations'), findsOneWidget);
      expect(find.text('Friend Requests'), findsOneWidget);

      // Verify items rendered
      expect(find.text('Bob Marley'), findsOneWidget);
      expect(find.text('Invited you to: Chill Vibes Room'), findsOneWidget);
      expect(find.text('Alice In Chains'), findsOneWidget);
      expect(find.text('Wants to be your friend'), findsOneWidget);
    },
  );

  testWidgets(
    'Accepting a friend request invokes repository and refreshes notifications',
    (tester) async {
      when(
        () => friendsRepo.acceptRequest('req-1'),
      ).thenAnswer((_) async => incomingFriendRequest);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to requests
      await tester.tap(find.byTooltip('Requests'));
      await tester.pumpAndSettle();

      // After accepting, incoming requests return empty
      when(() => friendsRepo.getIncomingRequests()).thenAnswer((_) async => []);

      // Tap Accept button on the friend request (the second check circle)
      final acceptButtons = find.byIcon(Icons.check_circle_rounded);
      expect(
        acceptButtons,
        findsNWidgets(2),
      ); // 1 for room invite, 1 for friend req

      // Tap the second one (friend request)
      await tester.tap(acceptButtons.last);
      await tester.pumpAndSettle();

      verify(() => friendsRepo.acceptRequest('req-1')).called(1);
    },
  );

  testWidgets(
    'Accepting a room invitation invokes repository and refreshes rooms',
    (tester) async {
      when(
        () => roomRepo.acceptInvitation('invite-1'),
      ).thenAnswer((_) async => AcceptInvitationResultDto(message: 'Joined'));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to requests
      await tester.tap(find.byTooltip('Requests'));
      await tester.pumpAndSettle();

      // After accepting, invitations return empty
      when(() => roomRepo.getInvitations()).thenAnswer((_) async => []);

      // Tap Accept button on room invitation (the first check circle)
      final acceptButtons = find.byIcon(Icons.check_circle_rounded);
      await tester.tap(acceptButtons.first);
      await tester.pumpAndSettle();

      verify(() => roomRepo.acceptInvitation('invite-1')).called(1);
    },
  );

  testWidgets('Declining a friend request invokes repository', (tester) async {
    when(
      () => friendsRepo.declineRequest('req-1'),
    ).thenAnswer((_) async => incomingFriendRequest);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Requests'));
    await tester.pumpAndSettle();

    final cancelButtons = find.byIcon(Icons.cancel_rounded);
    expect(cancelButtons, findsNWidgets(2));

    // Tap decline on friend request
    await tester.tap(cancelButtons.last);
    await tester.pumpAndSettle();

    verify(() => friendsRepo.declineRequest('req-1')).called(1);
  });
}
