class ApiConfig {
  // * Base URL for the NestJS API
  // * Defaults to localhost for local development
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'http://localhost:3000',
  );

  // * WebSocket base URL
  static String get wsUrl => baseUrl;

  // * Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // * all rooms share the /rooms base
  static const String rooms = '/rooms';
  static const String profile = '/users/me';
  static const String search = '/spotify/search';

  // * Feature flag — toggle between mock and live API
  // Use mock data while backend is auth-only
  static bool useMockData = false;
}
