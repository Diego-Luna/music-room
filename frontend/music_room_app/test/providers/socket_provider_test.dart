import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/core/globals.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/providers/socket_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockEventsProvider extends Mock implements EventsProvider {}

class MockPlaylistsProvider extends Mock implements PlaylistsProvider {}

class MockRoomsProvider extends Mock implements RoomsProvider {}

class MockPlayerProvider extends Mock implements PlayerProvider {}

class MockFriendsProvider extends Mock implements FriendsProvider {}

class MockNotificationsProvider extends Mock implements NotificationsProvider {}

class MockSocket extends Mock implements io.Socket {}

void main() {
  late MockAuthProvider auth;
  late MockEventsProvider events;
  late MockPlaylistsProvider playlists;
  late MockRoomsProvider rooms;
  late MockPlayerProvider player;
  late MockFriendsProvider friends;
  late MockNotificationsProvider notifications;
  late MockSocket socket;
  late Map<String, Function> socketListeners;

  setUp(() {
    auth = MockAuthProvider();
    events = MockEventsProvider();
    playlists = MockPlaylistsProvider();
    rooms = MockRoomsProvider();
    player = MockPlayerProvider();
    friends = MockFriendsProvider();
    notifications = MockNotificationsProvider();
    socket = MockSocket();
    socketListeners = {};

    when(() => auth.signedIn).thenReturn(false);
    when(() => socket.on(any(), any())).thenAnswer((invocation) {
      final event = invocation.positionalArguments[0] as String;
      final callback = invocation.positionalArguments[1] as Function;
      socketListeners[event] = callback;
      return () => null;
    });
  });

  test('SocketProvider registers listener on AuthProvider', () {
    final socketProvider = SocketProvider(
      authProvider: auth,
      eventsProvider: events,
      playlistsProvider: playlists,
      roomsProvider: rooms,
      playerProvider: player,
      friendsProvider: friends,
      notificationsProvider: notifications,
    );

    verify(() => auth.addListener(any())).called(1);
    expect(socketProvider.isConnected, isFalse);
  });

  group('Room Presence Controls', () {
    test('joinRoom emits room:join when connected', () {
      when(() => socket.connected).thenReturn(true);

      final provider = SocketProvider(
        authProvider: auth,
        eventsProvider: events,
        playlistsProvider: playlists,
        roomsProvider: rooms,
        playerProvider: player,
        friendsProvider: friends,
        notificationsProvider: notifications,
        socket: socket,
      );

      provider.joinRoom('room_123');

      verify(() => socket.emit('room:join', {'roomId': 'room_123'})).called(1);
    });

    test('joinRoom does not emit room:join when disconnected', () {
      when(() => socket.connected).thenReturn(false);

      final provider = SocketProvider(
        authProvider: auth,
        eventsProvider: events,
        playlistsProvider: playlists,
        roomsProvider: rooms,
        playerProvider: player,
        friendsProvider: friends,
        notificationsProvider: notifications,
        socket: socket,
      );

      provider.joinRoom('room_123');

      verifyNever(() => socket.emit('room:join', any()));
    });

    test('leaveRoom emits room:leave when connected', () {
      when(() => socket.connected).thenReturn(true);

      final provider = SocketProvider(
        authProvider: auth,
        eventsProvider: events,
        playlistsProvider: playlists,
        roomsProvider: rooms,
        playerProvider: player,
        friendsProvider: friends,
        notificationsProvider: notifications,
        socket: socket,
      );

      provider.leaveRoom('room_123');

      verify(() => socket.emit('room:leave', {'roomId': 'room_123'})).called(1);
    });

    test('leaveRoom does not emit room:leave when disconnected', () {
      when(() => socket.connected).thenReturn(false);

      final provider = SocketProvider(
        authProvider: auth,
        eventsProvider: events,
        playlistsProvider: playlists,
        roomsProvider: rooms,
        playerProvider: player,
        friendsProvider: friends,
        notificationsProvider: notifications,
        socket: socket,
      );

      provider.leaveRoom('room_123');

      verifyNever(() => socket.emit('room:leave', any()));
    });
  });

  group('Playback Socket Events', () {
    test(
      'playback:command event calls playerProvider.handlePlaybackCommand',
      () {
        SocketProvider(
          authProvider: auth,
          eventsProvider: events,
          playlistsProvider: playlists,
          roomsProvider: rooms,
          playerProvider: player,
          friendsProvider: friends,
          notificationsProvider: notifications,
          socket: socket,
        );

        expect(socketListeners.containsKey('playback:command'), isTrue);

        final commandData = {'action': 'play', 'trackUri': 'http://test.mp3'};
        socketListeners['playback:command']?.call(commandData);

        verify(() => player.handlePlaybackCommand(commandData)).called(1);
      },
    );
  });

  group('Membership & delegation realtime events', () {
    SocketProvider build() => SocketProvider(
      authProvider: auth,
      eventsProvider: events,
      playlistsProvider: playlists,
      roomsProvider: rooms,
      playerProvider: player,
      friendsProvider: friends,
      notificationsProvider: notifications,
      socket: socket,
    );

    test(
      'member:removed routes to roomsProvider and notifies the members stream',
      () {
        final provider = build();
        expect(socketListeners.containsKey('member:removed'), isTrue);

        expectLater(provider.roomMembersChanged, emits('room_1'));
        socketListeners['member:removed']?.call({
          'roomId': 'room_1',
          'userId': 'u9',
        });

        verify(() => rooms.handleMemberLeft('room_1', 'u9')).called(1);
      },
    );

    test('member:role-changed notifies the members stream', () {
      final provider = build();
      expect(socketListeners.containsKey('member:role-changed'), isTrue);

      expectLater(provider.roomMembersChanged, emits('room_1'));
      socketListeners['member:role-changed']?.call({
        'roomId': 'room_1',
        'userId': 'u9',
        'role': 'ADMIN',
      });
    });

    test(
      'device:delegation:revoked calls playerProvider.handleDelegationRevoked',
      () {
        build();
        expect(
          socketListeners.containsKey('device:delegation:revoked'),
          isTrue,
        );

        socketListeners['device:delegation:revoked']?.call({
          'deviceId': 'dev_1',
          'ownerId': 'owner_1',
        });

        verify(
          () => player.handleDelegationRevoked('dev_1', 'owner_1'),
        ).called(1);
      },
    );

    test('room:kicked refreshes both room lists and the inbox', () {
      when(() => playlists.fetchPlaylists()).thenAnswer((_) async {});
      when(() => events.fetchEvents()).thenAnswer((_) async {});
      when(() => notifications.fetchNotifications()).thenAnswer((_) async {});

      build();
      expect(socketListeners.containsKey('room:kicked'), isTrue);

      // Not currently inside the room → no navigation, just refreshes.
      socketListeners['room:kicked']?.call({
        'roomId': 'room_1',
        'roomName': 'Gone',
      });

      verify(() => playlists.fetchPlaylists()).called(1);
      verify(() => events.fetchEvents()).called(1);
      verify(() => notifications.fetchNotifications()).called(1);
    });
  });

  group('Realtime Notification Events', () {
    testWidgets(
      'friend:request:new event shows snackbar when scaffold messenger is in tree',
      (WidgetTester tester) async {
        final auth = MockAuthProvider();
        final events = MockEventsProvider();
        final playlists = MockPlaylistsProvider();
        final rooms = MockRoomsProvider();
        final player = MockPlayerProvider();
        final friends = MockFriendsProvider();
        final notifications = MockNotificationsProvider();
        final socket = MockSocket();
        final socketListeners = <String, Function>{};

        when(() => auth.signedIn).thenReturn(false);
        when(() => socket.on(any(), any())).thenAnswer((invocation) {
          final event = invocation.positionalArguments[0] as String;
          final callback = invocation.positionalArguments[1] as Function;
          socketListeners[event] = callback;
          return () => null;
        });
        when(() => notifications.fetchNotifications()).thenAnswer((_) async {});

        SocketProvider(
          authProvider: auth,
          eventsProvider: events,
          playlistsProvider: playlists,
          roomsProvider: rooms,
          playerProvider: player,
          friendsProvider: friends,
          notificationsProvider: notifications,
          socket: socket,
        );

        await tester.pumpWidget(
          MaterialApp(
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            home: const Scaffold(body: SizedBox()),
          ),
        );

        expect(socketListeners.containsKey('friend:request:new'), isTrue);

        socketListeners['friend:request:new']?.call(null);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('New friend request received!'), findsOneWidget);
      },
    );

    testWidgets('friend:request:accepted event shows snackbar', (
      WidgetTester tester,
    ) async {
      final auth = MockAuthProvider();
      final events = MockEventsProvider();
      final playlists = MockPlaylistsProvider();
      final rooms = MockRoomsProvider();
      final player = MockPlayerProvider();
      final friends = MockFriendsProvider();
      final notifications = MockNotificationsProvider();
      final socket = MockSocket();
      final socketListeners = <String, Function>{};

      when(() => auth.signedIn).thenReturn(false);
      when(() => socket.on(any(), any())).thenAnswer((invocation) {
        final event = invocation.positionalArguments[0] as String;
        final callback = invocation.positionalArguments[1] as Function;
        socketListeners[event] = callback;
        return () => null;
      });
      when(() => notifications.fetchNotifications()).thenAnswer((_) async {});
      when(() => friends.fetchFriendsData()).thenAnswer((_) async {});

      SocketProvider(
        authProvider: auth,
        eventsProvider: events,
        playlistsProvider: playlists,
        roomsProvider: rooms,
        playerProvider: player,
        friendsProvider: friends,
        notificationsProvider: notifications,
        socket: socket,
      );

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );

      expect(socketListeners.containsKey('friend:request:accepted'), isTrue);

      socketListeners['friend:request:accepted']?.call(null);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Friend request accepted!'), findsOneWidget);
    });

    testWidgets(
      'invitation:new event shows snackbar with roomName if provided',
      (WidgetTester tester) async {
        final auth = MockAuthProvider();
        final events = MockEventsProvider();
        final playlists = MockPlaylistsProvider();
        final rooms = MockRoomsProvider();
        final player = MockPlayerProvider();
        final friends = MockFriendsProvider();
        final notifications = MockNotificationsProvider();
        final socket = MockSocket();
        final socketListeners = <String, Function>{};

        when(() => auth.signedIn).thenReturn(false);
        when(() => socket.on(any(), any())).thenAnswer((invocation) {
          final event = invocation.positionalArguments[0] as String;
          final callback = invocation.positionalArguments[1] as Function;
          socketListeners[event] = callback;
          return () => null;
        });
        when(() => notifications.fetchNotifications()).thenAnswer((_) async {});

        SocketProvider(
          authProvider: auth,
          eventsProvider: events,
          playlistsProvider: playlists,
          roomsProvider: rooms,
          playerProvider: player,
          friendsProvider: friends,
          notificationsProvider: notifications,
          socket: socket,
        );

        await tester.pumpWidget(
          MaterialApp(
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            home: const Scaffold(body: SizedBox()),
          ),
        );

        expect(socketListeners.containsKey('invitation:new'), isTrue);

        socketListeners['invitation:new']?.call({'roomName': 'My Cool Room'});
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('New room invitation received to join My Cool Room!'),
          findsOneWidget,
        );
      },
    );
  });
}
