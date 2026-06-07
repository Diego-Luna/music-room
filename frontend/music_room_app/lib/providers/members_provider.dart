import 'package:flutter/foundation.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';
import 'package:music_room_app/models/room_member.dart';
import 'package:music_room_app/models/user.dart';

// * Page-owned provider (like ProfileProvider) scoped to a single room's
// * membership. Reusable by both PlaylistDetail and EventDetail. Resolves
// * userId -> User for display names, mirroring FriendsProvider's cache.
class MembersProvider extends ChangeNotifier {
  final RoomRepository _rooms;
  final FriendsRepository _friends;

  MembersProvider({
    required RoomRepository roomRepository,
    required FriendsRepository friendsRepository,
  }) : _rooms = roomRepository,
       _friends = friendsRepository;

  List<RoomMember> _members = [];
  final Map<String, User> _userCache = {};
  bool _isLoading = false;
  String? _error;

  List<RoomMember> get members => _members;
  Map<String, User> get userCache => _userCache;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load(String roomId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _members = await _rooms.getMembers(roomId);
      await _fetchProfilesForCache(_members.map((m) => m.userId).toSet());
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchProfilesForCache(Set<String> userIds) async {
    final fetches = <Future<void>>[];
    for (final id in userIds) {
      if (_userCache.containsKey(id)) continue;
      fetches.add(
        _friends
            .getUserProfile(id)
            .then((user) {
              _userCache[id] = user;
            })
            .catchError((_) {
              // * Ignore individual profile failures (e.g. private profiles).
            }),
      );
    }
    if (fetches.isNotEmpty) await Future.wait(fetches);
  }

  // * Owner-only. Updates the role locally on success.
  Future<void> changeRole(
    String roomId,
    String userId,
    RoomMemberRole role,
  ) async {
    try {
      final updated = await _rooms.updateMemberRole(roomId, userId, role);
      final idx = _members.indexWhere((m) => m.userId == userId);
      if (idx != -1) _members[idx] = updated;
      notifyListeners();
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  // * Owner/admin. Removes the member locally on success.
  Future<void> removeMember(String roomId, String userId) async {
    try {
      await _rooms.removeMember(roomId, userId);
      _members.removeWhere((m) => m.userId == userId);
      notifyListeners();
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  // * Current user joins a PUBLIC room (direct membership; the backend rejects
  //   private rooms without an invitation). Reloads the member list on success
  //   so the caller reflects the new membership.
  Future<void> join(String roomId) async {
    try {
      await _rooms.joinRoom(roomId);
      await load(roomId);
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  // * Current user leaves the room.
  Future<void> leave(String roomId) async {
    try {
      await _rooms.leaveRoom(roomId);
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }
}
