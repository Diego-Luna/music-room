import 'package:flutter/foundation.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';

enum FriendsView { friends, requests, add }

class FriendsProvider extends ChangeNotifier {
  final FriendsRepository _repository;

  FriendsProvider({required FriendsRepository repository})
    : _repository = repository;

  List<FriendDto> _friends = [];
  final Map<String, User> _userCache = {};

  bool _isLoading = false;
  String? _error;
  FriendsView _currentView = FriendsView.friends;

  List<FriendDto> get friends => _friends;
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
      final results = await Future.wait([_repository.getFriends()]);

      _friends = results[0];

      final Set<String> userIdsToFetch = {};
      for (final f in _friends) {
        userIdsToFetch.add(f.friendId);
      }

      await _fetchProfilesForCache(userIdsToFetch);
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
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
      await _repository.sendFriendRequest(targetUserId);
      await _fetchProfilesForCache({targetUserId});
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
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
      final freshFriends = await _repository.getFriends();
      _friends = freshFriends;
      final Set<String> ids = freshFriends.map((f) => f.friendId).toSet();
      await _fetchProfilesForCache(ids);
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
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
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
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
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
