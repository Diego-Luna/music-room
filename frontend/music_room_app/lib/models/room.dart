import 'package:music_room_app/models/track.dart';

// * The same like the backend `Room.kind`
enum RoomKind {
  vote,
  playlist,
  delegate;

  static RoomKind fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'PLAYLIST':
        return RoomKind.playlist;
      case 'DELEGATE':
        return RoomKind.delegate;
      default:
        return RoomKind.vote;
    }
  }

  String toJson() => name.toUpperCase();
}

class Room {
  final String id;
  final String name;
  final String ownerId;
  final RoomKind kind;
  final bool isPublic;
  final DateTime createdAt;

  // * Tracks list is for used by VOTE and PLAYLIST rooms
  final List<Track> tracks;

  // * DJ/admins/owners delegation is for DELEGATE rooms
  final String? currentControllerId;

  Room({
    required this.id,
    required this.name,
    required this.ownerId,
    this.kind = RoomKind.vote,
    this.isPublic = true,
    this.tracks = const [],
    this.currentControllerId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      // * Backend sends 'PUBLIC' / 'PRIVATE' is a bool
      kind: RoomKind.fromString(json['kind'] as String?),
      isPublic: (json['visibility'] as String?) != 'PRIVATE',
      tracks: (json['tracks'] as List? ?? [])
          .map((t) => Track.fromJson(t))
          .toList(),
      currentControllerId:
          (json['currentControllerId'] ?? json['delegateUserId']) as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'kind': kind.toJson(),
    // * Frontend bool maps to backend enum string
    'visibility': isPublic ? 'PUBLIC' : 'PRIVATE',
    'tracks': tracks.map((t) => t.toJson()).toList(),
    if (currentControllerId != null) 'currentControllerId': currentControllerId,
    'createdAt': createdAt.toIso8601String(),
  };

  Room copyWith({
    String? name,
    RoomKind? kind,
    bool? isPublic,
    List<Track>? tracks,
    String? currentControllerId,
  }) {
    return Room(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      kind: kind ?? this.kind,
      isPublic: isPublic ?? this.isPublic,
      tracks: tracks ?? this.tracks,
      currentControllerId: currentControllerId ?? this.currentControllerId,
      createdAt: createdAt,
    );
  }
}
