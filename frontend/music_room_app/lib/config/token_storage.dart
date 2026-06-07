import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  final _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<String?> get accessToken async => await _storage.read(key: _accessKey);
  Future<String?> get refreshToken async =>
      await _storage.read(key: _refreshKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<String> getOrCreateDeviceId() async {
    const deviceIdKey = 'device_id';
    var deviceId = await _storage.read(key: deviceIdKey);
    if (deviceId == null) {
      final random =
          DateTime.now().millisecondsSinceEpoch.toString() +
          (1000 + (DateTime.now().microsecond % 9000)).toString();
      deviceId = 'dev_$random';
      await _storage.write(key: deviceIdKey, value: deviceId);
    }
    return deviceId;
  }
}
