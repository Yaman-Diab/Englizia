import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.current);

  List<ConnectivityResult> current;
  final changes = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;

  Future<void> close() => changes.close();
}

void main() {
  test('any interface but none counts as online', () async {
    final fake = _FakeConnectivity([ConnectivityResult.mobile]);
    addTearDown(fake.close);
    final service = PlusConnectivityService(fake);
    expect(await service.isOnline(), isTrue);

    fake.current = [ConnectivityResult.none];
    expect(await service.isOnline(), isFalse);

    fake.current = [ConnectivityResult.wifi, ConnectivityResult.vpn];
    expect(await service.isOnline(), isTrue);
  });

  test('changes are reported once per switch', () async {
    final fake = _FakeConnectivity([ConnectivityResult.wifi]);
    addTearDown(fake.close);
    final events = <bool>[];
    final sub = PlusConnectivityService(fake).onlineChanges.listen(events.add);

    fake.changes
      ..add([ConnectivityResult.wifi])
      ..add([ConnectivityResult.mobile])
      ..add([ConnectivityResult.none])
      ..add([ConnectivityResult.none])
      ..add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);

    expect(events, [true, false, true]);
    await sub.cancel();
  });
}
