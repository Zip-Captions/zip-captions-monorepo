// `hide Timeout`: `flutter_test` re-exports `test_api`'s `Timeout`, which
// would otherwise collide with `ConnectFailure`'s `Timeout` variant.
import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:zip_core/src/models/connect_failure.dart';
import 'package:zip_core/src/models/connection_status.dart';

void main() {
  group('ConnectionType', () {
    test('has exactly the four values fixed by FR-4.6', () {
      expect(
        ConnectionType.values,
        containsAll(<ConnectionType>[
          ConnectionType.p2pDirect,
          ConnectionType.turnRelayed,
          ConnectionType.connecting,
          ConnectionType.disconnected,
        ]),
      );
      expect(ConnectionType.values, hasLength(4));
    });
  });

  group('ConnectionStatus', () {
    test('Connecting is a const singleton-equivalent value', () {
      const a = Connecting();
      const b = Connecting();
      expect(a, equals(b));
      expect(a, isA<Connecting>());
    });

    test('Connected carries connectionType', () {
      const status = Connected(ConnectionType.p2pDirect);
      expect(status, isA<Connected>());
      expect(status.connectionType, ConnectionType.p2pDirect);
    });

    test('Connected equality compares connectionType', () {
      const a = Connected(ConnectionType.p2pDirect);
      const b = Connected(ConnectionType.p2pDirect);
      const c = Connected(ConnectionType.turnRelayed);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('Interrupted is a const singleton-equivalent value', () {
      const a = Interrupted();
      const b = Interrupted();
      expect(a, equals(b));
      expect(a, isA<Interrupted>());
    });

    test('Failed carries failure', () {
      const status = Failed(IceFailed());
      expect(status, isA<Failed>());
      expect(status.failure, const IceFailed());
    });

    test('Failed equality compares failure', () {
      const a = Failed(IceFailed());
      const b = Failed(IceFailed());
      const c = Failed(Timeout());
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('distinct variants are never equal to each other', () {
      const connecting = Connecting();
      const connected = Connected(ConnectionType.p2pDirect);
      const interrupted = Interrupted();
      const failed = Failed(BroadcastFull());
      final variants = [connecting, connected, interrupted, failed];
      for (final a in variants) {
        for (final b in variants) {
          if (identical(a, b)) continue;
          expect(a, isNot(equals(b)));
        }
      }
    });
  });
}
