import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';

/// Registers this device's push token with the backend
/// (`POST /notifications/register`).
///
/// We deliberately avoid Firebase here (see the project's no-Firebase
/// decision): the backend ships a `LogPushTransport`, so it only needs a
/// stable opaque token to demonstrate the registration lifecycle. We derive
/// one from `device_info_plus` and persist it in secure storage so the same
/// device keeps the same token across launches.
class PushTokenService {
  final ApiClient _client;
  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'push_device_token';
  bool _registered = false;

  PushTokenService({required ApiClient client, FlutterSecureStorage? storage})
    : _client = client,
      _storage = storage ?? const FlutterSecureStorage();

  String get _platform {
    if (kIsWeb) return 'WEB';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.android:
        return 'ANDROID';
      default:
        return 'WEB';
    }
  }

  Future<String> _deviceToken() async {
    final existing = await _storage.read(key: _tokenKey);
    if (existing != null && existing.length >= 8) return existing;
    final generated = await _deriveToken();
    await _storage.write(key: _tokenKey, value: generated);
    return generated;
  }

  Future<String> _deriveToken() async {
    final info = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final web = await info.webBrowserInfo;
        return 'web-${web.browserName.name}-${_randomHex()}';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final a = await info.androidInfo;
          return 'android-${a.id}-${_randomHex()}';
        case TargetPlatform.iOS:
          final i = await info.iosInfo;
          return 'ios-${i.identifierForVendor ?? _randomHex()}';
        default:
          return 'device-${_randomHex()}';
      }
    } catch (_) {
      return 'device-${_randomHex()}';
    }
  }

  String _randomHex() {
    final rnd = Random.secure();
    return List.generate(
      16,
      (_) => rnd.nextInt(16).toRadixString(16),
    ).join();
  }

  /// Register once per app session. Best-effort: this is a bonus feature, so
  /// failures are swallowed and never block the user.
  Future<void> registerIfNeeded() async {
    if (_registered) return;
    try {
      final token = await _deviceToken();
      await _client.post(
        ApiConfig.notificationsRegister,
        data: {'token': token, 'platform': _platform},
      );
      _registered = true;
    } catch (_) {
      // Ignore — push registration must not impact the session.
    }
  }

  /// Allow re-registration after a logout/login cycle.
  void reset() => _registered = false;
}
