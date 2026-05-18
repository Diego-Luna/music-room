import 'package:music_room_app/models/base_session.dart';

class Room extends BaseSession {
  final String? currentControllerId;
  final List<String> connectedUsers;

  Room({
    required super.id,
    required super.name,
    required super.ownerId,
    super.isPublic = true,
    this.currentControllerId,
    this.connectedUsers = const [],
    super.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      isPublic: json['isPublic'] as bool? ?? true,
      currentControllerId: json['currentControllerId'] as String?,
      connectedUsers: (json['connectedUsers'] as List? ?? [])
          .map((u) => u as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'currentControllerId': currentControllerId,
    'connectedUsers': connectedUsers,
  };

  Room copyWith({
    String? name,
    bool? isPublic,
    String? currentControllerId,
    List<String>? connectedUsers,
  }) {
    return Room(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      isPublic: isPublic ?? this.isPublic,
      currentControllerId: currentControllerId ?? this.currentControllerId,
      connectedUsers: connectedUsers ?? this.connectedUsers,
      createdAt: createdAt,
    );
  }
}
