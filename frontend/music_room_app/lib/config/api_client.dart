import 'package:dio/dio.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/config/client_device_info.dart';
import 'package:music_room_app/config/token_storage.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();
  final void Function()? onUnauthorized;

  ApiClient({this.onUnauthorized})
    : _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)) {
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
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 &&
              e.requestOptions.path != ApiConfig.refresh) {
            final success = await _refreshToken();
            if (success) {
              // Retry the original request
              final options = e.requestOptions;
              final token = await _tokenStorage.accessToken;
              options.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(options);
              return handler.resolve(response);
            } else {
              // Refresh failed, notify unauthorized
              onUnauthorized?.call();
            }
          }
          return handler.next(e);
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
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final access = response.data['accessToken'] as String;
        final newRefresh = response.data['refreshToken'] as String;
        await _tokenStorage.saveTokens(access, newRefresh);
        return true;
      }
    } catch (e) {
      await _tokenStorage.clear();
      onUnauthorized?.call();
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
}
