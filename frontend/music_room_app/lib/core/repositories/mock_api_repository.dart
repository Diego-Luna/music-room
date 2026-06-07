import 'package:music_room_app/config/mock/mock_data.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/invitation.dart';
import 'package:music_room_app/models/room_member.dart';

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
    String? editAccess,
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
  Future<Room> updateRoom(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
    String? editAccess,
    String? voteAccess,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _rooms.indexWhere((r) => r.id == id);
    if (idx == -1) {
      return Room(id: id, name: name ?? 'Room', ownerId: 'owner-mock');
    }
    final updated = _rooms[idx].copyWith(
      name: name,
      isPublic: isPublic,
      description: description,
      editAccess: editAccess,
      voteAccess: voteAccess,
    );
    _rooms[idx] = updated;
    return updated;
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
    String trackId, {
    String? afterTrackId,
    String? beforeTrackId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) return;
    final tracks = List<Track>.from(_rooms[idx].tracks);
    final moving = tracks.indexWhere((t) => t.id == trackId);
    if (moving == -1) return;
    final track = tracks.removeAt(moving);
    int insertAt;
    if (afterTrackId != null) {
      final a = tracks.indexWhere((t) => t.id == afterTrackId);
      insertAt = a == -1 ? tracks.length : a + 1;
    } else if (beforeTrackId != null) {
      final b = tracks.indexWhere((t) => t.id == beforeTrackId);
      insertAt = b == -1 ? 0 : b;
    } else {
      insertAt = tracks.length;
    }
    tracks.insert(insertAt, track);
    _rooms[idx] = _rooms[idx].copyWith(tracks: tracks);
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
  Future<void> inviteToRoom(String roomId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    // * Mock: invitations are not persisted in the in-memory store.
  }

  @override
  Future<List<Track>> searchTracks(String query) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final allTracks = _rooms.expand((r) => r.tracks).toList();
    final cleaned = query.toLowerCase();
    return allTracks
        .where(
          (t) =>
              t.title.toLowerCase().contains(cleaned) ||
              t.artist.toLowerCase().contains(cleaned),
        )
        .toList();
  }

  @override
  Future<List<RoomMember>> getMembers(String roomId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final room = _rooms.firstWhere(
      (r) => r.id == roomId,
      orElse: () => _rooms.first,
    );
    return [
      RoomMember(
        id: 'member-owner-$roomId',
        roomId: roomId,
        userId: room.ownerId,
        role: RoomMemberRole.owner,
        joinedAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<RoomMember> updateMemberRole(
    String roomId,
    String userId,
    RoomMemberRole role,
  ) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return RoomMember(
      id: 'member-$userId',
      roomId: roomId,
      userId: userId,
      role: role,
      joinedAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeMember(String roomId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<List<RoomInvitationDto>> getInvitations() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return [];
  }

  @override
  Future<AcceptInvitationResultDto> acceptInvitation(
    String invitationId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return AcceptInvitationResultDto(message: 'Joined room');
  }

  @override
  Future<RoomInvitationDto> declineInvitation(String invitationId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return RoomInvitationDto(
      id: invitationId,
      roomId: 'room-mock-1',
      inviterId: 'inviter-mock-1',
      inviteeId: 'invitee-mock-1',
      status: 'DECLINED',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<RoomInvitationDto>> getSentInvitations() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return [];
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
