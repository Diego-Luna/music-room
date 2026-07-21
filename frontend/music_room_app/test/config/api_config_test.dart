import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:music_room_app/config/api_config.dart';

void main() {
  setUp(() async {
    ApiConfig.resetForTest();
    Hive.init('./.dart_tool/test_hive_api_config');
    if (!Hive.isBoxOpen('app_settings')) {
      await Hive.openBox('app_settings');
    }
    await Hive.box('app_settings').clear();
  });

  tearDown(() async {
    ApiConfig.resetForTest();
    if (Hive.isBoxOpen('app_settings')) {
      await Hive.box('app_settings').clear();
    }
  });

  // * Verify the default URL resolves to localhost for local development
  test('ApiConfig.baseUrl defaults to localhost', () {
    expect(ApiConfig.baseUrl, equals('http://localhost:3000'));
  });

  test('ApiConfig.wsUrl returns baseUrl', () {
    expect(ApiConfig.wsUrl, equals(ApiConfig.baseUrl));
  });

  test('setBackendUrl persists override and updates baseUrl', () async {
    await ApiConfig.setBackendUrl('http://192.168.1.10:3000/');
    expect(ApiConfig.baseUrl, equals('http://192.168.1.10:3000'));
    expect(ApiConfig.hasOverride, isTrue);

    ApiConfig.resetForTest();
    await ApiConfig.load();
    expect(ApiConfig.baseUrl, equals('http://192.168.1.10:3000'));
  });

  test('clearBackendUrlOverride restores default', () async {
    await ApiConfig.setBackendUrl('https://api.example.com');
    await ApiConfig.clearBackendUrlOverride();
    expect(ApiConfig.hasOverride, isFalse);
    expect(ApiConfig.baseUrl, equals('http://localhost:3000'));
  });

  test('setBackendUrl rejects invalid URLs', () async {
    expect(
      () => ApiConfig.setBackendUrl('not-a-url'),
      throwsA(isA<FormatException>()),
    );
  });
}
