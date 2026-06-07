import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/invitation.dart';
import 'package:music_room_app/models/room_member.dart';

// * The contract
abstract class RoomRepository {
  // * Rooms
  Future<List<Room>> getRooms({RoomKind? kind});

  Future<Room> getRoomById(String id);

  // ? posible to do better with a type, or maybe a class that
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
  });

  // * Update an existing room's settings (owner/admin) — PATCH /rooms/:id.
  //   Only the provided fields change; the rest are left untouched.
  Future<Room> updateRoom(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
    String? editAccess,
    String? voteAccess,
  });

  Future<void> deleteRoom(String id);

  Future<void> joinRoom(String id);

  Future<void> leaveRoom(String id);

  // * Invite a user to a (private) room — POST /rooms/:id/invitations
  Future<void> inviteToRoom(String roomId, String userId);

  // * Members (V.2.3) — list / change role (owner) / remove (owner|admin)
  Future<List<RoomMember>> getMembers(String roomId);
  Future<RoomMember> updateMemberRole(
    String roomId,
    String userId,
    RoomMemberRole role,
  );
  Future<void> removeMember(String roomId, String userId);

  // * VOTE room
  Future<List<Track>> getVoteTracks(String roomId);

  Future<Track> addVoteTrack(String roomId, Track track);

  Future<void> voteForTrack(
    String roomId,
    String trackId,

    // * value: 1 = upvote, -1 = downvote, 0 = remove vote
    int value, {
    double? lat,
    double? lng,
  });

  // *PLAYLIST room
  Future<List<Track>> getPlaylistTracks(String roomId);

  Future<Track> addPlaylistTrack(String roomId, Track track);

  // * Reorder a playlist track via fractional indices: provide exactly one of
  //   afterTrackId / beforeTrackId (the anchor the moved track lands next to).
  Future<void> movePlaylistTrack(
    String roomId,
    String trackId, {
    String? afterTrackId,
    String? beforeTrackId,
  });

  Future<void> removePlaylistTrack(String roomId, String trackId);

  // *DELEGATE room

  // * Search tracks via the music provider (Deezer)
  Future<List<Track>> searchTracks(String query);

  // * Room Invitations
  Future<List<RoomInvitationDto>> getInvitations();
  Future<AcceptInvitationResultDto> acceptInvitation(String invitationId);
  Future<RoomInvitationDto> declineInvitation(String invitationId);

  // * Invitations I sent (still pending) + revoke one of them
  Future<List<RoomInvitationDto>> getSentInvitations();
  Future<void> cancelInvitation(String invitationId);
}
