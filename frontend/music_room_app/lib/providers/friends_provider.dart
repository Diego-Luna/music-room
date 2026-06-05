import 'package:flutter/foundation.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/friendship.dart';

enum FriendsView { friends, requests, add }

class FriendsProvider extends ChangeNotifier {
  final FriendsRepository _repository;

  FriendsProvider({required FriendsRepository repository})
    : _repository = repository;

  List<FriendDto> _friends = [];
  List<FriendshipDto> _incomingRequests = [];
  List<FriendshipDto> _outgoingRequests = [];
  final Map<String, User> _userCache = {};

  bool _isLoading = false;
  String? _error;
  FriendsView _currentView = FriendsView.friends;

  List<FriendDto> get friends => _friends;
  List<FriendshipDto> get incomingRequests => _incomingRequests;
  List<FriendshipDto> get outgoingRequests => _outgoingRequests;
  Map<String, User> get userCache => _userCache;

  bool get isLoading => _isLoading;
  String? get error => _error;
  FriendsView get currentView => _currentView;

  void setView(FriendsView view) {
    _currentView = view;
    notifyListeners();
  }

  Future<void> fetchFriendsData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getFriends(),
        _repository.getIncomingRequests(),
        _repository.getOutgoingRequests(),
      ]);

      _friends = results[0] as List<FriendDto>;
      _incomingRequests = results[1] as List<FriendshipDto>;
      _outgoingRequests = results[2] as List<FriendshipDto>;

      final Set<String> userIdsToFetch = {};
      for (final f in _friends) {
        userIdsToFetch.add(f.friendId);
      }
      for (final req in _incomingRequests) {
        userIdsToFetch.add(req.requesterId);
      }
      for (final req in _outgoingRequests) {
        userIdsToFetch.add(req.addresseeId);
      }

      await _fetchProfilesForCache(userIdsToFetch);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchProfilesForCache(Set<String> userIds) async {
    final List<Future<void>> profileFetches = [];
    for (final id in userIds) {
      if (!_userCache.containsKey(id)) {
        profileFetches.add(
          _repository
              .getUserProfile(id)
              .then((user) {
                _userCache[id] = user;
              })
              .catchError((e) {
                // * Ignore failures for individual profiles
              }),
        );
      }
    }
    if (profileFetches.isNotEmpty) {
      await Future.wait(profileFetches);
    }
  }

  Future<void> sendRequest(String targetUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final req = await _repository.sendFriendRequest(targetUserId);
      _outgoingRequests.add(req);
      await _fetchProfilesForCache({targetUserId});
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptFriendRequest(String friendshipId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.acceptRequest(friendshipId);
      _incomingRequests.removeWhere((r) => r.id == friendshipId);
      final freshFriends = await _repository.getFriends();
      _friends = freshFriends;
      final Set<String> ids = freshFriends.map((f) => f.friendId).toSet();
      await _fetchProfilesForCache(ids);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> declineFriendRequest(String friendshipId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.declineRequest(friendshipId);
      _incomingRequests.removeWhere((r) => r.id == friendshipId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelOrRemoveFriendship(String friendshipId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.cancelOrUnfriend(friendshipId);
      _friends.removeWhere((f) => f.friendshipId == friendshipId);
      _incomingRequests.removeWhere((r) => r.id == friendshipId);
      _outgoingRequests.removeWhere((r) => r.id == friendshipId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
