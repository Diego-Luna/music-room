class FriendshipDto {
  final String id;
  final String requesterId;
  final String addresseeId;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  FriendshipDto({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory FriendshipDto.fromJson(Map<String, dynamic> json) {
    return FriendshipDto(
      id: json['id'] as String,
      requesterId: json['requesterId'] as String,
      addresseeId: json['addresseeId'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'requesterId': requesterId,
    'addresseeId': addresseeId,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
  };
}

class FriendDto {
  final String friendshipId;
  final String friendId;
  final DateTime? since;

  FriendDto({required this.friendshipId, required this.friendId, this.since});

  factory FriendDto.fromJson(Map<String, dynamic> json) {
    return FriendDto(
      friendshipId: json['friendshipId'] as String,
      friendId: json['friendId'] as String,
      since: json['since'] != null
          ? DateTime.parse(json['since'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'friendshipId': friendshipId,
    'friendId': friendId,
    'since': since?.toIso8601String(),
  };
}
