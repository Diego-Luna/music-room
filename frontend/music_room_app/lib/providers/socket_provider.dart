import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/core/globals.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';

// * Central provider for managing WebSocket connection and forwarding events
class SocketProvider extends ChangeNotifier {
  late final io.Socket _socket;
  final AuthProvider _authProvider;
  final FriendsProvider _friendsProvider;
  final NotificationsProvider _notificationsProvider;

  // * Id of the room whose detail page is currently open (set via
  // * join/leaveRoom by the detail pages). Lets us pop the user out only when
  // * they are kicked from the room they are actually looking at.
  String? _currentRoomId;

  // * Emits a roomId whenever that room's membership changes (a member is
  // * removed or has their role changed). The open members sheet listens to
  // * this to reload itself live, scoped to its own room.
  final StreamController<String> _roomMembersChangedController =
      StreamController<String>.broadcast();
  Stream<String> get roomMembersChanged => _roomMembersChangedController.stream;

  bool get isConnected => _socket.connected;

  SocketProvider({
    required AuthProvider authProvider,
    required EventsProvider eventsProvider,
    required PlaylistsProvider playlistsProvider,
    required RoomsProvider roomsProvider,
    required PlayerProvider playerProvider,
    required FriendsProvider friendsProvider,
    required NotificationsProvider notificationsProvider,
    io.Socket? socket,
  }) : _authProvider = authProvider,
       _friendsProvider = friendsProvider,
       _notificationsProvider = notificationsProvider {
    _authProvider.addListener(_onAuthChanged);
    _initializeSocket(
      eventsProvider,
      playlistsProvider,
      roomsProvider,
      playerProvider,
      socket,
    );
  }

  // * Retrieve token and inject it into Socket.IO handshake before connecting.
  Future<void> _connectSocket() async {
    final token = await _authProvider.accessToken;
    if (token != null) {
      // * auth handshake map — preferred over header / query string.
      _socket.io.options?['auth'] = {'token': token};
    }
    _socket.connect();
    // * Fetch notifications on connection/login to populate the badge count immediately.
    _notificationsProvider.fetchNotifications();
  }

  void _onAuthChanged() {
    if (_authProvider.signedIn) {
      _connectSocket();
    } else {
      _socket.disconnect();
    }
  }

  void _initializeSocket(
    EventsProvider eventsProvider,
    PlaylistsProvider playlistsProvider,
    RoomsProvider roomsProvider,
    PlayerProvider playerProvider,
    io.Socket? injectedSocket,
  ) {
    // ! Connect to backend WebSocket endpoint defined in ApiConfig
    _socket =
        injectedSocket ??
        io.io(ApiConfig.wsUrl, <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
        });

    _socket.on('connect', (_) {
      // * Connected – notify listeners for UI if needed
      notifyListeners();
    });

    // * Realtime notification/friends events
    _socket.on('friend:request:new', (_) {
      _notificationsProvider.fetchNotifications();
      _showNotificationSnackBar('New friend request received!', routeFriends);
    });
    _socket.on('friend:request:accepted', (_) {
      _notificationsProvider.fetchNotifications();
      _friendsProvider.fetchFriendsData();
      _showNotificationSnackBar('Friend request accepted!', routeFriends);
    });
    _socket.on('friend:request:declined', (_) {
      _notificationsProvider.fetchNotifications();
      _friendsProvider.fetchFriendsData();
    });
    _socket.on('friend:request:canceled', (_) {
      _notificationsProvider.fetchNotifications();
      _friendsProvider.fetchFriendsData();
    });
    _socket.on('friend:removed', (_) {
      _notificationsProvider.fetchNotifications();
      _friendsProvider.fetchFriendsData();
    });
    _socket.on('invitation:new', (data) {
      _notificationsProvider.fetchNotifications();
      String roomSuffix = '';
      if (data is Map && data['roomName'] != null) {
        roomSuffix = ' to join ${data['roomName']}';
      }
      _showNotificationSnackBar(
        'New room invitation received$roomSuffix!',
        routeFriends,
      );
    });
    _socket.on('invitation:declined', (_) {
      _notificationsProvider.fetchNotifications();
    });
    _socket.on('invitation:revoked', (_) {
      _notificationsProvider.fetchNotifications();
    });

    // * Playlist events
    _socket.on('playlist:item-added', (data) {
      final track = _trackFromJson(data);
      playlistsProvider.handleTrackAdded(track);
    });
    _socket.on('playlist:item-moved', (data) {
      final roomId = data['roomId'] as String? ?? '';
      final trackId = data['trackId'] as String? ?? '';
      final position = data['position'] as String? ?? '';
      playlistsProvider.handleTrackMoved(roomId, trackId, position);
    });
    _socket.on('playlist:item-removed', (data) {
      final trackId = data['trackId'] as String? ?? '';
      playlistsProvider.handleTrackRemoved(trackId);
    });

    // * Vote room events (forward to EventsProvider)
    _socket.on('track:added', (data) {
      final track = _trackFromJson(data);
      eventsProvider.handleTrackAdded(track);
    });
    _socket.on('track:voted', (data) {
      final trackId = data['trackId'] as String? ?? '';
      final score = data['score'] as int? ?? 0;
      final votes = data['votesCount'] as int? ?? 0; // currently unused
      eventsProvider.handleTrackVoted(trackId, score, votes);
    });

