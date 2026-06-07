import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/models/subscription.dart';

/// Owns the subscription screen state (VI.3 bonus): the catalogue of offers
/// and the signed-in user's current tier. Talks to GET /subscription/plans
/// and GET/PUT /subscription/me. Mirrors [ProfileProvider] conventions.
class SubscriptionProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  SubscriptionProvider({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  List<SubscriptionPlan> _plans = const [];
  SubscriptionTier? _currentTier;
  bool _isLoading = false;
  bool _isSwitching = false;
  String? _error;

  List<SubscriptionPlan> get plans => _plans;
  SubscriptionTier? get currentTier => _currentTier;
  bool get isLoading => _isLoading;
  bool get isSwitching => _isSwitching;
  String? get error => _error;

  /// Loads the catalogue and the current tier in parallel. Used on screen open.
  Future<void> load() async {
    _setLoading(true);
    _error = null;

    try {
      final results = await Future.wait([
        _apiClient.get(ApiConfig.subscriptionPlans),
        _apiClient.get(ApiConfig.subscriptionMe),
      ]);

      final plansData = results[0].data as List<dynamic>;
      _plans = plansData
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      _currentTier =
          Subscription.fromJson(results[1].data as Map<String, dynamic>).tier;
      notifyListeners();
    } on DioException catch (e) {
      _error =
          e.response?.data?['message']?.toString() ??
          'Failed to load subscription';
    } catch (e) {
      _error = 'An unexpected error occurred';
    } finally {
      _setLoading(false);
    }
  }

  /// Switches the signed-in user to [tier] via PUT /subscription/me, updating
  /// [currentTier] from the response. No-op if already on that tier.
  /// Returns true on success.
  Future<bool> switchTo(SubscriptionTier tier) async {
    if (tier == _currentTier) return true;
    _isSwitching = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.put(
        ApiConfig.subscriptionMe,
        data: {'tier': tier.toJson()},
      );
      _currentTier =
          Subscription.fromJson(response.data as Map<String, dynamic>).tier;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error =
          e.response?.data?['message']?.toString() ??
          'Failed to update subscription';
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _isSwitching = false;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
