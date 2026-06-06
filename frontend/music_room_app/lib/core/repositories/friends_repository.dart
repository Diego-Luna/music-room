import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/user.dart';

abstract class FriendsRepository {
  Future<List<FriendDto>> getFriends();
  Future<List<FriendshipDto>> getIncomingRequests();
  Future<List<FriendshipDto>> getOutgoingRequests();
  Future<FriendshipDto> sendFriendRequest(String userId);
  Future<FriendshipDto> acceptRequest(String friendshipId);
  Future<FriendshipDto> declineRequest(String friendshipId);
  Future<void> cancelOrUnfriend(String friendshipId);
  Future<User> getUserProfile(String userId);
}
