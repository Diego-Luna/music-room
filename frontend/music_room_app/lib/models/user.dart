import 'dart:convert';

class User {
  final String id;
  final String email;

  User({required this.id, required this.email});

  factory User.fromJwtPayload(Map<String, dynamic> payload) {
    return User(
      id: payload['sub'] as String,
      email: payload['email'] as String,
    );
  }

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
}
