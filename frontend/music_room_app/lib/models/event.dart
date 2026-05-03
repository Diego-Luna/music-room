import 'package:music_room_app/models/event_track.dart';

class Event {
  final String id;
  final String name;
  final String ownerId;
  final bool isPublic;
  final List<EventTrack> tracks;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.name,
    required this.ownerId,
    this.isPublic = true,
    this.tracks = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'isPublic': isPublic,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
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
