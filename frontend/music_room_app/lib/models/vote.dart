class Vote {
  final String userId;
  final String eventId;
  final String trackId;
  final DateTime createdAt;

  Vote({
    required this.userId,
    required this.eventId,
    required this.trackId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      userId: json['userId'] as String,
      eventId: json['eventId'] as String,
      trackId: json['trackId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'eventId': eventId,
    'trackId': trackId,
    'createdAt': createdAt.toIso8601String(),
  };
}
