class ApiConstants {
  ApiConstants._();

  // Point this at your Go backend. Use --dart-define=API_BASE_URL=... to override at build time.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://43.205.146.178:8080/api/v1',
  );

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  static const String profile = '/users/profile';
  static const String changePassword = '/users/change-password';
}
