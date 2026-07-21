import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

// * Trigger production deploy
class ApiConfig {
  static const _settingsBoxName = 'app_settings';
  static const _backendUrlKey = 'backend_api_url';

  /// Runtime override persisted in Hive (V.5 — configurable on the app).
  static String? _overrideUrl;

  /// Compile-time / default URL before any runtime override.
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('BACKEND_API_URL');
    return fromEnv.isNotEmpty ? fromEnv : 'http://localhost:3000';
  }

  /// Effective URL used by REST + WebSocket (override → dart-define → localhost).
  static String get baseUrl {
    final raw = (_overrideUrl != null && _overrideUrl!.isNotEmpty)
        ? _overrideUrl!
        : defaultBaseUrl;
    return _rewriteForAndroidEmulator(raw);
  }

  /// WebSocket base URL
  static String get wsUrl => baseUrl;

  /// True when the user (or tests) set a runtime override.
  static bool get hasOverride =>
      _overrideUrl != null && _overrideUrl!.isNotEmpty;

  /// Load persisted override. Call after [HiveConfig.initialize].
  static Future<void> load() async {
    final box = Hive.box(_settingsBoxName);
    final stored = box.get(_backendUrlKey);
    if (stored is String && stored.trim().isNotEmpty) {
      _overrideUrl = _stripTrailingSlash(stored.trim());
    }
  }

  /// Persist and apply a new backend URL (http/https). Throws [FormatException]
  /// if invalid.
  static Future<void> setBackendUrl(String url) async {
    final normalized = _normalizeAndValidate(url);
    _overrideUrl = normalized;
    await Hive.box(_settingsBoxName).put(_backendUrlKey, normalized);
  }

  /// Clear override and fall back to [defaultBaseUrl].
  static Future<void> clearBackendUrlOverride() async {
    _overrideUrl = null;
    await Hive.box(_settingsBoxName).delete(_backendUrlKey);
  }

  @visibleForTesting
  static void resetForTest() {
    _overrideUrl = null;
  }

  static String _normalizeAndValidate(String url) {
    final trimmed = _stripTrailingSlash(url.trim());
    if (trimmed.isEmpty) {
      throw const FormatException('Backend URL cannot be empty.');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Enter a valid http(s) URL, e.g. http://localhost:3000',
      );
    }
    return trimmed;
  }

  static String _stripTrailingSlash(String url) {
    if (url.length > 1 && url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Redirect localhost to the host machine IP when running on Android emulator.
  /// Exclude tests because defaultTargetPlatform defaults to android in widget tests.
  static String _rewriteForAndroidEmulator(String rawUrl) {
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
