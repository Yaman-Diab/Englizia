/// No response was received: offline, DNS failure, timeout or TLS error.
final class NetworkException implements Exception {
  const NetworkException(this.reason);

  final String reason;

  @override
  String toString() => 'NetworkException($reason)';
}
