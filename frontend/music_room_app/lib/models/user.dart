import 'dart:convert';

enum UserVisibility {
  public,
  friendsOnly,
  private;

  static UserVisibility fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'FRIENDS_ONLY':
        return UserVisibility.friendsOnly;
      case 'PRIVATE':
        return UserVisibility.private;
      default:
        return UserVisibility.public;
    }
  }

  String toJson() {
    switch (this) {
      case UserVisibility.public:
        return 'PUBLIC';
      case UserVisibility.friendsOnly:
        return 'FRIENDS_ONLY';
      case UserVisibility.private:
        return 'PRIVATE';
    }
  }
}

class User {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool emailVerified;
  final UserVisibility visibility;
  final List<String> musicPreferences;
  // V.1 — the three audience-scoped profile texts.
  // friendsInfo/privateInfo are only present when the API exposes them
  // (self always; friend tier only for friends), so they stay nullable.
  final String? publicInfo;
  final String? friendsInfo;
  final String? privateInfo;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.emailVerified = false,
    this.visibility = UserVisibility.public,
    this.musicPreferences = const [],
    this.publicInfo,
    this.friendsInfo,
    this.privateInfo,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory User.fromJwtPayload(Map<String, dynamic> payload) {
    return User(
      id: payload['sub'] as String,
      email: payload['email'] as String,
      displayName:
          payload['displayName'] as String? ??
          payload['email'].toString().split('@')[0],
      avatarUrl: payload['avatarUrl'] as String?,
      emailVerified: payload['emailVerified'] as bool? ?? false,
      visibility: UserVisibility.fromString(payload['visibility'] as String?),
      musicPreferences: List<String>.from(payload['musicPreferences'] ?? []),
      publicInfo: payload['publicInfo'] as String?,
      friendsInfo: payload['friendsInfo'] as String?,
      privateInfo: payload['privateInfo'] as String?,
      createdAt: payload['createdAt'] != null
          ? DateTime.parse(payload['createdAt'])
          : null,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      visibility: UserVisibility.fromString(json['visibility'] as String?),
      musicPreferences: List<String>.from(json['musicPreferences'] ?? []),
      publicInfo: json['publicInfo'] as String?,
      friendsInfo: json['friendsInfo'] as String?,
      privateInfo: json['privateInfo'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'emailVerified': emailVerified,
    'visibility': visibility.toJson(),
    'musicPreferences': musicPreferences,
    'publicInfo': publicInfo,
    'friendsInfo': friendsInfo,
    'privateInfo': privateInfo,
    'createdAt': createdAt.toIso8601String(),
  };

  static User? decodeFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      var normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> data = json.decode(decoded);

      return User.fromJwtPayload(data);
    } catch (e) {
      return null;
    }
  }

  User copyWith({
    String? displayName,
    String? avatarUrl,
    bool? emailVerified,
    UserVisibility? visibility,
    List<String>? musicPreferences,
    String? publicInfo,
    String? friendsInfo,
    String? privateInfo,
  }) {
    return User(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      visibility: visibility ?? this.visibility,
      musicPreferences: musicPreferences ?? this.musicPreferences,
      publicInfo: publicInfo ?? this.publicInfo,
      friendsInfo: friendsInfo ?? this.friendsInfo,
      privateInfo: privateInfo ?? this.privateInfo,
      createdAt: createdAt,
    );
  }
}
