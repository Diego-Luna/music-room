import 'package:dio/dio.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/config/token_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

String? _cachedUserAgent;
String? _cachedAppVersion;

// V.6: every request must carry the platform so the back-end can log it.
// Same convention as PushTokenService (IOS/ANDROID/WEB).
String get _platform {
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

// V.6: app version header (e.g. "1.0.0+1"), read once from the bundle.
Future<String> _getAppVersion() async {
  if (_cachedAppVersion != null) return _cachedAppVersion!;
  try {
    final info = await PackageInfo.fromPlatform();
    _cachedAppVersion = info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  } catch (_) {
    _cachedAppVersion = 'unknown';
  }
  return _cachedAppVersion!;
}

Future<String> _getUserAgent() async {
  if (_cachedUserAgent != null) return _cachedUserAgent!;
  final deviceInfo = DeviceInfoPlugin();
  try {
    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      _cachedUserAgent = 'Web Browser (${webInfo.browserName.name})';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final androidInfo = await deviceInfo.androidInfo;
          _cachedUserAgent = 'Android (${androidInfo.model})';
          break;
        case TargetPlatform.iOS:
          final iosInfo = await deviceInfo.iosInfo;
          _cachedUserAgent = 'iOS (${iosInfo.name})';
          break;
        case TargetPlatform.macOS:
          final macInfo = await deviceInfo.macOsInfo;
          _cachedUserAgent = 'macOS (${macInfo.model})';
          break;
        default:
          _cachedUserAgent = 'Unknown Device';
          break;
      }
    }
  } catch (e) {
    _cachedUserAgent = 'Unknown Device';
  }
  return _cachedUserAgent!;
}

class ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();
  final void Function()? onUnauthorized;

  ApiClient({this.onUnauthorized})
    : _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // * Attach device info headers to ALL requests (including auth).
          // * V.6: Platform + Device + App Version must be logged by the
          //   back-end on every action, so they ride on every request.
          final deviceId = await _tokenStorage.getOrCreateDeviceId();
          options.headers['x-device'] = deviceId;
          options.headers['x-platform'] = _platform;
          options.headers['x-app-version'] = await _getAppVersion();
          options.headers['user-agent'] = await _getUserAgent();

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
    return _dio.post(path, data: data);
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return _dio.delete(path);
  }
}