    // * Room membership events
    _socket.on('member:joined', (data) {
      final roomId = data['roomId'] as String? ?? '';
      final userId = data['userId'] as String? ?? '';
      roomsProvider.handleMemberJoined(roomId, userId);
    });
    _socket.on('member:left', (data) {
      final roomId = data['roomId'] as String? ?? '';
      final userId = data['userId'] as String? ?? '';
      roomsProvider.handleMemberLeft(roomId, userId);
    });
    _socket.on('member:removed', (data) {
      final roomId = data['roomId'] as String? ?? '';
      final userId = data['userId'] as String? ?? '';
      roomsProvider.handleMemberLeft(roomId, userId);
      if (roomId.isNotEmpty) _roomMembersChangedController.add(roomId);
    });
    _socket.on('member:role-changed', (data) {
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) _roomMembersChangedController.add(roomId);
    });

    // * We were removed from a room (kicked by an admin, or the room was
    // * deleted by its owner). Drop it from both lists + the inbox, and if we
    // * are currently inside that very room, leave the now-dead detail screen.
    _socket.on('room:kicked', (data) {
      String roomId = '';
      String roomName = '';
      if (data is Map) {
        roomId = data['roomId'] as String? ?? '';
        roomName = data['roomName'] as String? ?? '';
      }
      playlistsProvider.fetchPlaylists();
      eventsProvider.fetchEvents();
      _notificationsProvider.fetchNotifications();
      if (roomId.isNotEmpty && _currentRoomId == roomId) {
        _currentRoomId = null;
        final router = AppRouter.router;
        if (router.canPop()) router.pop();
      }
      _showRoomKickedSnackBar(roomName);
    });

    // * Playback (vote queue progression). The back drives "now playing" via
    // * track:nowPlaying; delegated play/pause/next/volume arrive via
    // * playback:command (handled by the delegation feature, T9).
    // * The old playbackPaused/Skipped/VolumeChanged events are gone — the
    // * Deezer/relay back never emits them.
    _socket.on('track:nowPlaying', (data) {
      final track = _trackFromJson(data['track']);
      playerProvider.handlePlaybackPlayed(track);
    });

    _socket.on('playback:command', (data) {
      if (data is Map) {
        playerProvider.handlePlaybackCommand(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('device:delegation:granted', (data) {
      if (data is Map) {
        final deviceId = data['deviceId'] as String?;
        final ownerId = data['ownerId'] as String?;
        if (deviceId != null && ownerId != null) {
          playerProvider.handleDelegationGranted(deviceId, ownerId);
        }
      }
    });

    _socket.on('device:delegation:revoked', (data) {
      if (data is Map) {
        final deviceId = data['deviceId'] as String?;
        final ownerId = data['ownerId'] as String?;
        if (deviceId != null && ownerId != null) {
          playerProvider.handleDelegationRevoked(deviceId, ownerId);
        }
      }
    });

    // * Finally, connect if signed in
    if (_authProvider.signedIn) {
      _connectSocket();
    }
  }

  // * Helper to convert raw JSON into a Track model
  Track _trackFromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return Track.fromJson(json);
    }
    // Fallback – create empty placeholder to avoid crashes
    return Track(
      id: json['id'] ?? 'unknown',
      providerId: json['providerId'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      durationMs: json['durationMs'] ?? 0,
    );
  }

  // * Room Presence Controls
  void joinRoom(String roomId) {
    _currentRoomId = roomId;
    if (isConnected) {
      _socket.emit('room:join', {'roomId': roomId});
    }
  }

  void leaveRoom(String roomId) {
    if (_currentRoomId == roomId) _currentRoomId = null;
    if (isConnected) {
      _socket.emit('room:leave', {'roomId': roomId});
    }
  }

  void disposeSocket() {
    _authProvider.removeListener(_onAuthChanged);
    _roomMembersChangedController.close();
    _socket.disconnect();
    super.dispose();
  }

  // * Informational snackbar (no "View" action) shown when we are removed
  // * from a room — the room no longer exists for us, so there is nowhere to
  // * navigate to.
  void _showRoomKickedSnackBar(String roomName) {
    final context = rootScaffoldMessengerKey.currentContext;
    if (context == null) return;
    final theme = Theme.of(context);
    final suffix = roomName.isNotEmpty ? ' "$roomName"' : '';
    rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'You were removed from$suffix',
          style: TextStyle(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: theme.colorScheme.secondaryContainer,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // * Helper to show in-app notification snackbars globally
  void _showNotificationSnackBar(String message, String routePath) {
    final context = rootScaffoldMessengerKey.currentContext;
    if (context == null) return;

    final theme = Theme.of(context);

    rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: theme.colorScheme.secondaryContainer,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          textColor: theme.colorScheme.primary,
          label: 'View',
          onPressed: () {
            AppRouter.router.push(routePath);
          },
        ),
      ),
    );
  }
}
