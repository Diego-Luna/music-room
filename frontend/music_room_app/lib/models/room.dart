import 'package:music_room_app/models/track.dart';

// * The same like the backend `Room.kind`
enum RoomKind {
  vote,
  playlist;

  static RoomKind fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'PLAYLIST':
        return RoomKind.playlist;
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

  // * Editable settings (V.2.3 / V.3.2). 'EVERYONE' | 'INVITED_ONLY'.
  final String? description;
  final String? editAccess;
  final String? voteAccess;

  // * V.2.1 location licence — when all three are set, votes need lat/lng.
  final double? voteLocationLat;
  final double? voteLocationLng;
  final double? voteLocationRadiusM;

  // * Tracks list is for used by VOTE and PLAYLIST rooms
  final List<Track> tracks;

  Room({
    required this.id,
    required this.name,
    required this.ownerId,
    this.kind = RoomKind.vote,
    this.isPublic = true,
    this.description,
    this.editAccess,
    this.voteAccess,
    this.voteLocationLat,
    this.voteLocationLng,
    this.voteLocationRadiusM,
    this.tracks = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isGeoGated =>
      voteLocationLat != null &&
      voteLocationLng != null &&
      voteLocationRadiusM != null;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      // * Backend sends 'PUBLIC' / 'PRIVATE' is a bool
      kind: RoomKind.fromString(json['kind'] as String?),
      isPublic: (json['visibility'] as String?) != 'PRIVATE',
      description: json['description'] as String?,
      editAccess: json['editAccess'] as String?,
      voteAccess: json['voteAccess'] as String?,
      voteLocationLat: (json['voteLocationLat'] as num?)?.toDouble(),
      voteLocationLng: (json['voteLocationLng'] as num?)?.toDouble(),
      voteLocationRadiusM: (json['voteLocationRadiusM'] as num?)?.toDouble(),
      tracks: (json['tracks'] as List? ?? [])
          .map((t) => Track.fromJson(t))
          .toList(),
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
    if (description != null) 'description': description,
    if (editAccess != null) 'editAccess': editAccess,
    if (voteAccess != null) 'voteAccess': voteAccess,
    if (voteLocationLat != null) 'voteLocationLat': voteLocationLat,
    if (voteLocationLng != null) 'voteLocationLng': voteLocationLng,
    if (voteLocationRadiusM != null) 'voteLocationRadiusM': voteLocationRadiusM,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  Room copyWith({
    String? name,
    RoomKind? kind,
    bool? isPublic,
    String? description,
    String? editAccess,
    String? voteAccess,
    double? voteLocationLat,
    double? voteLocationLng,
    double? voteLocationRadiusM,
    List<Track>? tracks,
  }) {
    return Room(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      kind: kind ?? this.kind,
      isPublic: isPublic ?? this.isPublic,
      description: description ?? this.description,
      editAccess: editAccess ?? this.editAccess,
      voteAccess: voteAccess ?? this.voteAccess,
      voteLocationLat: voteLocationLat ?? this.voteLocationLat,
      voteLocationLng: voteLocationLng ?? this.voteLocationLng,
      voteLocationRadiusM: voteLocationRadiusM ?? this.voteLocationRadiusM,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
