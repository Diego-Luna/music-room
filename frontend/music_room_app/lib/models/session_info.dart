/// A single active session (refresh-token row) as returned by
/// `GET /auth/sessions`.
class SessionInfo {
  final String id;
  final String? deviceId;
  final String? userAgent;
  final String? ip;
  final DateTime expiresAt;
  final DateTime createdAt;

  SessionInfo({
    required this.id,
    this.deviceId,
    this.userAgent,
    this.ip,
    required this.expiresAt,
    required this.createdAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String?,
      userAgent: json['userAgent'] as String?,
      ip: json['ip'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Best-effort human label for the session.
  String get label {
    if (deviceId != null && deviceId!.isNotEmpty) return deviceId!;
    if (userAgent != null && userAgent!.isNotEmpty) return userAgent!;
    return 'Unknown device';
  }
}
