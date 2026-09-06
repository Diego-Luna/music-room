import 'dart:async';
import 'package:dio/dio.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/config/client_device_info.dart';
import 'package:music_room_app/config/token_storage.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage;
  final void Function()? onUnauthorized;
  Completer<bool>? _refreshCompleter;

  ApiClient({this.onUnauthorized, TokenStorage? tokenStorage, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ),
      _tokenStorage = tokenStorage ?? TokenStorage() {
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          error: true,
          logPrint: (obj) => debugPrint('[HTTP] $obj'),
        ),
      );
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // * V.5: honour runtime backend URL on every request so all ApiClient
          //   instances (AuthProvider, repositories, etc.) stay in sync.
          final base = ApiConfig.baseUrl;
          _dio.options.baseUrl = base;
          options.baseUrl = base;

          // * V.6: Platform + Device (human label) + App Version on every action.
          // * x-device-id keeps the stable UUID used for sessions / delegation.
          try {
            final deviceId = await _tokenStorage.getOrCreateDeviceId();
            final info = await ClientDeviceInfo.resolve(deviceId: deviceId);
            options.headers.addAll(info.asHttpHeaders());
          } catch (_) {
            options.headers['x-platform'] = kIsWeb ? 'WEB' : 'UNKNOWN';
            options.headers['x-device'] = 'unknown';
            options.headers['x-device-id'] = 'unknown';
            options.headers['x-app-version'] = 'unknown';
          }

          // * Only attach the Bearer token to protected endpoints.
          // ! Public auth routes must NOT receive the header — an expired token
          // ! on /auth/refresh triggers the global guard, causing a logout loop.
          final path = options.path;
          final isPublic =
              path == ApiConfig.register ||
              path == ApiConfig.login ||
              path == ApiConfig.refresh ||
              path == ApiConfig.forgotPassword ||
              path == ApiConfig.resetPassword ||
              path == ApiConfig.verifyEmail ||
              path == ApiConfig.resendVerification ||
              path == ApiConfig.socialLogin ||
              path == '/health';
          if (!isPublic) {
            final token = await _tokenStorage.accessToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException err, handler) async {
          final isRefresh =
              err.requestOptions.path == ApiConfig.refresh ||
              err.requestOptions.path.endsWith(ApiConfig.refresh) ||
              err.requestOptions.extra['isRefresh'] == true;

          if (err.response?.statusCode == 401 && !isRefresh) {
            if (_refreshCompleter != null) {
              final inFlight = _refreshCompleter!;
              final success = await inFlight.future;
              if (success) {
                final token = await _tokenStorage.accessToken;
                if (token != null) {
                  err.requestOptions.headers['Authorization'] = 'Bearer $token';
                }
                try {
                  final response = await _dio.fetch(err.requestOptions);
                  return handler.resolve(response);
                } on DioException catch (retryErr) {
                  return handler.next(retryErr);
                } catch (_) {
                  return handler.next(err);
                }
              } else {
                return handler.next(err);
              }
            }

            final completer = Completer<bool>();
            _refreshCompleter = completer;
            try {
              final success = await _refreshToken();
              if (success) {
                completer.complete(true);
                _refreshCompleter = null;
                final token = await _tokenStorage.accessToken;
                if (token != null) {
                  err.requestOptions.headers['Authorization'] = 'Bearer $token';
                }
                try {
                  final response = await _dio.fetch(err.requestOptions);
                  return handler.resolve(response);
                } on DioException catch (retryErr) {
                  return handler.next(retryErr);
                } catch (_) {
                  return handler.next(err);
                }
              } else {
                completer.complete(false);
                _refreshCompleter = null;
                onUnauthorized?.call();
                return handler.next(err);
              }
            } catch (e) {
              if (!completer.isCompleted) {
                completer.complete(false);
              }
              _refreshCompleter = null;
              return handler.next(err);
            }
          }
          return handler.next(err);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    final refresh = await _tokenStorage.refreshToken;
    if (refresh == null) return false;

    try {
      final response = await _dio.post(
        ApiConfig.refresh,
        data: {'refreshToken': refresh},
        options: Options(extra: {'isRefresh': true}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final access = response.data['accessToken'] as String;
        final newRefresh = response.data['refreshToken'] as String;
        await _tokenStorage.saveTokens(access, newRefresh);
        return true;
      }
    } catch (e) {
      await _tokenStorage.clear();
    }
    return false;
  }

  Future<Response> post(String path, {dynamic data}) async {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    return _dio.post(path, data: data);
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> put(String path, {dynamic data}) async {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) async {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    return _dio.delete(path, data: data);
  }

  /// Point Dio at a new backend base URL (V.5 runtime config).
  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  @visibleForTesting
  Dio get dioForTest => _dio;

  @visibleForTesting
  Completer<bool>? get refreshCompleterForTest => _refreshCompleter;

  @visibleForTesting
  TokenStorage get tokenStorageForTest => _tokenStorage;
}
