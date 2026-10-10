// PBT-03 stateful property (S-14, S-16, S-18): ViewerAdmission's cap
// invariant (business-rules.md Rule 6), driven by generated
// AdmissionCommand sequences — count (active + reserved-for-reclaim)
// never exceeds maxViewers after every single command, under any
// interleaving of tryAdmit/release calls and clock advances, including
// when a reservation's expiry races a new tryAdmit. The real
// ViewerAdmission is the thing under test (no parallel reference
// implementation) — the invariant itself is the assertion.
//
// ViewerAdmission owns no timer (expiry is swept lazily at the start of
// every call), so time is simulated by advancing a mutable DateTime read
// by the injected now closure — same idiom as viewer_admission_test.dart,
// no fakeAsync needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/broadcast_limits.dart';
import 'package:zip_core/src/services/webrtc/viewer_admission.dart';

import '../helpers/generators.dart';
import '../helpers/pbt.dart';

const _limits = BroadcastLimits(
  maxViewers: 2,
  presenceTimeout: Duration(seconds: 60),
  reconnectWindow: Duration(seconds: 120),
);

void main() {
  Glados(arbitraryAdmissionCommandSequence).test(
    'count never exceeds maxViewers after every command in any sequence',
    (commands) {
      var currentTime = DateTime.utc(2026);
      final admission = ViewerAdmission(_limits, now: () => currentTime);

      for (final command in commands) {
        switch (command) {
          case TryAdmitCommand(:final peerId):
            admission.tryAdmit(peerId);
          case ReleaseCommand(:final peerId):
            admission.release(peerId);
          case AdvanceClockCommand(:final duration):
            currentTime = currentTime.add(duration);
        }

        // Rule 6 invariant: count (active + reserved-for-reclaim) never
        // exceeds maxViewers — checked after every single command so a
        // violation is attributed to the exact command that caused it.
        expect(
          admission.count,
          lessThanOrEqualTo(_limits.maxViewers),
          reason: 'Rule 6 invariant violated after $command',
        );
      }
    },
  );
}
