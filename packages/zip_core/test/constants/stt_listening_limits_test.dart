import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/constants/stt_listening_limits.dart';

void main() {
  group('defaultSttListeningLimits', () {
    test('carries the NFR Design starting values', () {
      expect(defaultSttListeningLimits.restartCap, 3);
      expect(
        defaultSttListeningLimits.immediateFailureWindow,
        const Duration(seconds: 2),
      );
      expect(
        defaultSttListeningLimits.restartDelay,
        const Duration(milliseconds: 250),
      );
      expect(
        defaultSttListeningLimits.onDeviceCheckTimeout,
        const Duration(seconds: 2),
      );
      // D-2 revised (Amendment 03 section 12): 5 minutes, the recogniser's
      // measured maximum. Anything longer is "too high, ignored" and the
      // recogniser drops the segmented session.
      expect(
        defaultSttListeningLimits.segmentedSessionLength,
        const Duration(minutes: 5),
      );
    });

    test('is a compile-time constant', () {
      // Two const instances with the same values are identical.
      const a = SttListeningLimits(
        restartCap: 3,
        immediateFailureWindow: Duration(seconds: 2),
        restartDelay: Duration(milliseconds: 250),
        onDeviceCheckTimeout: Duration(seconds: 2),
        segmentedSessionLength: Duration(minutes: 5),
      );
      expect(identical(a, defaultSttListeningLimits), isTrue);
    });
  });
}
