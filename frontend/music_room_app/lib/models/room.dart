import 'package:music_room_app/models/track.dart';

const _keep = Object();

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

  // * Caller's membership on this room. Null when they only see a public room.
  // * OWNER | ADMIN | MEMBER.
  final String? myRole;
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

  // * Track the room is playing right now. Votes on it are locked.
  final String? currentTrackId;

  // * Shared clock. Position is now - startedAt, frozen while pausedAt is set.
  final DateTime? currentTrackStartedAt;
  final DateTime? playbackPausedAt;

  Room({
    required this.id,
    required this.name,
    required this.ownerId,
    this.myRole,
    this.kind = RoomKind.vote,
    this.isPublic = true,
    this.description,
    this.editAccess,
    this.voteAccess,
    this.voteLocationLat,
    this.voteLocationLng,
    this.voteLocationRadiusM,
    this.tracks = const [],
    this.currentTrackId,
    this.currentTrackStartedAt,
    this.playbackPausedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isGeoGated =>
      voteLocationLat != null &&
      voteLocationLng != null &&
      voteLocationRadiusM != null;

  // * Yours when the server says so, or when this account owns the room.
  // * Create responses and GET /rooms/:id omit myRole, which otherwise
  // * dumped a room the user just made into Discover (or nowhere).
  bool ownedBy(String? userId) =>
      myRole == 'OWNER' ||
      (userId != null && userId.isNotEmpty && ownerId == userId);

  bool joinedBy(String? userId) =>
      !ownedBy(userId) && (myRole == 'MEMBER' || myRole == 'ADMIN');

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      myRole: json['myRole'] as String?,
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
      currentTrackId: json['currentTrackId'] as String?,
      currentTrackStartedAt: json['currentTrackStartedAt'] != null
          ? DateTime.parse(json['currentTrackStartedAt'] as String)
          : null,
      playbackPausedAt: json['playbackPausedAt'] != null
          ? DateTime.parse(json['playbackPausedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    if (myRole != null) 'myRole': myRole,
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
    if (currentTrackId != null) 'currentTrackId': currentTrackId,
    if (currentTrackStartedAt != null)
      'currentTrackStartedAt': currentTrackStartedAt!.toIso8601String(),
    if (playbackPausedAt != null)
      'playbackPausedAt': playbackPausedAt!.toIso8601String(),
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
    Object? myRole = _keep,
    Object? currentTrackId = _keep,
    Object? currentTrackStartedAt = _keep,
    Object? playbackPausedAt = _keep,
  }) {
    return Room(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      myRole: identical(myRole, _keep) ? this.myRole : myRole as String?,
      kind: kind ?? this.kind,
      isPublic: isPublic ?? this.isPublic,
      description: description ?? this.description,
      editAccess: editAccess ?? this.editAccess,
      voteAccess: voteAccess ?? this.voteAccess,
      voteLocationLat: voteLocationLat ?? this.voteLocationLat,
      voteLocationLng: voteLocationLng ?? this.voteLocationLng,
      voteLocationRadiusM: voteLocationRadiusM ?? this.voteLocationRadiusM,
      tracks: tracks ?? this.tracks,
      currentTrackId: identical(currentTrackId, _keep)
          ? this.currentTrackId
          : currentTrackId as String?,
      currentTrackStartedAt: identical(currentTrackStartedAt, _keep)
          ? this.currentTrackStartedAt
          : currentTrackStartedAt as DateTime?,
      playbackPausedAt: identical(playbackPausedAt, _keep)
          ? this.playbackPausedAt
          : playbackPausedAt as DateTime?,
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
