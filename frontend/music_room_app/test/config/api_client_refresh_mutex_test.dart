import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/config/token_storage.dart';

class _InMemoryTokenStorage implements TokenStorage {
  String? currentAccess = 'expired_access_token';
  String? currentRefresh = 'valid_refresh_token';
  bool cleared = false;

  @override
  Future<String?> get accessToken async => currentAccess;

  @override
  Future<String?> get refreshToken async => currentRefresh;

  @override
  Future<void> saveTokens(String access, String refresh) async {
    currentAccess = access;
    currentRefresh = refresh;
  }

  @override
  Future<void> clear() async {
    currentAccess = null;
    currentRefresh = null;
    cleared = true;
  }

  @override
  Future<String> getOrCreateDeviceId() async => 'test_device_123';
}

class _TestAdapter implements HttpClientAdapter {
  int refreshCallCount = 0;
  bool failRefresh = false;
  int? retryStatusCode;
  Completer<void>? refreshDelayCompleter;
  Completer<void> refreshStartedCompleter = Completer<void>();
  final List<String> authorizationHeadersReceived = [];
  final List<String> pathsRequested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    pathsRequested.add(path);
    final auth = options.headers['Authorization'] as String?;
    if (auth != null) {
      authorizationHeadersReceived.add(auth);
    }

    if (path == ApiConfig.refresh) {
      refreshCallCount++;
      if (!refreshStartedCompleter.isCompleted) {
        refreshStartedCompleter.complete();
      }
      if (refreshDelayCompleter != null) {
        await refreshDelayCompleter!.future;
      }
      if (failRefresh) {
        return ResponseBody.fromString(
          '{"statusCode":401,"message":"Invalid refresh token"}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString(
        '{"accessToken":"new_valid_token","refreshToken":"new_refresh_token"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    // Normal endpoints
    if (auth == 'Bearer new_valid_token') {
      if (retryStatusCode != null) {
        return ResponseBody.fromString(
          '{"statusCode":$retryStatusCode,"message":"Retry failed"}',
          retryStatusCode!,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString(
        '{"status":"ok","path":"$path"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    // Default for old/expired token
    return ResponseBody.fromString(
      '{"statusCode":401,"message":"jwt expired"}',
      401,
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

  late _InMemoryTokenStorage tokenStorage;
  late _TestAdapter adapter;
  late bool unauthorizedCalled;
  late ApiClient client;

  setUp(() {
    tokenStorage = _InMemoryTokenStorage();
    adapter = _TestAdapter();
    unauthorizedCalled = false;
    client = ApiClient(
      tokenStorage: tokenStorage,
      onUnauthorized: () {
        unauthorizedCalled = true;
      },
    );
    client.dioForTest.httpClientAdapter = adapter;
  });

  group('401 JWT Refresh Concurrency Mutex', () {
    test(
      'concurrent 401 requests trigger exactly 1 refresh call and retry all successfully',
      () async {
        adapter.refreshDelayCompleter = Completer<void>();

        // Launch 3 concurrent requests to protected endpoints
        final f1 = client.get('/rooms');
        final f2 = client.get('/users/me');
        final f3 = client.get('/playlists');

        // Wait until refresh is actively in flight
        await adapter.refreshStartedCompleter.future;

        // Exactly one refresh call is in flight
        expect(adapter.refreshCallCount, equals(1));
        expect(client.refreshCompleterForTest, isNotNull);

        // Complete the refresh call
        adapter.refreshDelayCompleter!.complete();

        final responses = await Future.wait([f1, f2, f3]);

        // All 3 completed with status 200
        expect(responses[0].statusCode, equals(200));
        expect(responses[1].statusCode, equals(200));
        expect(responses[2].statusCode, equals(200));

        // Only 1 refresh was made
        expect(adapter.refreshCallCount, equals(1));

        // Tokens were updated in storage
        expect(tokenStorage.currentAccess, equals('new_valid_token'));
        expect(tokenStorage.currentRefresh, equals('new_refresh_token'));

        // Refresh completer was reset to null
        expect(client.refreshCompleterForTest, isNull);
        expect(unauthorizedCalled, isFalse);

        // Verify retries used the new authorization header
        final retryHeaders = adapter.authorizationHeadersReceived.where(
          (h) => h == 'Bearer new_valid_token',
        );
        expect(retryHeaders.length, equals(3));
      },
    );

    test(
      'when refresh fails, all concurrent requests receive 401 and onUnauthorized is notified',
      () async {
        adapter.failRefresh = true;
        adapter.refreshDelayCompleter = Completer<void>();

        final f1 = client.get('/rooms');
        final f2 = client.get('/users/me');

        // Wait until refresh is in flight
        await adapter.refreshStartedCompleter.future;

        expect(adapter.refreshCallCount, equals(1));
        expect(client.refreshCompleterForTest, isNotNull);

        // Complete refresh with failure
        adapter.refreshDelayCompleter!.complete();

        // Both requests should fail with DioException 401
        await expectLater(f1, throwsA(isA<DioException>()));
        await expectLater(f2, throwsA(isA<DioException>()));

        expect(adapter.refreshCallCount, equals(1));
        expect(unauthorizedCalled, isTrue);
        expect(tokenStorage.cleared, isTrue);
        expect(client.refreshCompleterForTest, isNull);
      },
    );

    test(
      'refresh endpoint call itself does not trigger 401 interceptor loop',
      () async {
        adapter.failRefresh = true;

        // Calling refresh endpoint directly with 401 response
        await expectLater(
          client.post(ApiConfig.refresh, data: {'refreshToken': 'bad_token'}),
          throwsA(isA<DioException>()),
        );

        // Must be exactly 1 call (no retry loop triggered)
        expect(adapter.refreshCallCount, equals(1));
        expect(client.refreshCompleterForTest, isNull);
      },
    );

    test(
      'sequential request after refresh reuses new token without refreshing again',
      () async {
        // First request triggers refresh
        final r1 = await client.get('/rooms');
        expect(r1.statusCode, equals(200));
        expect(adapter.refreshCallCount, equals(1));

        // Second request uses the new token directly
        final r2 = await client.get('/users/me');
        expect(r2.statusCode, equals(200));
        expect(adapter.refreshCallCount, equals(1));
      },
    );

    test('default constructor sets connectTimeout and receiveTimeout to 15 seconds', () {
      final defaultClient = ApiClient();
      expect(
        defaultClient.dioForTest.options.connectTimeout,
        equals(const Duration(seconds: 15)),
      );
      expect(
        defaultClient.dioForTest.options.receiveTimeout,
        equals(const Duration(seconds: 15)),
      );
    });

    test('when leader retry request fails with DioException, retry error is propagated', () async {
      adapter.retryStatusCode = 500;
      try {
        await client.get('/fail-retry');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, equals(500));
      }
    });

    test('when refresh fails, onUnauthorized callback is called exactly once', () async {
      int callCount = 0;
      final singleClient = ApiClient(
        tokenStorage: tokenStorage,
        onUnauthorized: () {
          callCount++;
        },
      );
      singleClient.dioForTest.httpClientAdapter = adapter;
      adapter.failRefresh = true;

      await expectLater(
        singleClient.get('/rooms'),
        throwsA(isA<DioException>()),
      );

      expect(callCount, equals(1));
    });
  });
}
