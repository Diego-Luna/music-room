import 'package:music_room_app/models/track.dart';

class PlaylistTrack {
  final String id;
  final String playlistId;
  final String trackId;
  final int position;
  final Track? track;

  PlaylistTrack({
    required this.id,
    required this.playlistId,
    required this.trackId,
    required this.position,
    this.track,
  });

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) {
    return PlaylistTrack(
      id: json['id'] as String,
      playlistId: json['playlistId'] as String,
      trackId: json['trackId'] as String,
      position: json['position'] as int,
      track: json['track'] != null ? Track.fromJson(json['track']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'playlistId': playlistId,
    'trackId': trackId,
    'position': position,
    if (track != null) 'track': track!.toJson(),
  };
}
