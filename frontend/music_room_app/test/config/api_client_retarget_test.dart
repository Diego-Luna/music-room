import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';

class _CaptureAdapter implements HttpClientAdapter {
  String? lastUri;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastUri = options.uri.toString();
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('./.dart_tool/test_hive_api_client_retarget');
    if (!Hive.isBoxOpen('app_settings')) {
      await Hive.openBox('app_settings');
    }
  });

  setUp(() async {
    ApiConfig.resetForTest();
    await Hive.box('app_settings').clear();
  });

  tearDown(() async {
    ApiConfig.resetForTest();
    await Hive.box('app_settings').clear();
  });

  test('ApiClient.post follows ApiConfig.baseUrl after override', () async {
    final adapter = _CaptureAdapter();
    final client = ApiClient();
    client.dioForTest.httpClientAdapter = adapter;

    await ApiConfig.setBackendUrl('http://retarget.example:9999');
    try {
      await client.post(
        ApiConfig.login,
        data: {'email': 'a', 'password': 'b'},
      );
    } catch (_) {}
    expect(adapter.lastUri, equals('http://retarget.example:9999/auth/login'));

    await ApiConfig.setBackendUrl('http://127.0.0.1:3000');
    try {
      await client.post(
        ApiConfig.login,
        data: {'email': 'a', 'password': 'b'},
      );
    } catch (_) {}
    expect(adapter.lastUri, equals('http://127.0.0.1:3000/auth/login'));
  });
}
