import 'package:music_room_app/config/mock/mock_data.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/user.dart';

// ! Legacy helper service
// * The new business logic should go in RoomRepository
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

  // Rooms
  Future<List<Room>> getRooms({RoomKind? kind}) {
    final data = kind == null
        ? MockData.rooms
        : MockData.rooms.where((r) => r.kind == kind).toList();
    return _simulate(data);
  }

  // Tracks

  Future<List<Track>> searchTracks(String query) {
    final cleanedQuery = query.toLowerCase();
    final allTracks = MockData.rooms.expand((r) => r.tracks).toList();
    final results = allTracks
        .where(
          (t) =>
              t.title.toLowerCase().contains(cleanedQuery) ||
              t.artist.toLowerCase().contains(cleanedQuery),
        )
        .toList();
    return _simulate(results);
  }
}
