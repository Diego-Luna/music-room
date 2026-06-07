// * Model representing a room invitation from the backend
class RoomInvitationDto {
  final String id;
  final String roomId;
  final String inviterId;
  final String inviteeId;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? respondedAt;

  RoomInvitationDto({
    required this.id,
    required this.roomId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    this.expiresAt,
    required this.createdAt,
    this.respondedAt,
  });

  factory RoomInvitationDto.fromJson(Map<String, dynamic> json) {
    return RoomInvitationDto(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      inviterId: json['inviterId'] as String,
      inviteeId: json['inviteeId'] as String,
      status: json['status'] as String,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roomId': roomId,
    'inviterId': inviterId,
    'inviteeId': inviteeId,
    'status': status,
    'expiresAt': expiresAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
  };
}

// * Result of accepting an invitation
class AcceptInvitationResultDto {
  final String message;
  final String? roomId;

  AcceptInvitationResultDto({required this.message, this.roomId});

  factory AcceptInvitationResultDto.fromJson(Map<String, dynamic> json) {
    return AcceptInvitationResultDto(
      message: json['message'] as String? ?? 'Joined',
      roomId: json['roomId'] as String?,
    );
  }
}
