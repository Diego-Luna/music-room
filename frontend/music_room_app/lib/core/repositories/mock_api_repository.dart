import 'package:music_room_app/config/mock/mock_data.dart';
import 'package:music_room_app/models/event.dart';
import 'package:music_room_app/models/event_track.dart';
import 'package:music_room_app/models/playlist.dart';
import 'package:music_room_app/models/playlist_track.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

class MockApiRepository {
  final List<Event> _events = List.from(MockData.events);
  final List<Playlist> _playlists = List.from(MockData.playlists);
  final List<Room> _rooms = List.from(MockData.rooms);

  Future<List<Event>> getEvents() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_events);
  }

  Future<Event> getEventById(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _events.firstWhere((e) => e.id == id);
  }

  Future<Event> createEvent(Event event) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _events.add(event);
    return event;
  }

  Future<void> voteForTrack(
    String eventId,
    String trackId,
    bool hasVoted,
  ) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex != -1) {
      final event = _events[eventIndex];
      final trackIndex = event.tracks.indexWhere((t) => t.trackId == trackId);
      if (trackIndex != -1) {
        final eventTrack = event.tracks[trackIndex];
        final diff = hasVoted ? 1 : -1;
        final updatedTrack = eventTrack.copyWith(
          voteCount: eventTrack.voteCount + diff,
          hasVoted: hasVoted,
        );
        final updatedTracks = List<EventTrack>.from(event.tracks);
        updatedTracks[trackIndex] = updatedTrack;
        updatedTracks.sort((a, b) => b.voteCount.compareTo(a.voteCount));
        _events[eventIndex] = event.copyWith(tracks: updatedTracks);
      }
    }
  }

  Future<void> suggestTrack(String eventId, Track track) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex != -1) {
      final event = _events[eventIndex];
      final trackExists = event.tracks.any((t) => t.trackId == track.id);
      if (!trackExists) {
        final newEventTrack = EventTrack(
          id: 'et-${DateTime.now().millisecondsSinceEpoch}',
          eventId: eventId,
          trackId: track.id,
          voteCount: 1,
          hasVoted: true,
          track: track,
        );
        final updatedTracks = List<EventTrack>.from(event.tracks)
          ..add(newEventTrack);
        updatedTracks.sort((a, b) => b.voteCount.compareTo(a.voteCount));
        _events[eventIndex] = event.copyWith(tracks: updatedTracks);
      }
    }
  }

  Future<List<Playlist>> getPlaylists() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_playlists);
  }

  Future<Playlist> getPlaylistById(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _playlists.firstWhere((p) => p.id == id);
  }

  Future<Playlist> createPlaylist(Playlist playlist) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _playlists.add(playlist);
    return playlist;
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final playlist = _playlists[playlistIndex];
      final trackExists = playlist.tracks.any((t) => t.trackId == track.id);
      if (!trackExists) {
        final newPlaylistTrack = PlaylistTrack(
          id: 'pt-${DateTime.now().millisecondsSinceEpoch}',
          playlistId: playlistId,
          trackId: track.id,
          position: playlist.tracks.length,
          track: track,
        );
        final updatedTracks = List<PlaylistTrack>.from(playlist.tracks)
          ..add(newPlaylistTrack);
        _playlists[playlistIndex] = playlist.copyWith(tracks: updatedTracks);
      }
    }
  }

  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final playlist = _playlists[playlistIndex];
      final updatedTracks = playlist.tracks
          .where((t) => t.trackId != trackId)
          .toList();
      _playlists[playlistIndex] = playlist.copyWith(tracks: updatedTracks);
    }
  }

  Future<List<Room>> getRooms() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_rooms);
  }

  Future<Room> getRoomById(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _rooms.firstWhere((r) => r.id == id);
  }

  Future<Room> createRoom(Room room) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _rooms.add(room);
    return room;
  }

  Future<void> delegateRoomControl(String roomId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final roomIndex = _rooms.indexWhere((r) => r.id == roomId);
    if (roomIndex != -1) {
      final room = _rooms[roomIndex];
      _rooms[roomIndex] = room.copyWith(currentControllerId: userId);
    }
  }

  Future<void> revokeRoomControl(String roomId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final roomIndex = _rooms.indexWhere((r) => r.id == roomId);
    if (roomIndex != -1) {
      final room = _rooms[roomIndex];
      _rooms[roomIndex] = room.copyWith(currentControllerId: room.ownerId);
    }
  }
}
