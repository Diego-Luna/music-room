class ApiConfig {
  // * Base URL for the NestJS API
  // Todo: change to env var for production and development
  static const String baseUrl = 'http://localhost:3000';

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
