import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_ce/hive.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/user_search_page.dart';

// * Offline decorator over the remote friends repository.
// * Read lists (friends / incoming / outgoing) are cached in Hive and served
// * from cache when the network is unreachable, so the friends screen stays
// * readable offline. Mutations stay online-only (they need server validation).
class OfflineFriendsRepository implements FriendsRepository {
  final FriendsRepository _remote;
  final Connectivity _connectivity;
  final Box<Map>? _testBox;

  OfflineFriendsRepository({
    required FriendsRepository remoteRepository,
    Connectivity? connectivity,
    Box<Map>? cacheBox,
  }) : _remote = remoteRepository,
       _connectivity = connectivity ?? Connectivity(),
       _testBox = cacheBox;

  Box<Map> get _box => _testBox ?? Hive.box<Map>('cached_friends');

  Future<bool> _isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> json) async {
    await _box.put(key, {'list': json});
  }

  List<Map<String, dynamic>> _readList(String key) {
    final data = _box.get(key);
    final list = (data?['list'] as List?) ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<FriendDto>> getFriends() async {
    if (!await _isOnline()) {
      return _readList('friends').map(FriendDto.fromJson).toList();
    }
    try {
      final friends = await _remote.getFriends();
      await _saveList('friends', friends.map((f) => f.toJson()).toList());
      return friends;
    } catch (_) {
      return _readList('friends').map(FriendDto.fromJson).toList();
    }
  }

  @override
  Future<List<FriendshipDto>> getIncomingRequests() async {
    if (!await _isOnline()) {
      return _readList('incoming').map(FriendshipDto.fromJson).toList();
    }
    try {
      final requests = await _remote.getIncomingRequests();
      await _saveList('incoming', requests.map((r) => r.toJson()).toList());
      return requests;
    } catch (_) {
      return _readList('incoming').map(FriendshipDto.fromJson).toList();
    }
  }

  @override
  Future<List<FriendshipDto>> getOutgoingRequests() async {
    if (!await _isOnline()) {
      return _readList('outgoing').map(FriendshipDto.fromJson).toList();
    }
    try {
      final requests = await _remote.getOutgoingRequests();
      await _saveList('outgoing', requests.map((r) => r.toJson()).toList());
      return requests;
    } catch (_) {
      return _readList('outgoing').map(FriendshipDto.fromJson).toList();
    }
  }

  // * Mutations and single-profile lookups stay online-only.
  @override
  Future<FriendshipDto> sendFriendRequest(String userId) =>
      _remote.sendFriendRequest(userId);

  @override
  Future<FriendshipDto> acceptRequest(String friendshipId) =>
      _remote.acceptRequest(friendshipId);

  @override
  Future<FriendshipDto> declineRequest(String friendshipId) =>
      _remote.declineRequest(friendshipId);

  @override
  Future<void> cancelOrUnfriend(String friendshipId) =>
      _remote.cancelOrUnfriend(friendshipId);

  @override
  Future<User> getUserProfile(String userId) =>
      _remote.getUserProfile(userId);

  // * Search needs the network (no meaningful offline cache for it).
  @override
  Future<UserSearchPage> searchUsers({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!await _isOnline()) {
      throw Exception('Search needs an internet connection.');
    }
    return _remote.searchUsers(query: query, limit: limit, offset: offset);
  }
}
