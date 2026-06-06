import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/models/user.dart';

/// Owns the current user's editable profile (V.1): public / friends-only /
/// private informations + music preferences + visibility.
/// Talks to GET/PATCH /users/me. Mirrors [AuthProvider] conventions.
class ProfileProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  ProfileProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  User? _profile;
  bool _isLoading = false;
  String? _error;

  User? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetches the full self profile (all fields, including private).
  Future<void> loadProfile() async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiClient.get(ApiConfig.profile);
      _profile = User.fromJson(response.data as Map<String, dynamic>);
      notifyListeners();
    } on DioException catch (e) {
      _error =
          e.response?.data['message']?.toString() ?? 'Failed to load profile';
    } catch (e) {
      _error = 'An unexpected error occurred';
    } finally {
      _setLoading(false);
    }
  }

  /// Updates only the fields passed (non-null) via PATCH /users/me, then
  /// refreshes [profile] from the response. Returns true on success.
  Future<bool> updateProfile({
    String? displayName,
    UserVisibility? visibility,
    List<String>? musicPreferences,
    String? publicInfo,
    String? friendsInfo,
    String? privateInfo,
  }) async {
    _setLoading(true);
    _error = null;

    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (visibility != null) data['visibility'] = visibility.toJson();
    if (musicPreferences != null) data['musicPreferences'] = musicPreferences;
    if (publicInfo != null) data['publicInfo'] = publicInfo;
    if (friendsInfo != null) data['friendsInfo'] = friendsInfo;
    if (privateInfo != null) data['privateInfo'] = privateInfo;

    try {
      final response = await _apiClient.patch(ApiConfig.profile, data: data);
      _profile = User.fromJson(response.data as Map<String, dynamic>);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error =
          e.response?.data['message']?.toString() ?? 'Failed to update profile';
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
