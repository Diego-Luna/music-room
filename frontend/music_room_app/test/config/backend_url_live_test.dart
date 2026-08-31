import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:music_room_app/config/api_config.dart';

/// Live check against Nest on :3000 — same retarget path as
/// ApiConfig.setBackendUrl + ApiClient.updateBaseUrl.
///
/// Tests that hit the network skip when `/health` is unreachable so
/// `flutter test` stays green on CI (no Nest there).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio dio;
  var nestUp = false;

  setUpAll(() async {
    Hive.init('./.dart_tool/test_hive_backend_url_live');
    if (!Hive.isBoxOpen('app_settings')) {
      await Hive.openBox('app_settings');
    }
    nestUp = await _nestIsListening();
  });

  setUp(() async {
    ApiConfig.resetForTest();
    await Hive.box('app_settings').clear();
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));
  });

  tearDown(() async {
    ApiConfig.resetForTest();
    await Hive.box('app_settings').clear();
    dio.close(force: true);
  });

  test('good URL: login endpoint reachable after setBackendUrl', () async {
    if (!nestUp) {
      markTestSkipped('Nest is not listening on 127.0.0.1:3000');
      return;
    }

    await ApiConfig.setBackendUrl('http://127.0.0.1:3000');
    dio.options.baseUrl = ApiConfig.baseUrl;

    try {
      await dio.post(
        ApiConfig.login,
        data: {'email': 'url-test@example.com', 'password': 'wrong-password'},
      );
      fail('expected DioException from auth');
    } on DioException catch (e) {
      expect(e.type, isNot(DioExceptionType.connectionError));
      expect(e.type, isNot(DioExceptionType.connectionTimeout));
      expect(e.response?.statusCode, isIn([400, 401, 403]));
    }
  });

  test('bad URL: baseUrl retargets away from the live backend', () async {
    await ApiConfig.setBackendUrl('http://127.0.0.1:3000');
    dio.options.baseUrl = ApiConfig.baseUrl;

    await ApiConfig.setBackendUrl('http://203.0.113.50:9');
    dio.options.baseUrl = ApiConfig.baseUrl;
    expect(dio.options.baseUrl, equals('http://203.0.113.50:9'));
    expect(ApiConfig.baseUrl, isNot(contains('127.0.0.1:3000')));
  });

  test('switching back to good URL works again', () async {
    if (!nestUp) {
      markTestSkipped('Nest is not listening on 127.0.0.1:3000');
      return;
    }

    await ApiConfig.setBackendUrl('http://203.0.113.50:9');
    dio.options.baseUrl = ApiConfig.baseUrl;

    await ApiConfig.setBackendUrl('http://127.0.0.1:3000');
    dio.options.baseUrl = ApiConfig.baseUrl;
    expect(dio.options.baseUrl, equals('http://127.0.0.1:3000'));

    try {
      await dio.post(
        ApiConfig.login,
        data: {'email': 'url-test@example.com', 'password': 'wrong'},
      );
      fail('expected DioException from auth');
    } on DioException catch (e) {
      expect(e.response?.statusCode, isIn([400, 401, 403]));
    }
  });
}

Future<bool> _nestIsListening() async {
  final probe = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    ),
  );
  try {
    await probe.get('http://127.0.0.1:3000/health');
    return true;
  } catch (_) {
    return false;
  } finally {
    probe.close(force: true);
  }
}
