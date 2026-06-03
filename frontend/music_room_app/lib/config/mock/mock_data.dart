import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/user.dart';

class MockData {
  static final List<User> users = [
    User(
      id: 'user-1',
      email: 'diego@42.fr',
      displayName: 'Diego Luna',
      avatarUrl: 'https://i.pravatar.cc/150?u=user-1',
    ),
    User(
      id: 'user-2',
      email: 'jeremy@42.fr',
      displayName: 'Jeremy',
      avatarUrl: 'https://i.pravatar.cc/150?u=user-2',
    ),
    User(id: 'user-3', email: 'music@lover.com', displayName: 'Music Lover'),
  ];

  // * VOTE rooms
  static final Room voteRoom1 = Room(
    id: 'room-vote-1',
    name: 'Friday Night TACOS',
    ownerId: 'user-1',
    kind: RoomKind.vote,
    isPublic: true,
    tracks: [
      Track(
        id: 'track-uuid-1',
        providerId: 'spotify:track:1',
        title: 'One More Time',
        artist: 'Daft Punk',
        durationMs: 320000,
        artworkUrl: 'https://picsum.photos/seed/daft/300/300',
        score: 12,
      ),
      Track(
        id: 'track-uuid-2',
        providerId: 'spotify:track:2',
        title: 'Starboy',
        artist: 'The Weeknd',
        durationMs: 230000,
        artworkUrl: 'https://picsum.photos/seed/weeknd/300/300',
        score: 8,
      ),
    ],
  );

  static final Room voteRoom2 = Room(
    id: 'room-vote-2',
    name: 'Deep Focus Beats',
    ownerId: 'user-1',
    kind: RoomKind.vote,
    isPublic: true,
    tracks: [
      Track(
        id: 'track-uuid-5',
        providerId: 'spotify:track:5',
        title: 'Get Lucky',
        artist: 'Daft Punk',
        durationMs: 249000,
        artworkUrl: 'https://picsum.photos/seed/daft/300/300',
        score: 5,
      ),
    ],
  );

  static final Room voteRoom3 = Room(
    id: 'room-vote-3',
    name: 'Workout Power Mix',
    ownerId: 'user-1',
    kind: RoomKind.vote,
    isPublic: true,
    tracks: [
      Track(
        id: 'track-uuid-6',
        providerId: 'spotify:track:6',
        title: 'Instant Crush',
        artist: 'Daft Punk',
        durationMs: 337000,
        artworkUrl: 'https://picsum.photos/seed/daft/300/300',
        score: 7,
      ),
    ],
  );

  // * PLAYLIST room
  static final Room playlistRoom = Room(
    id: 'room-playlist-1',
    name: 'My Favorites',
    ownerId: 'user-1',
    kind: RoomKind.playlist,
    isPublic: true,
    tracks: [
      Track(
        id: 'track-uuid-3',
        providerId: 'spotify:track:3',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        durationMs: 200000,
        artworkUrl: 'https://picsum.photos/seed/blinding/300/300',
        position: 'a0',
      ),
      Track(
        id: 'track-uuid-4',
        providerId: 'spotify:track:4',
        title: 'Around the World',
        artist: 'Daft Punk',
        durationMs: 420000,
        artworkUrl: 'https://picsum.photos/seed/around/300/300',
        position: 'a1',
      ),
    ],
  );

  // * DELEGATE room
  static final Room delegateRoom = Room(
    id: 'room-delegate-1',
    name: 'Electronic Beats Room',
    ownerId: 'user-2',
    kind: RoomKind.delegate,
    isPublic: false,
    currentControllerId: 'user-2',
  );

  static List<Room> get rooms => [
    voteRoom1,
    voteRoom2,
    voteRoom3,
    playlistRoom,
    delegateRoom,
  ];
}
