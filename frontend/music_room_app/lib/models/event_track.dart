import 'package:music_room_app/models/track.dart';

class EventTrack {
  final String id;
  final String eventId;
  final String trackId;
  final int voteCount;
  final bool hasVoted; // Client-side flag for the current user
  final Track? track; // Optional nested track details

  EventTrack({
    required this.id,
    required this.eventId,
    required this.trackId,
    this.voteCount = 0,
    this.hasVoted = false,
    this.track,
  });

  factory EventTrack.fromJson(Map<String, dynamic> json) {
    return EventTrack(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      trackId: json['trackId'] as String,
      voteCount: json['voteCount'] as int? ?? 0,
      hasVoted: json['hasVoted'] as bool? ?? false,
      track: json['track'] != null ? Track.fromJson(json['track']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'trackId': trackId,
    'voteCount': voteCount,
    'hasVoted': hasVoted,
    if (track != null) 'track': track!.toJson(),
  };

  EventTrack copyWith({int? voteCount, bool? hasVoted}) {
    return EventTrack(
      id: id,
      eventId: eventId,
      trackId: trackId,
      voteCount: voteCount ?? this.voteCount,
      hasVoted: hasVoted ?? this.hasVoted,
      track: track,
    );
  }
}
