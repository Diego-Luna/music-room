class ApiConfig {
  // * Base URL for the NestJS API
  // Todo: change to env var for production and development
  static const String baseUrl = 'http://localhost:3000';

  // * Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // * Feature endpoints
  static const String events = '/events';
  static const String playlists = '/playlists';
  static const String profile = '/users/me';
  static const String search = '/music/search';

  // * Feature flags
  static bool useMockData = true; // Use mock data while backend is auth-only
}
