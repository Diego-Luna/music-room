// We are gona use for the Events and Room with extends
abstract class BaseSession {
  final String id;
  final String name;
  final String ownerId;
  final bool isPublic;
  final DateTime createdAt;

  BaseSession({
    required this.id,
    required this.name,
    required this.ownerId,
    this.isPublic = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'isPublic': isPublic,
    'createdAt': createdAt.toIso8601String(),
  };
}
