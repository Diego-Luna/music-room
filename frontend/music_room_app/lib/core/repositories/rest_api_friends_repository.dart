import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/user_search_page.dart';

class RestApiFriendsRepository implements FriendsRepository {
  final ApiClient _client;

  RestApiFriendsRepository({required ApiClient client}) : _client = client;

  @override
  Future<List<FriendDto>> getFriends() async {
    final response = await _client.get('/users/me/friends');
    final data = response.data as List;
    return data.map((json) => FriendDto.fromJson(json)).toList();
  }

  @override
  Future<List<FriendshipDto>> getIncomingRequests() async {
    final response = await _client.get('/users/me/friends/incoming');
    final data = response.data as List;
    return data.map((json) => FriendshipDto.fromJson(json)).toList();
  }

  @override
  Future<List<FriendshipDto>> getOutgoingRequests() async {
    final response = await _client.get('/users/me/friends/outgoing');
    final data = response.data as List;
    return data.map((json) => FriendshipDto.fromJson(json)).toList();
  }

  @override
  Future<FriendshipDto> sendFriendRequest(String userId) async {
    final response = await _client.post(
      '/users/me/friends/request',
      data: {'userId': userId},
    );
    return FriendshipDto.fromJson(response.data);
  }

  @override
  Future<FriendshipDto> acceptRequest(String friendshipId) async {
    final response = await _client.post(
      '/users/me/friends/$friendshipId/accept',
    );
    return FriendshipDto.fromJson(response.data);
  }

  @override
  Future<FriendshipDto> declineRequest(String friendshipId) async {
    final response = await _client.post(
      '/users/me/friends/$friendshipId/decline',
    );
    return FriendshipDto.fromJson(response.data);
  }

  @override
  Future<void> cancelOrUnfriend(String friendshipId) async {
    await _client.delete('/users/me/friends/$friendshipId');
  }

  @override
  Future<User> getUserProfile(String userId) async {
    final response = await _client.get('/users/$userId');
    return User.fromJson(response.data);
  }

  @override
  Future<UserSearchPage> searchUsers({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client.get(
      '/users/search',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        'limit': limit,
        'offset': offset,
      },
    );
    return UserSearchPage.fromJson(response.data as Map<String, dynamic>);
  }
}
