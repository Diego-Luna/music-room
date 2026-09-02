import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/models/subscription.dart';

/// Owns the signed-in user's subscription (VI.3 bonus): the catalogue of
/// offers and the current tier. Talks to GET /subscription/plans and
/// GET/PUT /subscription/me. Registered in the app-wide locator so Playlists
/// can hide the editor for FREE without waiting for a 403.
class SubscriptionProvider extends ChangeNotifier {
  static const _settingsBoxName = 'app_settings';
  static const _tierKey = 'subscription_tier';

  final ApiClient _apiClient;

  SubscriptionProvider({ApiClient? apiClient, SubscriptionTier? initialTier})
    : _apiClient = apiClient ?? ApiClient(),
      _currentTier = initialTier {
    _currentTier ??= _readCachedTier();
  }

  List<SubscriptionPlan> _plans = const [];
  SubscriptionTier? _currentTier;
  bool _isLoading = false;
  bool _isSwitching = false;
  String? _error;

  List<SubscriptionPlan> get plans => _plans;
  SubscriptionTier? get currentTier => _currentTier;
  bool get isPremium => _currentTier == SubscriptionTier.premium;
  bool get isLoading => _isLoading;
  bool get isSwitching => _isSwitching;
  String? get error => _error;

  /// Label for Settings: current plan, or a generic hint before the first load.
  String get currentLabel {
    switch (_currentTier) {
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.free:
        return 'Free';
      case null:
        return 'Free / Premium plans';
    }
  }

  /// Safe lookup for widget tests that omit the provider. Missing → not Premium.
  static bool isPremiumOf(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<SubscriptionProvider>(
        context,
        listen: listen,
      ).isPremium;
    } on ProviderNotFoundException {
      return false;
    }
  }

  /// Safe lookup for Settings when the provider is absent.
  static String labelOf(BuildContext context) {
    try {
      return Provider.of<SubscriptionProvider>(context).currentLabel;
    } on ProviderNotFoundException {
      return 'Free / Premium plans';
    }
  }

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
      _currentTier = Subscription.fromJson(
        results[1].data as Map<String, dynamic>,
      ).tier;
      _writeCachedTier(_currentTier);
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

  bool _isRefreshingTier = false;

  /// Fetches only GET /subscription/me. Used after login so Playlists knows
  /// the gate without opening the subscription screen. Keeps the last known
  /// (Hive-cached) tier if the request fails — a Premium user going offline
  /// must still see the editor.
  Future<void> refreshTier() async {
    if (_isRefreshingTier) return;
    _isRefreshingTier = true;
    try {
      final response = await _apiClient.get(ApiConfig.subscriptionMe);
      _currentTier = Subscription.fromJson(
        response.data as Map<String, dynamic>,
      ).tier;
      _writeCachedTier(_currentTier);
      notifyListeners();
    } catch (_) {
      // Keep last known tier (memory or Hive).
    } finally {
      _isRefreshingTier = false;
    }
  }

  /// Drops in-memory + cached tier on logout so the next account starts clean.
  void clear() {
    _currentTier = null;
    _plans = const [];
    _error = null;
    _writeCachedTier(null);
    notifyListeners();
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
      _currentTier = Subscription.fromJson(
        response.data as Map<String, dynamic>,
      ).tier;
      _writeCachedTier(_currentTier);
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

  SubscriptionTier? _readCachedTier() {
    try {
      if (!Hive.isBoxOpen(_settingsBoxName)) return null;
      final raw = Hive.box(_settingsBoxName).get(_tierKey) as String?;
      if (raw == null) return null;
      return SubscriptionTier.fromString(raw);
    } catch (_) {
      return null;
    }
  }

  void _writeCachedTier(SubscriptionTier? tier) {
    try {
      if (!Hive.isBoxOpen(_settingsBoxName)) return;
      final box = Hive.box(_settingsBoxName);
      if (tier == null) {
        box.delete(_tierKey);
      } else {
        box.put(_tierKey, tier.toJson());
      }
    } catch (_) {}
  }
}
