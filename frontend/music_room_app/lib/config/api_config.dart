class ApiConfig {
  // * Base URL for the NestJS API
  // Todo: change to env var for production and development
  static const String baseUrl = 'http://localhost:3000';

  // * Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
}
