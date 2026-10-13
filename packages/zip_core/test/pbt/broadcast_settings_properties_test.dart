// PBT-03 invariant: for any generated session-name string (including
// deliberately adversarial inputs), `BroadcastSettings.validateSessionName`
// returns exactly zero or one `SessionNameError` category — never more than
// one (Unit 6, `business-rules.md` Rule 7, NFR Requirements Q6). The three
// named example cases (empty/too-long/control-char) are kept as explicit
// example-based tests in `test/models/broadcast_settings_test.dart`,
// per PBT-10 — this suite complements, not replaces, those.

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/broadcast_settings.dart';

import '../helpers/generators.dart';
import '../helpers/pbt.dart';

void main() {
  Glados(arbitraryBroadcastSessionNameInput).test(
    'validateSessionName never flags more than one error category',
    (name) {
      // The validator's own single-return-value signature already makes
      // "more than one category" syntactically impossible (it returns a
      // single nullable enum, not a set) — the real property worth
      // checking is that its result is *consistent* with checking each
      // category independently, i.e. the first category checked
      // (empty, then tooLong, then controlChar) that actually applies is
      // exactly what's returned, and no category that doesn't apply is
      // ever returned instead.
      final result = BroadcastSettings.validateSessionName(name);

      final isEmpty = name.trim().isEmpty;
      final isTooLong = name.length > broadcastSessionNameMaxLength;
      final hasControlChar = name.codeUnits.any(
        (c) => (c >= 0x00 && c <= 0x1F) || c == 0x7F,
      );

      if (isEmpty) {
        expect(result, SessionNameError.empty);
      } else if (isTooLong) {
        expect(result, SessionNameError.tooLong);
      } else if (hasControlChar) {
        expect(result, SessionNameError.controlChar);
      } else {
        expect(result, isNull);
      }
    },
  );
}
