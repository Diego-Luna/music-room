// * Trigger production deploy
class ApiConfig {
  // * Base URL for the NestJS API
  // * Defaults to localhost for local development
  static const String baseUrl = String.fromEnvironment('BACKEND_API_URL') != ''
      ? String.fromEnvironment('BACKEND_API_URL')
      : 'http://localhost:3000';

  // * WebSocket base URL
  static String get wsUrl => baseUrl;

  // * Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendVerification = '/auth/resend-verification';
  // * Social auth — login/register via provider token, and linking a
  //   provider to the signed-in account.
  static const String socialLogin = '/auth/social';
  static const String linkSocial = '/auth/link-social';

  // * all rooms share the /rooms base
  static const String rooms = '/rooms';
  static const String profile = '/users/me';
  static const String search = '/auth/spotify/search';

  // * Subscription (VI.3 bonus) — free vs premium offers.
  // GET /subscription/plans (catalogue), GET/PUT /subscription/me (my tier).
  static const String subscriptionPlans = '/subscription/plans';
  static const String subscriptionMe = '/subscription/me';

  // * Feature flag — toggle between mock and live API
  // Use mock data while backend is auth-only
  static bool useMockData = false;
}
