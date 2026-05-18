import 'package:music_room_app/models/base_session.dart';
import 'package:music_room_app/models/event_track.dart';

class Event extends BaseSession {
  final List<EventTrack> tracks;

  Event({
    required super.id,
    required super.name,
    required super.ownerId,
    super.isPublic = true,
    this.tracks = const [],
    super.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      isPublic: json['isPublic'] as bool? ?? true,
      tracks: (json['tracks'] as List? ?? [])
          .map((t) => EventTrack.fromJson(t))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'tracks': tracks.map((t) => t.toJson()).toList(),
  };

  Event copyWith({String? name, bool? isPublic, List<EventTrack>? tracks}) {
    return Event(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      isPublic: isPublic ?? this.isPublic,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt,
    );
  }
}
