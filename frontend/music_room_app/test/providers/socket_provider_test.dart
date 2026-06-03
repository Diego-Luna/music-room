import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/socket_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockEventsProvider extends Mock implements EventsProvider {}

class MockPlaylistsProvider extends Mock implements PlaylistsProvider {}

class MockRoomsProvider extends Mock implements RoomsProvider {}

class MockPlayerProvider extends Mock implements PlayerProvider {}

class MockSocket extends Mock implements IO.Socket {}

void main() {
  test('SocketProvider registers listener on AuthProvider', () {
    final auth = MockAuthProvider();
    final events = MockEventsProvider();
    final playlists = MockPlaylistsProvider();
    final rooms = MockRoomsProvider();
    final player = MockPlayerProvider();

    when(() => auth.signedIn).thenReturn(false);

    final socketProvider = SocketProvider(
      authProvider: auth,
      eventsProvider: events,
      playlistsProvider: playlists,
      roomsProvider: rooms,
      playerProvider: player,
    );

    verify(() => auth.addListener(any())).called(1);
    expect(socketProvider.isConnected, isFalse);
  });

  group('Room Presence Controls', () {
    late MockAuthProvider auth;
    late MockEventsProvider events;
    late MockPlaylistsProvider playlists;
    late MockRoomsProvider rooms;
    late MockPlayerProvider player;
    late MockSocket socket;

    setUp(() {
      auth = MockAuthProvider();
      events = MockEventsProvider();
      playlists = MockPlaylistsProvider();
      rooms = MockRoomsProvider();
      player = MockPlayerProvider();
      socket = MockSocket();

      when(() => auth.signedIn).thenReturn(false);
      when(() => socket.on(any(), any())).thenReturn(() => null);
    });

    test('joinRoom emits room:join when connected', () {
      when(() => socket.connected).thenReturn(true);

      final provider = SocketProvider(
        authProvider: auth,
        eventsProvider: events,
        playlistsProvider: playlists,
        roomsProvider: rooms,
        playerProvider: player,
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
        socket: socket,
      );

      provider.leaveRoom('room_123');

      verifyNever(() => socket.emit('room:leave', any()));
    });
  });
}
