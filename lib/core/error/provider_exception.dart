/// A sign-in service of the phone (Google's, Apple's) is missing, not set up
/// or failed. [reason] is for logs only.
final class ProviderException implements Exception {
  const ProviderException(this.reason);

  final String reason;

  @override
  String toString() => 'ProviderException($reason)';
}
