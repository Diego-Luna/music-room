import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
}
