import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/rooms_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';

// * Central provider for managing WebSocket connection and forwarding events
class SocketProvider extends ChangeNotifier {
  late final IO.Socket _socket;
  final AuthProvider _authProvider;

  bool get isConnected => _socket.connected;

  SocketProvider({
    required AuthProvider authProvider,
    required EventsProvider eventsProvider,
    required PlaylistsProvider playlistsProvider,
    required RoomsProvider roomsProvider,
    required PlayerProvider playerProvider,
  }) : _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
    _initializeSocket(
      eventsProvider,
      playlistsProvider,
      roomsProvider,
      playerProvider,
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
  ) {
    // ! Connect to backend WebSocket endpoint defined in ApiConfig
    _socket = IO.io(ApiConfig.wsUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.on('connect', (_) {
      // * Connected – notify listeners for UI if needed
      notifyListeners();
    });

    // * Playlist events
    _socket.on('trackAdded', (data) {
      final track = _trackFromJson(data);
      playlistsProvider.handleTrackAdded(track);
    });
    _socket.on('trackMoved', (data) {
      final roomId = data['roomId'] as String? ?? '';
      final trackId = data['trackId'] as String? ?? '';
      final newPos = data['newPosition'] as String? ?? '';
      playlistsProvider.handleTrackMoved(roomId, trackId, newPos);
    });
    _socket.on('trackRemoved', (data) {
      final trackId = data['trackId'] as String? ?? '';
      playlistsProvider.handleTrackRemoved(trackId);
    });

    // * Vote room events (forward to EventsProvider)
    _socket.on('eventTrackAdded', (data) {
      final track = _trackFromJson(data);
      eventsProvider.handleTrackAdded(track);
    });
    _socket.on('eventTrackVoted', (data) {
      final trackId = data['trackId'] as String? ?? '';
      final score = data['score'] as int? ?? 0;
      final votes = data['votesCount'] as int? ?? 0; // currently unused
      eventsProvider.handleTrackVoted(trackId, score, votes);
    });
    _socket.on('eventTrackRemoved', (data) {
      final trackId = data['trackId'] as String? ?? '';
      eventsProvider.handleTrackRemoved(trackId);
    });

    // * Delegate / room control events
    _socket.on('delegateUpdated', (data) {
      final roomId = data['roomId'] as String? ?? '';
      final controllerId = data['controllerId'] as String?; // may be null
      roomsProvider.handleDelegateUpdated(roomId, controllerId);
    });
    _socket.on('djRoleGranted', (data) {
      final roomId = data['roomId'] as String? ?? '';
      final userId = data['userId'] as String? ?? '';
      roomsProvider.handleDJRoleGranted(roomId, userId);
    });
    _socket.on('memberJoined', (data) {
      final roomId = data['roomId'] as String? ?? '';
      final userId = data['userId'] as String? ?? '';
      roomsProvider.handleMemberJoined(roomId, userId);
    });
    _socket.on('memberLeft', (data) {
      final roomId = data['roomId'] as String? ?? '';
      final userId = data['userId'] as String? ?? '';
      roomsProvider.handleMemberLeft(roomId, userId);
    });

    // * Playback events
    _socket.on('playbackPlayed', (data) {
      final track = _trackFromJson(data);
      playerProvider.handlePlaybackPlayed(track);
    });
    _socket.on('playbackPaused', (_) {
      playerProvider.handlePlaybackPaused();
    });
    _socket.on('playbackSkipped', (data) {
      final track = _trackFromJson(data);
      playerProvider.handlePlaybackSkipped(track);
    });
    _socket.on('playbackVolumeChanged', (data) {
      final vol = (data['volume'] as num?)?.toDouble() ?? 1.0;
      playerProvider.handlePlaybackVolumeChanged(vol);
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

  void disposeSocket() {
    _authProvider.removeListener(_onAuthChanged);
    _socket.disconnect();
    super.dispose();
  }
}
