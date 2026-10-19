// Tests for S-19: Zip Captions Viewer, `ReconnectPolicy` (Unit 7, NFR
// Design Q4). NFR-1.3's reconnection target is Spike 2.1's carried-forward
// aspirational value; this suite pins only the window arithmetic and the
// PBT-03 invariant.
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/constants/broadcast_limits_default.dart';
import 'package:zip_core/src/models/reconnect_policy.dart';

void main() {
  const policy = ReconnectPolicy();
  const window = Duration(seconds: 120);

  group('ReconnectPolicy', () {
    test('AC: returns the full window as the remaining delay at elapsed 0', () {
      expect(policy.nextDelay(0, Duration.zero), equals(window));
    });

    test('AC: returns the remaining window mid-flight', () {
      expect(
        policy.nextDelay(3, const Duration(seconds: 30)),
        equals(const Duration(seconds: 90)),
      );
    });

    test('AC: returns null exactly at the window boundary', () {
      expect(policy.nextDelay(0, window), isNull);
    });

    test('AC: returns null past the window', () {
      expect(
        policy.nextDelay(99, window + const Duration(seconds: 1)),
        isNull,
      );
    });

    test('AC: attempt is retained but never consulted', () {
      const elapsed = Duration(seconds: 45);
      expect(policy.nextDelay(0, elapsed), equals(policy.nextDelay(99, elapsed)));
    });

    test('AC: the window is defaultBroadcastLimits.reconnectWindow', () {
      expect(
        policy.nextDelay(0, Duration.zero),
        equals(defaultBroadcastLimits.reconnectWindow),
      );
    });

    test('PBT-03 invariant: non-null iff elapsed < window, and equals '
        'window - elapsed', () {
      final step = window.inSeconds + 60;
      for (var seconds = 0; seconds <= step; seconds++) {
        final elapsed = Duration(seconds: seconds);
        final delay = policy.nextDelay(seconds % 7, elapsed);
        if (elapsed < window) {
          expect(delay, equals(window - elapsed), reason: 'elapsed=$elapsed');
        } else {
          expect(delay, isNull, reason: 'elapsed=$elapsed');
        }
      }
    });
  });
}