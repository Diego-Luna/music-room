import 'music_control_delegation.dart';

class AccountDevice {
  final String deviceId;
  final String? userAgent;
  final DateTime? lastSeenAt;
  final MusicControlDelegation? delegation;

  AccountDevice({
    required this.deviceId,
    this.userAgent,
    this.lastSeenAt,
    this.delegation,
  });

  factory AccountDevice.fromJson(Map<String, dynamic> json) {
    return AccountDevice(
      deviceId: json['deviceId'] as String,
      userAgent: json['userAgent'] as String?,
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.parse(json['lastSeenAt'] as String)
          : null,
      delegation: json['delegation'] != null
          ? MusicControlDelegation.fromJson(
              json['delegation'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    if (userAgent != null) 'userAgent': userAgent,
    if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
    if (delegation != null) 'delegation': delegation!.toJson(),
  };
}
