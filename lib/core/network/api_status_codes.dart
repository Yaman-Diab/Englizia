abstract final class ApiStatusCodes {
  static const ok = 200;
  static const created = 201;
  static const noContent = 204;
  static const badRequest = 400;
  static const unauthorized = 401;
  static const forbidden = 403;
  static const notFound = 404;
  static const conflict = 409;
  static const gone = 410;
  static const unprocessableEntity = 422;

  /// This app's version is older than the server's minimum.
  static const upgradeRequired = 426;
  static const tooManyRequests = 429;
  static const internalServerError = 500;
}
