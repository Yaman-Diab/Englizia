import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone is connected, for screens that must react when the
/// connection drops or returns (offline banners, actions that need the
/// network). It reports a network interface, not a reachable server: a
/// request can still fail, and `ApiClient` reports that separately.
abstract interface class ConnectivityService {
  Future<bool> isOnline();

  /// On Wi-Fi or a cable: a connection that doesn't spend mobile data.
  Future<bool> isOnWifi();

  /// Emits on every change only.
  Stream<bool> get onlineChanges;
}

final class PlusConnectivityService implements ConnectivityService {
  PlusConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      _isOnline(await _connectivity.checkConnectivity());

  @override
  Future<bool> isOnWifi() async =>
      (await _connectivity.checkConnectivity()).any(
        (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
      );

  @override
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
