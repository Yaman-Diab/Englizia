import 'package:englizia/core/error/provider_exception.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google's account sheet on this phone: the only place that knows its SDK.
abstract interface class GoogleIdentitySource {
  /// The ID token of the account the learner picks, made for the server; null
  /// when they closed the sheet. Throws [ProviderException] when Google's
  /// sign-in is missing, not set up or fails.
  Future<String?> idToken();

  /// Forgets the picked account, so the next sign-in asks which one.
  Future<void> signOut();
}

final class GoogleIdentitySourceImpl implements GoogleIdentitySource {
  GoogleIdentitySourceImpl(
    this._google, {
    required this.serverClientId,
    this.clientId,
  });

  final GoogleSignIn _google;

  /// The server's OAuth client (a "Web application" one): the token is made
  /// for it, and the server refuses any other.
  final String serverClientId;

  /// This app's own OAuth client, which iOS needs. Android finds its own by
  /// the application ID and the signing key.
  final String? clientId;

  Future<void>? _ready;

  /// Once per run; a failed try is forgotten, so the next one starts over.
  Future<void> _initialize() => _ready ??= _google
      .initialize(clientId: clientId, serverClientId: serverClientId)
      .onError<Object>((error, stackTrace) {
        _ready = null;
        Error.throwWithStackTrace(error, stackTrace);
      });

  @override
  Future<String?> idToken() async {
    if (serverClientId.isEmpty) {
      throw const ProviderException('no Google server client ID in this build');
    }
    try {
      await _initialize();
      if (!_google.supportsAuthenticate()) {
        throw const ProviderException('Google sign-in cannot ask here');
      }
      final account = await _google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const ProviderException('Google gave no ID token');
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        // Android also answers "canceled" for a client that is not set up
        // (a signing key Google does not know), so the reason is kept.
        AppLogger.info('Google sign-in canceled: ${error.description}');
        return null;
      }
      throw ProviderException('${error.code.name}: ${error.description}');
    }
  }

  @override
  Future<void> signOut() async {
    if (serverClientId.isEmpty) return;
    await _initialize();
    await _google.signOut();
  }
}

/// Mock mode (`env/mock.json`): any account, with no sheet.
final class GoogleIdentityFake implements GoogleIdentitySource {
  const GoogleIdentityFake();

  @override
  Future<String?> idToken() async => 'mock-google-id-token';

  @override
  Future<void> signOut() async {}
}
