import 'package:music_room_app/config/mock/mock_data.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

class MockApiRepository implements RoomRepository {
  final List<Room> _rooms = List.from(MockData.rooms);

  // Rooms
  @override
  Future<List<Room>> getRooms({RoomKind? kind}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (kind == null) return List.unmodifiable(_rooms);
    return _rooms.where((r) => r.kind == kind).toList();
  }

  @override
  Future<Room> getRoomById(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _rooms.firstWhere((r) => r.id == id);
  }

	@override
	Future<Room> createRoom({
		required String name,
		required RoomKind kind,
		required bool isPublic,
		String? description,
		String? voteAccess,
		String? voteWindow,
		DateTime? voteStartsAt,
		DateTime? voteEndsAt,
		double? voteLocationLat,
		double? voteLocationLng,
		double? voteLocationRadiusM,
	}) async {
		await Future.delayed(const Duration(milliseconds: 50));
		final room = Room(
			id: 'room-${DateTime.now().millisecondsSinceEpoch}',
			name: name,
			ownerId: 'user-1',
			kind: kind,
			isPublic: isPublic,
		);
		_rooms.add(room);
		return room;
	}

  @override
  Future<void> deleteRoom(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _rooms.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> joinRoom(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> leaveRoom(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // VOTE room
  @override
  Future<List<Track>> getVoteTracks(String roomId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final room = await getRoomById(roomId);
    final sorted = List<Track>.from(room.tracks);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }

  @override
  Future<Track> addVoteTrack(String roomId, Track track) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) throw Exception('Room not found');
    final updated = List<Track>.from(_rooms[idx].tracks)..add(track);
    _rooms[idx] = _rooms[idx].copyWith(tracks: updated);
    return track;
  }

  @override
  Future<void> voteForTrack(
    String roomId,
    String trackId,
    int value, {
    double? lat,
    double? lng,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) return;
    final updated = _rooms[idx].tracks.map((t) {
      if (t.id != trackId) return t;
      return t.copyWith(score: t.score + value);
    }).toList();
    _rooms[idx] = _rooms[idx].copyWith(tracks: updated);
  }

  @override
  Future<void> removeVoteTrack(String roomId, String trackId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) return;
    final updated = _rooms[idx].tracks.where((t) => t.id != trackId).toList();
    _rooms[idx] = _rooms[idx].copyWith(tracks: updated);
  }

  // PLAYLIST room
  @override
  Future<List<Track>> getPlaylistTracks(String roomId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final room = await getRoomById(roomId);
    final sorted = List<Track>.from(room.tracks);
    sorted.sort((a, b) => (a.position ?? '').compareTo(b.position ?? ''));
    return sorted;
  }

  @override
  Future<Track> addPlaylistTrack(String roomId, Track track) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) throw Exception('Room not found');
    final updated = List<Track>.from(_rooms[idx].tracks)..add(track);
    _rooms[idx] = _rooms[idx].copyWith(tracks: updated);
    return track;
  }

  @override
  Future<void> movePlaylistTrack(
    String roomId,
    String trackId,
    String newPosition,
  ) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) return;
    final updated = _rooms[idx].tracks.map((t) {
      if (t.id != trackId) return t;
      return t.copyWith(position: newPosition);
    }).toList();
    _rooms[idx] = _rooms[idx].copyWith(tracks: updated);
  }

  @override
  Future<void> removePlaylistTrack(String roomId, String trackId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) return;
    final updated = _rooms[idx].tracks.where((t) => t.id != trackId).toList();
    _rooms[idx] = _rooms[idx].copyWith(tracks: updated);
  }

	// DELEGATE room
	@override
	Future<void> delegateRoomControl(String roomId, String userId) async {
		await Future.delayed(const Duration(milliseconds: 50));
		final idx = _rooms.indexWhere((r) => r.id == roomId);
		if (idx == -1) return;
		_rooms[idx] = _rooms[idx].copyWith(currentControllerId: userId);
	}

	@override
	Future<void> revokeRoomControl(String roomId) async {
		await Future.delayed(const Duration(milliseconds: 50));
		final idx = _rooms.indexWhere((r) => r.id == roomId);
		if (idx == -1) return;
		_rooms[idx] = _rooms[idx].copyWith(
			currentControllerId: _rooms[idx].ownerId,
		);
	}

	@override
	Future<List<Track>> searchSpotifyTracks(String query) async {
		await Future.delayed(const Duration(milliseconds: 50));
		final allTracks = _rooms.expand((r) => r.tracks).toList();
		final cleaned = query.toLowerCase();
		return allTracks
				.where((t) =>
						t.title.toLowerCase().contains(cleaned) ||
						t.artist.toLowerCase().contains(cleaned))
				.toList();
	}
}
