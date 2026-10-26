/// Backend paths, one line each. Contract status lives in docs/api/.
abstract final class ApiEndpoints {
  // ASSUMPTION(api): `/api/v1` prefix and refresh path — confirm in docs/api/README.md.
  static const refreshToken = '/api/v1/auth/refresh';

  // ASSUMPTION(api): docs/api/tracks.md.
  static const tracks = '/api/v1/tracks';
}
