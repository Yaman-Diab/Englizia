/// Backend paths, one line each. Contract status lives in docs/api/.
abstract final class ApiEndpoints {
  // Confirmed in docs/api/openapi.json.
  static const refreshToken = '/api/v1/auth/refresh';
  // Confirmed in docs/api/openapi.json.
  static const register = '/api/v1/auth/register';
  // Confirmed in docs/api/openapi.json.
  static const login = '/api/v1/auth/login';
  // Confirmed in docs/api/openapi.json.
  static const logout = '/api/v1/auth/logout';
  // ASSUMPTION(api): docs/api/auth.md.
  static const guestAccount = '/api/v1/auth/guest';
  // ASSUMPTION(api): docs/api/auth.md.
  static const upgradeGuest = '/api/v1/auth/guest/upgrade';
  // ASSUMPTION(api): docs/api/auth.md.
  static const forgotPassword = '/api/v1/auth/password/forgot';
  // ASSUMPTION(api): docs/api/auth.md.
  static const verifyPasswordLink = '/api/v1/auth/password/reset/verify';
  // ASSUMPTION(api): docs/api/auth.md.
  static const resetPassword = '/api/v1/auth/password/reset';

  // ASSUMPTION(api): docs/api/tracks.md.
  static const tracks = '/api/v1/app/tracks';
  // ASSUMPTION(api): docs/api/placement.md.
  static const placementSummary = '/api/v1/app/placement/summary';
  // ASSUMPTION(api): docs/api/placement.md.
  static const placementStatus = '/api/v1/app/placement/status';
  // ASSUMPTION(api): docs/api/placement.md.
  static const placementAttempts = '/api/v1/app/placement/attempts';
  // ASSUMPTION(api): docs/api/settings.md.
  static const settings = '/api/v1/app/settings';

  // ASSUMPTION(api): docs/api/placement.md.
  static String enrollment(String enrollmentId) =>
      '/api/v1/app/enrollments/$enrollmentId';

  // ASSUMPTION(api): docs/api/tracks.md.
  static String levelUnits(String levelId) =>
      '/api/v1/app/levels/$levelId/units';

  static String trackLevels(String trackId) =>
      '/api/v1/app/tracks/$trackId/levels';
}
