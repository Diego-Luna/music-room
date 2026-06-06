// * This class is for the delegating the control of the music playback
class MusicControlDelegation {
  final String id;
  final String ownerId;
  final String deviceId;
  final String delegateUserId;
  final DateTime grantedAt;

  MusicControlDelegation({
    required this.id,
    required this.ownerId,
    required this.deviceId,
    required this.delegateUserId,
    required this.grantedAt,
  });

  // * This method is for create a new MusicControlDelegation from a JSON
  factory MusicControlDelegation.fromJson(Map<String, dynamic> json) {
    return MusicControlDelegation(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      deviceId: json['deviceId'] as String,
      delegateUserId: json['delegateUserId'] as String,
      grantedAt: DateTime.parse(json['grantedAt'] as String),
    );
  }

  // * This method is for convert a MusicControlDelegation to a JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'deviceId': deviceId,
    'delegateUserId': delegateUserId,
    'grantedAt': grantedAt.toIso8601String(),
  };
}
