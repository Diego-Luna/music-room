import 'package:music_room_app/models/playlist_track.dart';

class Playlist {
  final String id;
  final String name;
  final String ownerId;
  final bool isPublic;
  final List<PlaylistTrack> tracks;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.ownerId,
    this.isPublic = true,
    this.tracks = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      isPublic: json['isPublic'] as bool? ?? true,
      tracks: (json['tracks'] as List? ?? [])
          .map((t) => PlaylistTrack.fromJson(t))
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

  Playlist copyWith({String? name, bool? isPublic, List<PlaylistTrack>? tracks}) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      isPublic: isPublic ?? this.isPublic,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt,
    );
  }
}
