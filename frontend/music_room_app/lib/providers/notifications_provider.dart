import 'package:flutter/foundation.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/invitation.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';

// * State manager for the Inbox/Notifications tab, combining friend requests and room invitations
class NotificationsProvider extends ChangeNotifier {
  final RoomRepository roomRepository;
  final FriendsRepository friendsRepository;

  List<FriendshipDto> incomingFriendRequests = [];
  List<RoomInvitationDto> roomInvitations = [];
  List<FriendshipDto> outgoingFriendRequests = [];

  // * Cache for profiles and rooms to avoid multiple requests
  final Map<String, User> userCache = {};
  final Map<String, Room> roomCache = {};

  bool isLoading = false;
  String? error;

  NotificationsProvider({
    required this.roomRepository,
    required this.friendsRepository,
  });

  Future<void> fetchNotifications() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        friendsRepository.getIncomingRequests(),
        roomRepository.getInvitations(),
        friendsRepository.getOutgoingRequests(),
      ]);

      incomingFriendRequests = results[0] as List<FriendshipDto>;
      roomInvitations = results[1] as List<RoomInvitationDto>;
      outgoingFriendRequests = results[2] as List<FriendshipDto>;

      // * Collect unique user and room IDs to fetch profiles/rooms
      final Set<String> userIdsToFetch = {};
      final Set<String> roomIdsToFetch = {};

      for (final req in incomingFriendRequests) {
        userIdsToFetch.add(req.requesterId);
      }
      for (final req in outgoingFriendRequests) {
        userIdsToFetch.add(req.addresseeId);
      }
      for (final invite in roomInvitations) {
        userIdsToFetch.add(invite.inviterId);
        roomIdsToFetch.add(invite.roomId);
      }

      await Future.wait([
        _fetchProfilesForCache(userIdsToFetch),
        _fetchRoomsForCache(roomIdsToFetch),
      ]);
    } catch (e) {
      error = ApiErrorHandler.getMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchProfilesForCache(Set<String> userIds) async {
    final List<Future<void>> fetches = [];
    for (final id in userIds) {
      if (!userCache.containsKey(id)) {
        fetches.add(
          friendsRepository
              .getUserProfile(id)
              .then((user) {
                userCache[id] = user;
              })
              .catchError((_) {
                // * Ignore errors for single profiles to prevent blocking
              }),
        );
      }
    }
    if (fetches.isNotEmpty) {
      await Future.wait(fetches);
    }
  }

  // * Cache for rooms to avoid multiple requests
  Future<void> _fetchRoomsForCache(Set<String> roomIds) async {
    final List<Future<void>> fetches = [];
    for (final id in roomIds) {
      if (!roomCache.containsKey(id)) {
        fetches.add(
          roomRepository
              .getRoomById(id)
              .then((room) {
                roomCache[id] = room;
              })
              .catchError((_) {
                // * Ignore errors for single rooms to prevent blocking
              }),
        );
      }
    }
    if (fetches.isNotEmpty) {
      await Future.wait(fetches);
    }
  }

  Future<void> acceptFriendRequest(String id) async {
    try {
      await friendsRepository.acceptRequest(id);
      await fetchNotifications();
    } catch (e) {
      error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> declineFriendRequest(String id) async {
    try {
      await friendsRepository.declineRequest(id);
      await fetchNotifications();
    } catch (e) {
      error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> cancelOrRemoveFriendship(String id) async {
    try {
      await friendsRepository.cancelOrUnfriend(id);
      await fetchNotifications();
    } catch (e) {
      error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> acceptRoomInvitation(String id) async {
    try {
      await roomRepository.acceptInvitation(id);
      await fetchNotifications();
    } catch (e) {
      final msg = ApiErrorHandler.getMessage(e);
      error = msg;

      if (msg.toLowerCase().contains('already a member')) {
        // * Silently decline the invitation to remove it from the backend's pending list
        try {
          await roomRepository.declineInvitation(id);
        } catch (_) {}
        await fetchNotifications();
      }

      notifyListeners();
      rethrow;
    }
  }

  Future<void> declineRoomInvitation(String id) async {
    try {
      await roomRepository.declineInvitation(id);
      await fetchNotifications();
    } catch (e) {
      error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }
}
