import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// V.6 client tags sent on every HTTP request and Socket.IO handshake.
///
/// - [platform] → `x-platform` (ANDROID / IOS / WEB / …)
/// - [deviceLabel] → `x-device` (human-readable: "Pixel 7", "iPhone15,2", "Chrome")
/// - [deviceId] → `x-device-id` (stable UUID for sessions / delegation)
/// - [appVersion] → `x-app-version`
class ClientDeviceInfo {
  final String platform;
  final String deviceLabel;
  final String deviceId;
  final String appVersion;

  const ClientDeviceInfo({
    required this.platform,
    required this.deviceLabel,
    required this.deviceId,
    required this.appVersion,
  });

  static String? _cachedPlatform;
  static String? _cachedDeviceLabel;
  static String? _cachedAppVersion;

  /// Resolve (and cache) platform / model / app version. [deviceId] is supplied
  /// by the caller (TokenStorage) so this helper stays free of secure-storage.
  static Future<ClientDeviceInfo> resolve({required String deviceId}) async {
    return ClientDeviceInfo(
      platform: _cachedPlatform ??= _readPlatform(),
      deviceLabel: _cachedDeviceLabel ??= await _readDeviceLabel(),
      deviceId: deviceId,
      appVersion: _cachedAppVersion ??= await _readAppVersion(),
    );
  }

  Map<String, String> asHttpHeaders() => {
    'x-platform': platform,
    'x-device': deviceLabel,
    'x-device-id': deviceId,
    'x-app-version': appVersion,
  };

  /// Socket.IO `auth` payload extras (works on web where custom WS headers
  /// are blocked by the browser).
  Map<String, String> asSocketAuth() => {
    'platform': platform,
    'device': deviceLabel,
    'deviceId': deviceId,
    'appVersion': appVersion,
  };

  @visibleForTesting
  static void resetCacheForTest() {
    _cachedPlatform = null;
    _cachedDeviceLabel = null;
    _cachedAppVersion = null;
  }

  static String _readPlatform() {
    if (kIsWeb) return 'WEB';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.android:
        return 'ANDROID';
      case TargetPlatform.macOS:
        return 'MACOS';
      default:
        return 'WEB';
    }
  }

  static Future<String> _readAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Subject V.6 examples: "iPhone 6G", "iPad Air", "Samsung Edge".
  static Future<String> _readDeviceLabel() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final web = await plugin.webBrowserInfo;
        final browser = web.browserName.name;
        final vendor = web.vendor;
        if (vendor != null && vendor.isNotEmpty) {
          return '$browser ($vendor)';
        }
        return 'Web ($browser)';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = await plugin.androidInfo;
          final manufacturer = android.manufacturer.trim();
          final model = android.model.trim();
          if (manufacturer.isNotEmpty &&
              !model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
            return '$manufacturer $model';
          }
          return model.isNotEmpty ? model : 'Android';
        case TargetPlatform.iOS:
          final ios = await plugin.iosInfo;
          final machine = ios.utsname.machine.trim();
          final marketing = _iosMarketingName[machine];
          if (marketing != null) return marketing;
          // Fallback: "iPhone (iPhone15,2)" so logs stay readable.
          if (machine.isNotEmpty) {
            return '${ios.model} ($machine)';
          }
          return ios.localizedModel.isNotEmpty
              ? ios.localizedModel
              : ios.model;
        case TargetPlatform.macOS:
          final mac = await plugin.macOsInfo;
          return mac.model.isNotEmpty ? mac.model : 'macOS';
        default:
          return 'Unknown Device';
      }
    } catch (_) {
      return 'Unknown Device';
    }
  }

  /// Small map for common machines — enough for demo logs; unknown codes
  /// fall back to the raw `utsname.machine` string.
  static const Map<String, String> _iosMarketingName = {
    'iPhone14,4': 'iPhone 13 mini',
    'iPhone14,5': 'iPhone 13',
    'iPhone14,2': 'iPhone 13 Pro',
    'iPhone14,3': 'iPhone 13 Pro Max',
    'iPhone14,7': 'iPhone 14',
    'iPhone14,8': 'iPhone 14 Plus',
    'iPhone15,2': 'iPhone 14 Pro',
    'iPhone15,3': 'iPhone 14 Pro Max',
    'iPhone15,4': 'iPhone 15',
    'iPhone15,5': 'iPhone 15 Plus',
    'iPhone16,1': 'iPhone 15 Pro',
    'iPhone16,2': 'iPhone 15 Pro Max',
    'iPhone17,1': 'iPhone 16 Pro',
    'iPhone17,2': 'iPhone 16 Pro Max',
    'iPhone17,3': 'iPhone 16',
    'iPhone17,4': 'iPhone 16 Plus',
    'iPad13,18': 'iPad (10th gen)',
    'iPad14,1': 'iPad mini (6th gen)',
    'iPad14,3': 'iPad Pro 11-inch',
    'iPad14,5': 'iPad Pro 12.9-inch',
  };
}
