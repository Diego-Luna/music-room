import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/user_search_page.dart';

class MockFriendsRepository implements FriendsRepository {
  final List<User> _mockUsers = [
    User(
      id: 'user-2',
      email: 'jeremy@42.fr',
      displayName: 'Jeremy',
      avatarUrl: 'https://i.pravatar.cc/150?u=user-2',
    ),
    User(id: 'user-3', email: 'music@lover.com', displayName: 'Music Lover'),
    User(
      id: 'user-4',
      email: 'alice@42.fr',
      displayName: 'Alice',
      avatarUrl: 'https://i.pravatar.cc/150?u=user-4',
    ),
  ];

  final List<FriendshipDto> _friendships = [
    FriendshipDto(
      id: 'friendship-1',
      requesterId: 'user-1',
      addresseeId: 'user-2',
      status: 'ACCEPTED',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      respondedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    FriendshipDto(
      id: 'friendship-2',
      requesterId: 'user-3',
      addresseeId: 'user-1',
      status: 'PENDING',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  @override
  Future<List<FriendDto>> getFriends() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _friendships
        .where((f) => f.status == 'ACCEPTED')
        .map(
          (f) => FriendDto(
            friendshipId: f.id,
            friendId: f.requesterId == 'user-1' ? f.addresseeId : f.requesterId,
            since: f.respondedAt,
          ),
        )
        .toList();
  }

  @override
  Future<List<FriendshipDto>> getIncomingRequests() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _friendships
        .where((f) => f.addresseeId == 'user-1' && f.status == 'PENDING')
        .toList();
  }

  @override
  Future<List<FriendshipDto>> getOutgoingRequests() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _friendships
        .where((f) => f.requesterId == 'user-1' && f.status == 'PENDING')
        .toList();
  }

  @override
  Future<FriendshipDto> sendFriendRequest(String userId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final req = FriendshipDto(
      id: 'friendship-${DateTime.now().millisecondsSinceEpoch}',
      requesterId: 'user-1',
      addresseeId: userId,
      status: 'PENDING',
      createdAt: DateTime.now(),
    );
    _friendships.add(req);
    return req;
  }

  @override
  Future<FriendshipDto> acceptRequest(String friendshipId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _friendships.indexWhere((f) => f.id == friendshipId);
    if (index == -1) throw Exception('Friendship not found');
    final updated = FriendshipDto(
      id: _friendships[index].id,
      requesterId: _friendships[index].requesterId,
      addresseeId: _friendships[index].addresseeId,
      status: 'ACCEPTED',
      createdAt: _friendships[index].createdAt,
      respondedAt: DateTime.now(),
    );
    _friendships[index] = updated;
    return updated;
  }

  @override
  Future<FriendshipDto> declineRequest(String friendshipId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _friendships.indexWhere((f) => f.id == friendshipId);
    if (index == -1) throw Exception('Friendship not found');
    final updated = FriendshipDto(
      id: _friendships[index].id,
      requesterId: _friendships[index].requesterId,
      addresseeId: _friendships[index].addresseeId,
      status: 'DECLINED',
      createdAt: _friendships[index].createdAt,
      respondedAt: DateTime.now(),
    );
    _friendships[index] = updated;
    return updated;
  }

  @override
  Future<void> cancelOrUnfriend(String friendshipId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _friendships.removeWhere((f) => f.id == friendshipId);
  }

  @override
  Future<User> getUserProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _mockUsers.firstWhere(
      (u) => u.id == userId,
      orElse: () => User(
        id: userId,
        email: 'unknown@user.com',
        displayName: 'User $userId',
      ),
    );
  }

  @override
  Future<UserSearchPage> searchUsers({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final q = (query ?? '').toLowerCase();
    final matches = _mockUsers
        .where((u) => q.isEmpty || u.displayName.toLowerCase().contains(q))
        .toList();
    final page = matches.skip(offset).take(limit).toList();
    return UserSearchPage(
      items: page,
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }
}
