import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/event.dart';
import 'package:music_room_app/models/event_track.dart';
import 'package:music_room_app/models/playlist.dart';
import 'package:music_room_app/models/playlist_track.dart';
import 'package:music_room_app/models/room.dart';

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

  static final List<Track> tracks = [
    Track(
      id: 'spotify:track:1',
      title: 'One More Time',
      artist: 'Daft Punk',
      durationSeconds: 320,
      albumArtUrl: 'https://picsum.photos/seed/daft/300/300',
    ),
    Track(
      id: 'spotify:track:2',
      title: 'Starboy',
      artist: 'The Weeknd',
      durationSeconds: 230,
      albumArtUrl: 'https://picsum.photos/seed/weeknd/300/300',
    ),
    Track(
      id: 'spotify:track:3',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      durationSeconds: 200,
      albumArtUrl: 'https://picsum.photos/seed/blinding/300/300',
    ),
    Track(
      id: 'spotify:track:4',
      title: 'Around the World',
      artist: 'Daft Punk',
      durationSeconds: 420,
      albumArtUrl: 'https://picsum.photos/seed/around/300/300',
    ),
  ];

  static final List<Event> events = [
    Event(
      id: 'event-1',
      name: 'Friday Night TACOS',
      ownerId: 'user-1',
      tracks: [
        EventTrack(
          id: 'et-1',
          eventId: 'event-1',
          trackId: 'spotify:track:1',
          voteCount: 12,
          track: tracks[0],
        ),
        EventTrack(
          id: 'et-2',
          eventId: 'event-1',
          trackId: 'spotify:track:2',
          voteCount: 8,
          track: tracks[1],
        ),
      ],
    ),
    Event(
      id: 'event-2',
      name: 'Chill Vibes Only',
      ownerId: 'user-2',
      isPublic: true,
      tracks: [
        EventTrack(
          id: 'et-3',
          eventId: 'event-2',
          trackId: 'spotify:track:3',
          voteCount: 5,
          track: tracks[2],
        ),
      ],
    ),
  ];

  static final List<Playlist> playlists = [
    Playlist(
      id: 'pl-1',
      name: 'My Favorites',
      ownerId: 'user-1',
      tracks: [
        PlaylistTrack(
          id: 'pt-1',
          playlistId: 'pl-1',
          trackId: 'spotify:track:1',
          position: 0,
          track: tracks[0],
        ),
        PlaylistTrack(
          id: 'pt-2',
          playlistId: 'pl-1',
          trackId: 'spotify:track:4',
          position: 1,
          track: tracks[3],
        ),
      ],
    ),
    Playlist(
      id: 'pl-2',
      name: 'CODING MIX',
      ownerId: 'user-1',
      tracks: [
        PlaylistTrack(
          id: 'pt-3',
          playlistId: 'pl-2',
          trackId: 'spotify:track:2',
          position: 0,
          track: tracks[1],
        ),
      ],
    ),
  ];

  // Temporal date
  static final List<Room> rooms = [
    Room(
      id: 'room-1',
      name: 'Friday Rock Session',
      ownerId: 'user-1',
      currentControllerId: 'user-1',
      connectedUsers: ['user-1', 'user-2'],
    ),
    Room(
      id: 'room-2',
      name: 'Electronic Beats Room',
      ownerId: 'user-2',
      currentControllerId: 'user-2',
      connectedUsers: ['user-2', 'user-3'],
    ),
  ];
}
