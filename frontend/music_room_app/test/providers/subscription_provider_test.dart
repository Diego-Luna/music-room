import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:music_room_app/providers/subscription_provider.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/models/subscription.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<T> _ok<T>(T data) => Response<T>(
  data: data,
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
);

void main() {
  late SubscriptionProvider provider;
  late MockApiClient api;

  final plansJson = [
    {
      'tier': 'FREE',
      'label': 'Free',
      'price': '0',
      'features': ['Vote rooms'],
    },
    {
      'tier': 'PREMIUM',
      'label': 'Premium',
      'price': '9.99',
      'features': ['Playlist editor'],
    },
  ];

  setUp(() {
    api = MockApiClient();
    provider = SubscriptionProvider(apiClient: api);
  });

  group('SubscriptionProvider.load', () {
    test('loads the catalogue and the current tier', () async {
      when(() => api.get(ApiConfig.subscriptionPlans))
          .thenAnswer((_) async => _ok<dynamic>(plansJson));
      when(() => api.get(ApiConfig.subscriptionMe))
          .thenAnswer((_) async => _ok<dynamic>({'tier': 'FREE'}));

      await provider.load();

      expect(provider.plans, hasLength(2));
      expect(provider.plans.first.tier, SubscriptionTier.free);
      expect(provider.plans[1].tier, SubscriptionTier.premium);
      expect(provider.currentTier, SubscriptionTier.free);
      expect(provider.error, isNull);
      expect(provider.isLoading, false);
    });

    test('surfaces the backend message on failure', () async {
      when(() => api.get(ApiConfig.subscriptionPlans)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ApiConfig.subscriptionPlans),
          response: Response(
            requestOptions: RequestOptions(path: ApiConfig.subscriptionPlans),
            statusCode: 500,
            data: {'message': 'boom'},
          ),
        ),
      );
      when(() => api.get(ApiConfig.subscriptionMe))
          .thenAnswer((_) async => _ok<dynamic>({'tier': 'FREE'}));

      await provider.load();

      expect(provider.error, 'boom');
      expect(provider.plans, isEmpty);
    });
  });

  group('SubscriptionProvider.switchTo', () {
    test('PUTs the new tier and updates currentTier from the response',
        () async {
      provider = SubscriptionProvider(apiClient: api);
      when(() => api.put(ApiConfig.subscriptionMe, data: {'tier': 'PREMIUM'}))
          .thenAnswer((_) async => _ok<dynamic>({'tier': 'PREMIUM'}));

      final ok = await provider.switchTo(SubscriptionTier.premium);

      expect(ok, true);
      expect(provider.currentTier, SubscriptionTier.premium);
      verify(() => api.put(ApiConfig.subscriptionMe, data: {'tier': 'PREMIUM'}))
          .called(1);
    });

    test('is a no-op when already on the requested tier', () async {
      when(() => api.get(ApiConfig.subscriptionPlans))
          .thenAnswer((_) async => _ok<dynamic>(plansJson));
      when(() => api.get(ApiConfig.subscriptionMe))
          .thenAnswer((_) async => _ok<dynamic>({'tier': 'PREMIUM'}));
      await provider.load();

      final ok = await provider.switchTo(SubscriptionTier.premium);

      expect(ok, true);
      verifyNever(() => api.put(any(), data: any(named: 'data')));
    });
  });
}
