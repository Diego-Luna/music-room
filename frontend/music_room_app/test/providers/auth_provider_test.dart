import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/config/token_storage.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late AuthProvider authProvider;
  late MockApiClient mockApiClient;
  late MockTokenStorage mockTokenStorage;

  setUp(() {
    mockApiClient = MockApiClient();
    mockTokenStorage = MockTokenStorage();
    authProvider = AuthProvider(
      apiClient: mockApiClient,
      tokenStorage: mockTokenStorage,
    );
  });

  group('AuthProvider Tests', () {
    test('Initial state is unauthenticated', () {
      expect(authProvider.signedIn, false);
      expect(authProvider.user, null);
      expect(authProvider.isLoading, false);
    });

    test('login sets user on success', () async {
      // Mock token response
      final response = Response(
        requestOptions: RequestOptions(path: ''),
        data: {
          'accessToken':
              'header.eyJzdWIiOiIxMjMiLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20ifQ.signature',
          'refreshToken': 'refresh_token',
        },
        statusCode: 200,
      );

      when(
        () => mockApiClient.post(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => response);
      when(
        () => mockTokenStorage.saveTokens(any(), any()),
      ).thenAnswer((_) async => {});

      await authProvider.login('test@example.com', 'Password123');

      expect(authProvider.signedIn, true);
      expect(authProvider.user?.email, 'test@example.com');
      expect(authProvider.error, null);
      verify(() => mockTokenStorage.saveTokens(any(), any())).called(1);
    });

    test('login sets error on failure', () async {
      when(() => mockApiClient.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            data: {'message': 'Invalid credentials'},
            statusCode: 401,
          ),
        ),
      );

      await authProvider.login('test@example.com', 'wrong');

      expect(authProvider.signedIn, false);
      expect(authProvider.error, 'Invalid credentials');
    });

    test('logout clears user and storage', () async {
      // Set initial state to signed in
      // (Assuming tryAutoLogin logic works or we manually set _user if we could)
      // For simplicity, let's just test the logout call
      when(
        () => mockTokenStorage.refreshToken,
      ).thenAnswer((_) async => 'refresh');
      when(
        () => mockApiClient.post(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async =>
            Response(requestOptions: RequestOptions(path: ''), statusCode: 200),
      );
      when(() => mockTokenStorage.clear()).thenAnswer((_) async => {});

      await authProvider.logout();

      expect(authProvider.signedIn, false);
      verify(() => mockTokenStorage.clear()).called(1);
    });
  });
}
