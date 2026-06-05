import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/models/user.dart';

void main() {
  group('User Model Tests', () {
    test('User.fromJson parses successfully with standard profile', () {
      final json = {
        'id': 'user-123',
        'email': 'alice@42.fr',
        'displayName': 'Alice',
        'avatarUrl': 'https://example.com/avatar.png',
        'emailVerified': true,
        'visibility': 'PUBLIC',
        'musicPreferences': ['rock', 'pop'],
        'createdAt': '2026-06-01T12:00:00.000Z',
      };

      final user = User.fromJson(json);

      expect(user.id, equals('user-123'));
      expect(user.email, equals('alice@42.fr'));
      expect(user.displayName, equals('Alice'));
      expect(user.avatarUrl, equals('https://example.com/avatar.png'));
      expect(user.emailVerified, isTrue);
      expect(user.visibility, equals(UserVisibility.public));
      expect(user.musicPreferences, containsAll(['rock', 'pop']));
      expect(
        user.createdAt,
        equals(DateTime.parse('2026-06-01T12:00:00.000Z')),
      );
    });

    test(
      'User.fromJson handles missing email and createdAt for public profiles',
      () {
        // * PublicUserProfileDto in NestJS backend does not include 'email' or 'createdAt'
        final json = {
          'id': 'user-123',
          'displayName': 'Alice',
          'avatarUrl': 'https://example.com/avatar.png',
          'visibility': 'PUBLIC',
          'musicPreferences': ['rock', 'pop'],
        };

        final user = User.fromJson(json);

        expect(user.id, equals('user-123'));
        expect(user.email, isEmpty);
        expect(user.displayName, equals('Alice'));
        expect(user.avatarUrl, equals('https://example.com/avatar.png'));
        expect(user.visibility, equals(UserVisibility.public));
        expect(user.musicPreferences, containsAll(['rock', 'pop']));
        expect(user.createdAt, isNotNull);
      },
    );
  });
}
