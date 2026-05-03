import 'package:dio/dio.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/config/token_storage.dart';

class ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();

  ApiClient() : _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
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
    }
    return false;
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> get(String path) async {
    return _dio.get(path);
  }
}
