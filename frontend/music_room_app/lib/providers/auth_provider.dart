import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/config/token_storage.dart';
import 'package:music_room_app/models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthProvider({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get signedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> tryAutoLogin() async {
    final token = await _tokenStorage.accessToken;
    if (token != null) {
      final user = User.decodeFromToken(token);
      if (user != null) {
        _user = user;
        notifyListeners();
      } else {
        await _tokenStorage.clear();
      }
    }
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiClient.post(
        ApiConfig.login,
        data: {'email': email, 'password': password},
      );

      final accessToken = response.data['accessToken'] as String;
      final refreshToken = response.data['refreshToken'] as String;

      await _tokenStorage.saveTokens(accessToken, refreshToken);
      _user = User.decodeFromToken(accessToken);
      notifyListeners();
    } on DioException catch (e) {
      _error = e.response?.data['message']?.toString() ?? 'Login failed';
    } catch (e) {
      _error = 'An unexpected error occurred';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiClient.post(
        ApiConfig.register,
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );

      final accessToken = response.data['accessToken'] as String;
      final refreshToken = response.data['refreshToken'] as String;

      await _tokenStorage.saveTokens(accessToken, refreshToken);
      _user = User.decodeFromToken(accessToken);
      notifyListeners();
    } on DioException catch (e) {
      _error = e.response?.data['message']?.toString() ?? 'Registration failed';
    } catch (e) {
      _error = 'An unexpected error occurred';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _tokenStorage.refreshToken;
      await _apiClient.post(
        ApiConfig.logout,
        data: refreshToken != null ? {'refreshToken': refreshToken} : null,
      );
    } catch (e) {
      // Ignore logout errors
    } finally {
      await _tokenStorage.clear();
      _user = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
