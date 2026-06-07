// * A membership record inside a room (V.2.3 member management).
// * Mirrors the backend RoomMemberDto: { id, roomId, userId, role, joinedAt }.

enum RoomMemberRole { owner, admin, member }

RoomMemberRole roomMemberRoleFromString(String raw) {
  switch (raw.toUpperCase()) {
    case 'OWNER':
      return RoomMemberRole.owner;
    case 'ADMIN':
      return RoomMemberRole.admin;
    default:
      return RoomMemberRole.member;
  }
}

// * Only ADMIN/MEMBER are assignable via PATCH .../role (OWNER is never set
// * through this endpoint — ownership is not transferable here).
String roomMemberRoleToApi(RoomMemberRole role) {
  switch (role) {
    case RoomMemberRole.admin:
      return 'ADMIN';
    case RoomMemberRole.member:
    case RoomMemberRole.owner:
      return 'MEMBER';
  }
}

String roomMemberRoleLabel(RoomMemberRole role) {
  switch (role) {
    case RoomMemberRole.owner:
      return 'Owner';
    case RoomMemberRole.admin:
      return 'Admin';
    case RoomMemberRole.member:
      return 'Member';
  }
}

class RoomMember {
  final String id;
  final String roomId;
  final String userId;
  final RoomMemberRole role;
  final DateTime joinedAt;

  RoomMember({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      role: roomMemberRoleFromString(json['role'] as String),
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }

  RoomMember copyWith({RoomMemberRole? role}) => RoomMember(
    id: id,
    roomId: roomId,
    userId: userId,
    role: role ?? this.role,
    joinedAt: joinedAt,
  );
}
