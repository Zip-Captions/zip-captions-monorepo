// In-memory [CaptioningStarter] fake for `BroadcastSessionNotifier`'s own
// test suite (Unit 6, NFR Requirements Q1) — this unit's tests substitute
// this for the real `DefaultCaptioningStarter`/`BroadcastRecordingNotifier`-
// backed implementations, neither of which is this unit's own concern to
// re-test.

import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/services/caption/captioning_starter.dart';

/// Fake [CaptioningStarter] with a settable [currentActivity] and a
/// recorded [startCalls] count.
class FakeCaptioningStarter implements CaptioningStarter {
  CaptionActivity _currentActivity = CaptionActivity.inactive;

  /// If set, reading [currentActivity] throws this instead — simulates a
  /// step-6 (target create/register/prime) failure in `goLive()`
  /// (`business-rules.md` Rule 2's table).
  Exception? currentActivityError;

  @override
  CaptionActivity get currentActivity {
    final e = currentActivityError;
    if (e != null) throw e;
    return _currentActivity;
  }

  set currentActivity(CaptionActivity value) => _currentActivity = value;

  /// Number of times [start] was called.
  int startCalls = 0;

  /// If set, [start] throws this instead of recording a call — simulates
  /// a failing coupled auto-start (`business-rules.md` Rule 3).
  Exception? startError;

  /// If true (the default), a successful [start] call also sets
  /// [currentActivity] to [CaptionActivity.active] — simulates the real
  /// `BroadcastRecordingNotifier.start()` eventually publishing a
  /// `SessionStateEvent` that would update it.
  bool activatesOnStart = true;

  @override
  Future<void> start() async {
    final e = startError;
    if (e != null) throw e;
    startCalls++;
    if (activatesOnStart) _currentActivity = CaptionActivity.active;
  }
}
