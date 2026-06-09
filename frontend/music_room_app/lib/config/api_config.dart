import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// * Trigger production deploy
class ApiConfig {
  // * Base URL for the NestJS API
  // * Defaults to localhost for local development
  // * Dynamically maps localhost to 10.0.2.2 on Android Emulators
  static String get baseUrl {
    const rawUrl = String.fromEnvironment('BACKEND_API_URL') != ''
        ? String.fromEnvironment('BACKEND_API_URL')
        : 'http://localhost:3000';

    // * Redirect localhost to the host machine IP when running on Android emulator.
    // * Exclude tests because defaultTargetPlatform defaults to android in widget tests.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      if (rawUrl.contains('localhost')) {
        return rawUrl.replaceAll('localhost', '10.0.2.2');
      }
      if (rawUrl.contains('127.0.0.1')) {
        return rawUrl.replaceAll('127.0.0.1', '10.0.2.2');
      }
    }

    return rawUrl;
  }

  // * WebSocket base URL
  static String get wsUrl => baseUrl;

  // * Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendVerification = '/auth/resend-verification';
  // * Social auth — login/register via provider token, and linking a
  //   provider to the signed-in account.
  static const String socialLogin = '/auth/social';
  static const String linkSocial = '/auth/link-social';

  // * all rooms share the /rooms base
  static const String rooms = '/rooms';
  static const String profile = '/users/me';
  // * Deezer-backed track search (GET /search?q=&limit=)
  static const String search = '/search';

  // * Auth sessions (bonus) — list/revoke active refresh-token sessions.
  static const String sessions = '/auth/sessions';

  // * Push notifications (bonus) — register/unregister a device token.
  static const String notificationsRegister = '/notifications/register';

  // * Subscription (VI.3 bonus) — free vs premium offers.
  // GET /subscription/plans (catalogue), GET/PUT /subscription/me (my tier).
  static const String subscriptionPlans = '/subscription/plans';
  static const String subscriptionMe = '/subscription/me';
}
