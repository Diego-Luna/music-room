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
    IO.Socket? socket,
  }) : _authProvider = authProvider {
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
    IO.Socket? injectedSocket,
  ) {
    // ! Connect to backend WebSocket endpoint defined in ApiConfig
    _socket =
        injectedSocket ??
        IO.io(ApiConfig.wsUrl, <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
        });

    _socket.on('connect', (_) {
      // * Connected – notify listeners for UI if needed
      notifyListeners();
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
    _socket.on('track:removed', (data) {
      final trackId = data['trackId'] as String? ?? '';
      eventsProvider.handleTrackRemoved(trackId);
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

    // * Playback (vote queue progression). The back drives "now playing" via
    // * track:nowPlaying; delegated play/pause/next/volume arrive via
    // * playback:command (handled by the delegation feature, T9).
    // * The old playbackPaused/Skipped/VolumeChanged events are gone — the
    // * Deezer/relay back never emits them.
    _socket.on('track:nowPlaying', (data) {
      final track = _trackFromJson(data['track']);
      playerProvider.handlePlaybackPlayed(track);
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
    if (isConnected) {
      _socket.emit('room:join', {'roomId': roomId});
    }
  }

  void leaveRoom(String roomId) {
    if (isConnected) {
      _socket.emit('room:leave', {'roomId': roomId});
    }
  }

  void disposeSocket() {
    _authProvider.removeListener(_onAuthChanged);
    _socket.disconnect();
    super.dispose();
  }
}
