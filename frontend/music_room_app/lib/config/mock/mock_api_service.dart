import 'package:music_room_app/config/mock/mock_data.dart';
import 'package:music_room_app/models/event.dart';
import 'package:music_room_app/models/playlist.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/playlist_track.dart';

class MockApiService {
  Future<T> _simulate<T>(T data) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return data;
  }

  // Auth/User
  Future<User> getProfile() => _simulate(MockData.users[0]);
  Future<User> updateProfile(Map<String, dynamic> data) async {
    final updated = MockData.users[0].copyWith(
      displayName: data['displayName'],
      avatarUrl: data['avatarUrl'],
    );
    return _simulate(updated);
  }

  // Events
  Future<List<Event>> getEvents() => _simulate(MockData.events);
  Future<Event> getEvent(String id) =>
      _simulate(MockData.events.firstWhere((e) => e.id == id));
  Future<Event> createEvent(String name, bool isPublic) async {
    final newEvent = Event(
      id: 'event-${MockData.events.length + 1}',
      name: name,
      ownerId: 'user-1',
      isPublic: isPublic,
    );
    MockData.events.add(newEvent);
    return _simulate(newEvent);
  }

  // Playlists
  Future<List<Playlist>> getPlaylists() => _simulate(MockData.playlists);
  Future<Playlist> getPlaylist(String id) =>
      _simulate(MockData.playlists.firstWhere((p) => p.id == id));
  Future<Playlist> createPlaylist(String name, bool isPublic) async {
    final newPlaylist = Playlist(
      id: 'pl-${MockData.playlists.length + 1}',
      name: name,
      ownerId: 'user-1',
      isPublic: isPublic,
    );
    MockData.playlists.add(newPlaylist);
    return _simulate(newPlaylist);
  }

  // Tracks
  Future<List<Track>> searchTracks(String query) async {
    final results = MockData.tracks
        .where((t) =>
            t.title.toLowerCase().contains(query.toLowerCase()) ||
            t.artist.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return _simulate(results);
  }

  // Voting
  Future<void> voteTrack(String eventId, String trackId, bool isPositive) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final event = MockData.events.firstWhere((e) => e.id == eventId);
    final eventTrack = event.tracks.firstWhere((t) => t.trackId == trackId);
    // In a real app, we'd check if user already voted, but this is a mock
    final index = event.tracks.indexOf(eventTrack);
    event.tracks[index] = eventTrack.copyWith(
      voteCount: isPositive ? eventTrack.voteCount + 1 : eventTrack.voteCount - 1,
    );
  }

  // Playlist Management
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final playlist = MockData.playlists.firstWhere((p) => p.id == playlistId);
    final track = MockData.tracks.firstWhere((t) => t.id == trackId);
    
    playlist.tracks.add(
      PlaylistTrack(
        id: 'pt-${DateTime.now().millisecondsSinceEpoch}',
        playlistId: playlistId,
        trackId: trackId,
        position: playlist.tracks.length,
        track: track,
      ),
    );
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final playlist = MockData.playlists.firstWhere((p) => p.id == playlistId);
    playlist.tracks.removeWhere((t) => t.trackId == trackId);
  }
}
