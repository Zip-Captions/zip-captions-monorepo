// Tests for S-14, S-16, S-18: `ViewerAdmission` (WebRTC Transport, Remote
// Broadcast Output Target, Viewer Capacity) — example-based coverage of
// every `business-rules.md` Rule 6 behavior: the capacity cap accounts for
// a disconnected viewer's `reconnectWindow` grace period, and a slot is
// never handed to a new viewer while its original holder might still
// reclaim it. Property-based coverage of Rule 6's invariant lives in a
// separate PBT suite — this file is example-based only.
//
// `ViewerAdmission` owns no timer (expiry is swept lazily at the start of
// every call), so time is simulated by advancing a mutable `DateTime` read
// by the injected `now` closure — no `fakeAsync` needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/broadcast_limits.dart';
import 'package:zip_core/src/services/webrtc/viewer_admission.dart';

const _oneViewerLimits = BroadcastLimits(
  maxViewers: 1,
  presenceTimeout: Duration(seconds: 60),
  reconnectWindow: Duration(seconds: 120),
);

const _twoViewerLimits = BroadcastLimits(
  maxViewers: 2,
  presenceTimeout: Duration(seconds: 60),
  reconnectWindow: Duration(seconds: 120),
);

void main() {
  late DateTime currentTime;
  late ViewerAdmission admission;

  /// Reinstalls [admission] against [limits] with the clock back at the
  /// start, so every test starts from an empty, unelapsed state.
  void install(BroadcastLimits limits) {
    currentTime = DateTime.utc(2026);
    admission = ViewerAdmission(limits, now: () => currentTime);
  }

  void advance(Duration by) => currentTime = currentTime.add(by);

  group('ViewerAdmission', () {
    test(
      'a new peerId under maxViewers is admitted and count increases by 1',
      () {
        install(_twoViewerLimits);

        expect(admission.tryAdmit('peer-1'), const Admitted());
        expect(admission.count, 1);
      },
    );

    test(
      'a new peerId at maxViewers is Full and count is unchanged',
      () {
        install(_twoViewerLimits);
        admission
          ..tryAdmit('peer-1')
          ..tryAdmit('peer-2');

        expect(admission.tryAdmit('peer-3'), const Full());
        expect(admission.count, 2);
      },
    );

    test(
      'release of an admitted peerId does not decrease count (starts the '
      'reconnectWindow grace period instead)',
      () {
        install(_twoViewerLimits);
        admission.tryAdmit('peer-1');
        expect(admission.count, 1);

        admission.release('peer-1');

        // The slot is reserved, not freed — still counted against the cap.
        expect(admission.count, 1);
      },
    );

    test(
      'the same peerId reconnecting within reconnectWindow reclaims its '
      'slot: Admitted, with no net change to count across the '
      'release+reclaim pair',
      () {
        install(_twoViewerLimits);
        admission
          ..tryAdmit('peer-1')
          ..release('peer-1');
        expect(admission.count, 1);

        advance(const Duration(seconds: 60)); // within the 120s window.

        expect(admission.tryAdmit('peer-1'), const Admitted());
        expect(admission.count, 1);
      },
    );

    test(
      'an unreclaimed reservation frees its slot once reconnectWindow '
      'elapses: count drops by 1 and a different new peerId is admitted '
      'where it was Full',
      () {
        install(_twoViewerLimits);
        admission
          ..tryAdmit('peer-1')
          ..tryAdmit('peer-2')
          ..release('peer-1');

        // Still full: the reserved slot is counted against the cap.
        expect(admission.tryAdmit('peer-3'), const Full());
        expect(admission.count, 2);

        advance(const Duration(seconds: 121));

        expect(admission.count, 1);
        expect(admission.tryAdmit('peer-3'), const Admitted());
        expect(admission.count, 2);
      },
    );

    test(
      'release of a never-admitted peerId is a no-op: no exception, count '
      'unchanged, and the peerId did not consume a slot',
      () {
        install(_oneViewerLimits);

        expect(() => admission.release('ghost'), returnsNormally);
        expect(admission.count, 0);

        // If 'ghost' had (incorrectly) been registered as a reservation,
        // it would hold the only slot and this would be Full.
        expect(admission.tryAdmit('peer-1'), const Admitted());
        expect(admission.count, 1);
      },
    );

    test(
      'a full cycle at maxViewers 1: a released slot keeps a different '
      'peerId out until the window elapses',
      () {
        install(_oneViewerLimits);
        expect(admission.tryAdmit('peer-1'), const Admitted());

        admission.release('peer-1');

        // Immediately, before the window has elapsed:
        expect(admission.tryAdmit('peer-2'), const Full());
        expect(admission.count, 1);
      },
    );

    test(
      'count never exceeds maxViewers under an interleaved sequence of '
      'admits, releases, reclaims, and expiries (Rule 6 invariant)',
      () {
        install(_twoViewerLimits);

        expect(admission.tryAdmit('peer-1'), const Admitted());
        expect(admission.count, 1);
        expect(admission.tryAdmit('peer-2'), const Admitted());
        expect(admission.count, 2);
        expect(admission.tryAdmit('peer-3'), const Full());
        expect(admission.count, 2);

        admission.release('peer-1');
        expect(admission.count, 2); // reserved, still counted.
        advance(const Duration(seconds: 60));
        // Reclaim: the same peerId, within its window.
        expect(admission.tryAdmit('peer-1'), const Admitted());
        expect(admission.count, 2);

        admission.release('peer-2');
        expect(admission.count, 2);
        advance(const Duration(seconds: 121));
        expect(admission.count, 1); // peer-2's reservation expired.
        expect(admission.tryAdmit('peer-3'), const Admitted());
        expect(admission.count, 2);
      },
    );
  });
}
