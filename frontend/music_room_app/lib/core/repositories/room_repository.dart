import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

// * The contract
abstract class RoomRepository {
  // * Rooms
  Future<List<Room>> getRooms({RoomKind? kind});
  Future<Room> getRoomById(String id);
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
	});
  Future<void> deleteRoom(String id);
  Future<void> joinRoom(String id);
  Future<void> leaveRoom(String id);

  // * Invite a user to a (private) room — POST /rooms/:id/invitations
  Future<void> inviteToRoom(String roomId, String userId);

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
  Future<void> removeVoteTrack(String roomId, String trackId);

  // *PLAYLIST room
  Future<List<Track>> getPlaylistTracks(String roomId);
  Future<Track> addPlaylistTrack(String roomId, Track track);
  Future<void> movePlaylistTrack(
    String roomId,
    String trackId,
    String newPosition,
  );
  Future<void> removePlaylistTrack(String roomId, String trackId);

  // *DELEGATE room
	Future<void> delegateRoomControl(String roomId, String userId);
	Future<void> revokeRoomControl(String roomId);

	// * Search tracks via the music provider (Deezer)
	Future<List<Track>> searchTracks(String query);
}
