// Example-based tests for `BroadcastSettings.validateSessionName` (Unit 6,
// `business-rules.md` Rule 7) — the three named categories plus the valid
// case. Complementary to the invariant PBT suite
// (`broadcast_settings_pbt_test.dart`), per PBT-10 — not a replacement.

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/broadcast_settings.dart';

void main() {
  group('BroadcastSettings.validateSessionName', () {
    test('a valid name returns null', () {
      expect(BroadcastSettings.validateSessionName('My Stream'), isNull);
    });

    test('an empty string returns empty', () {
      expect(
        BroadcastSettings.validateSessionName(''),
        SessionNameError.empty,
      );
    });

    test('a whitespace-only string returns empty (trimmed first)', () {
      expect(
        BroadcastSettings.validateSessionName('   '),
        SessionNameError.empty,
      );
    });

    test('a name over the max length returns tooLong', () {
      final name = 'a' * (broadcastSessionNameMaxLength + 1);
      expect(
        BroadcastSettings.validateSessionName(name),
        SessionNameError.tooLong,
      );
    });

    test('a name at exactly the max length is valid', () {
      final name = 'a' * broadcastSessionNameMaxLength;
      expect(BroadcastSettings.validateSessionName(name), isNull);
    });

    test('a name containing a control character returns controlChar', () {
      expect(
        BroadcastSettings.validateSessionName('hello\x00world'),
        SessionNameError.controlChar,
      );
    });

    test('a name containing DEL (U+007F) returns controlChar', () {
      expect(
        BroadcastSettings.validateSessionName('hello\x7Fworld'),
        SessionNameError.controlChar,
      );
    });
  });
}
