import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Coordinates used when voting in a geo-gated room (V.2.1).
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint({required this.lat, required this.lng});
}

/// Persisted vote position (Settings override). Used so web / school desktops
/// can demo location-licensed events without a GPS device.
class LocationConfig {
  static const _settingsBoxName = 'app_settings';
  static const _latKey = 'vote_location_lat';
  static const _lngKey = 'vote_location_lng';

  static double? _overrideLat;
  static double? _overrideLng;

  /// Effective position for API votes, or null if none configured.
  static GeoPoint? get current {
    final lat = _overrideLat;
    final lng = _overrideLng;
    if (lat == null || lng == null) return null;
    return GeoPoint(lat: lat, lng: lng);
  }

  static bool get hasOverride => current != null;

  /// Load persisted override. Call after [HiveConfig.initialize].
  static Future<void> load() async {
    final box = Hive.box(_settingsBoxName);
    final lat = box.get(_latKey);
    final lng = box.get(_lngKey);
    if (lat is num && lng is num) {
      _overrideLat = lat.toDouble();
      _overrideLng = lng.toDouble();
    }
  }

  /// Persist vote coordinates. Throws [FormatException] if out of range.
  static Future<void> setOverride({
    required double lat,
    required double lng,
  }) async {
    if (lat < -90 || lat > 90) {
      throw const FormatException('Latitude must be between -90 and 90.');
    }
    if (lng < -180 || lng > 180) {
      throw const FormatException('Longitude must be between -180 and 180.');
    }
    _overrideLat = lat;
    _overrideLng = lng;
    final box = Hive.box(_settingsBoxName);
    await box.put(_latKey, lat);
    await box.put(_lngKey, lng);
  }

  static Future<void> clearOverride() async {
    _overrideLat = null;
    _overrideLng = null;
    final box = Hive.box(_settingsBoxName);
    await box.delete(_latKey);
    await box.delete(_lngKey);
  }

  /// Position attached to vote requests (override only for now).
  static Future<GeoPoint?> resolve() async => current;

  @visibleForTesting
  static void resetForTest() {
    _overrideLat = null;
    _overrideLng = null;
  }

  @visibleForTesting
  static void setForTest({double? lat, double? lng}) {
    _overrideLat = lat;
    _overrideLng = lng;
  }
}
