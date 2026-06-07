import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/models/invitation.dart';

// * REST implementation NestJS backend API
class RestApiRepository implements RoomRepository {
  final ApiClient _client;

  RestApiRepository({required ApiClient client}) : _client = client;

  // Rooms
  @override
  Future<List<Room>> getRooms({RoomKind? kind}) async {
    final response = await _client.get(
      ApiConfig.rooms,
      queryParameters: kind != null ? {'kind': kind.toJson()} : null,
    );
    final data = response.data as List;
    return data.map((json) => Room.fromJson(json)).toList();
  }

  @override
  Future<Room> getRoomById(String id) async {
    final response = await _client.get('${ApiConfig.rooms}/$id');
    return Room.fromJson(response.data);
  }

  @override
  Future<Room> createRoom({
    required String name,
    required RoomKind kind,
    required bool isPublic,
    String? description,
    String? voteAccess,
    String? voteWindow,
    DateTime? voteStartsAt,
    DateTime? voteEndsAt,
    double? voteLocationLat,
    double? voteLocationLng,
    double? voteLocationRadiusM,
  }) async {
    final response = await _client.post(
      ApiConfig.rooms,
      data: {
        'name': name,
        'kind': kind.toJson(),
        'visibility': isPublic ? 'PUBLIC' : 'PRIVATE',
        'description': ?description,
        'voteAccess': ?voteAccess,
        'voteWindow': ?voteWindow,
        if (voteStartsAt != null)
          'voteStartsAt': voteStartsAt.toIso8601String(),
        if (voteEndsAt != null) 'voteEndsAt': voteEndsAt.toIso8601String(),
        'voteLocationLat': ?voteLocationLat,
        'voteLocationLng': ?voteLocationLng,
        'voteLocationRadiusM': ?voteLocationRadiusM,
      },
    );
    return Room.fromJson(response.data);
  }

  @override
  Future<void> deleteRoom(String id) async {
    await _client.delete('${ApiConfig.rooms}/$id');
  }

  @override
  Future<void> joinRoom(String id) async {
    await _client.post('${ApiConfig.rooms}/$id/join');
  }

  @override
  Future<void> leaveRoom(String id) async {
    await _client.post('${ApiConfig.rooms}/$id/leave');
  }

  // VOTE room
  @override
  Future<List<Track>> getVoteTracks(String roomId) async {
    final response = await _client.get('${ApiConfig.rooms}/$roomId/tracks');
    final data = response.data as List;
    return data.map((json) => Track.fromJson(json)).toList();
  }

  @override
  Future<Track> addVoteTrack(String roomId, Track track) async {
    final response = await _client.post(
      '${ApiConfig.rooms}/$roomId/tracks',
      data: {
        'providerId': track.providerId,
        'provider': track.provider,
        'title': track.title,
        'artist': track.artist,
        'durationMs': track.durationMs,
        if (track.artworkUrl != null) 'artworkUrl': track.artworkUrl,
        if (track.previewUrl != null) 'previewUrl': track.previewUrl,
      },
    );
    return Track.fromJson(response.data);
  }

  @override
  Future<void> voteForTrack(
    String roomId,
    String trackId,
    int value, {
    double? lat,
    double? lng,
  }) async {
    await _client.post(
      '${ApiConfig.rooms}/$roomId/tracks/$trackId/vote',
      data: {'value': value, 'lat': ?lat, 'lng': ?lng},
    );
  }

  @override
  Future<void> removeVoteTrack(String roomId, String trackId) async {
    await _client.delete('${ApiConfig.rooms}/$roomId/tracks/$trackId');
  }

  // PLAYLIST room
  @override
  Future<List<Track>> getPlaylistTracks(String roomId) async {
    final response = await _client.get('${ApiConfig.rooms}/$roomId/playlist');
    final data = response.data as List;
    return data.map((json) => Track.fromJson(json)).toList();
  }

  @override
  Future<Track> addPlaylistTrack(String roomId, Track track) async {
    final response = await _client.post(
      '${ApiConfig.rooms}/$roomId/playlist',
      data: {
        'providerId': track.providerId,
        'provider': track.provider,
        'title': track.title,
        'artist': track.artist,
        'durationMs': track.durationMs,
        if (track.artworkUrl != null) 'artworkUrl': track.artworkUrl,
        if (track.previewUrl != null) 'previewUrl': track.previewUrl,
      },
    );
    return Track.fromJson(response.data);
  }

  @override
  Future<void> movePlaylistTrack(
    String roomId,
    String trackId,
    String newPosition,
  ) async {
    await _client.patch(
      '${ApiConfig.rooms}/$roomId/playlist/$trackId/move',
      data: {'newPosition': newPosition},
    );
  }

  @override
  Future<void> removePlaylistTrack(String roomId, String trackId) async {
    await _client.delete('${ApiConfig.rooms}/$roomId/playlist/$trackId');
  }

  @override
  Future<List<Track>> searchTracks(String query) async {
    final response = await _client.get(
      ApiConfig.search,
      queryParameters: {'q': query},
    );
    final data = response.data as List;
    return data.map((json) {
      // Back (Deezer) returns: providerId, title, artist, durationMs,
      // artworkUrl, previewUrl. We key our local id on providerId.
      final providerId = json['providerId'] as String;
      return Track(
        id: providerId,
        providerId: providerId,
        provider: 'deezer',
        title: json['title'] as String,
        artist: json['artist'] as String,
        durationMs: json['durationMs'] as int,
        artworkUrl: json['artworkUrl'] as String?,
        previewUrl: json['previewUrl'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> inviteToRoom(String roomId, String userId) async {
    await _client.post(
      '${ApiConfig.rooms}/$roomId/invitations',
      data: {'userId': userId},
    );
  }

  @override
  Future<List<RoomInvitationDto>> getInvitations() async {
    final response = await _client.get('/users/me/invitations');
    final data = response.data as List;
    return data.map((json) => RoomInvitationDto.fromJson(json)).toList();
  }

  @override
  Future<AcceptInvitationResultDto> acceptInvitation(
    String invitationId,
  ) async {
    final response = await _client.post(
      '/users/me/invitations/$invitationId/accept',
    );
    return AcceptInvitationResultDto.fromJson(response.data);
  }

  @override
  Future<RoomInvitationDto> declineInvitation(String invitationId) async {
    final response = await _client.post(
      '/users/me/invitations/$invitationId/decline',
    );
    return RoomInvitationDto.fromJson(response.data);
  }
}
