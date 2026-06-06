import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/config/token_storage.dart';
import 'package:music_room_app/core/auth/social_auth_service.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/models/session_info.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final SocialAuthService _socialAuth;

  AuthProvider({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
    SocialAuthService? socialAuth,
  }) : _apiClient = apiClient ?? ApiClient(),
       _tokenStorage = tokenStorage ?? TokenStorage(),
       _socialAuth = socialAuth ?? DefaultSocialAuthService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get signedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // * Allows SocketProvider to obtain the current access token for WS auth.
  Future<String?> get accessToken => _tokenStorage.accessToken;

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

  Future<void> forgotPassword(String email) async {
    _setLoading(true);
    _error = null;

    try {
      await _apiClient.post(ApiConfig.forgotPassword, data: {'email': email});
      notifyListeners();
    } on DioException catch (e) {
      _error =
          e.response?.data['message']?.toString() ?? 'Forgot password failed';
    } catch (e) {
      _error = 'An unexpected error occurred';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _setLoading(true);
    _error = null;

    try {
      await _apiClient.post(
        ApiConfig.resetPassword,
        data: {'token': token, 'newPassword': newPassword},
      );
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error =
          e.response?.data['message']?.toString() ?? 'Password reset failed';
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _setLoading(false);
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

  /// Login or register through a social provider (Google / Facebook).
  /// Runs the native OAuth flow, then exchanges the provider token at
  /// `POST /auth/social` for our session tokens. Returns true on success.
  Future<bool> socialLogin(SocialProvider provider) async {
    _setLoading(true);
    _error = null;

    try {
      final providerToken = await _socialAuth.signIn(provider);
      if (providerToken == null) {
        // User cancelled the native flow — not an error.
        return false;
      }

      final response = await _apiClient.post(
        ApiConfig.socialLogin,
        data: {'provider': provider.apiValue, 'accessToken': providerToken},
      );

      final accessToken = response.data['accessToken'] as String;
      final refreshToken = response.data['refreshToken'] as String;

      await _tokenStorage.saveTokens(accessToken, refreshToken);
      _user = User.decodeFromToken(accessToken);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data['message']?.toString() ?? 'Social login failed';
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Link a social provider to the currently signed-in account via
  /// `POST /auth/link-social` (protected route — token attached automatically).
  /// Returns true on success.
  Future<bool> linkSocial(SocialProvider provider) async {
    _setLoading(true);
    _error = null;

    try {
      final providerToken = await _socialAuth.signIn(provider);
      if (providerToken == null) {
        return false; // cancelled
      }

      await _apiClient.post(
        ApiConfig.linkSocial,
        data: {'provider': provider.apiValue, 'accessToken': providerToken},
      );
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error =
          e.response?.data['message']?.toString() ?? 'Linking account failed';
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
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
      debugPrint('Registering user...');
      debugPrint('wsUrl: ${ApiConfig.wsUrl}');

      await _apiClient.post(
        ApiConfig.register,
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );

      // * Verification is required; no session tokens are returned
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('Error in registration:');
      debugPrint(e.response?.data.toString());
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

  void forceLogout() async {
    await _tokenStorage.clear();
    _user = null;
    notifyListeners();
  }

  Future<bool> verifyEmail(String token) async {
    _setLoading(true);
    _error = null;

    try {
      await _apiClient.post(ApiConfig.verifyEmail, data: {'token': token});
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error =
          e.response?.data['message']?.toString() ??
          'Email verification failed';
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendVerification(String email) async {
    _setLoading(true);
    _error = null;

    try {
      await _apiClient.post(
        ApiConfig.resendVerification,
        data: {'email': email},
      );
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error =
          e.response?.data['message']?.toString() ??
          'Resending verification failed';
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Active sessions (bonus) ──────────────────────────────────────
  // GET /auth/sessions — list active refresh-token sessions.
  Future<List<SessionInfo>> listSessions() async {
    final response = await _apiClient.get(ApiConfig.sessions);
    final data = response.data as List;
    return data
        .map((json) => SessionInfo.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // DELETE /auth/sessions/:id — revoke one session.
  Future<void> revokeSession(String sessionId) async {
    await _apiClient.delete('${ApiConfig.sessions}/$sessionId');
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
