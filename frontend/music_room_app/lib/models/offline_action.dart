// * Model representing a mutation queued when offline
class OfflineAction {
  final String id;
  final String roomId;
  final String type; // * 'vote' | 'addPlaylistTrack' (legacy 'addTrack') | 'addVoteTrack' | 'removePlaylistTrack' | 'move'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  OfflineAction({
    required this.id,
    required this.roomId,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'roomId': roomId,
    'type': type,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
  };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    type: json['type'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
