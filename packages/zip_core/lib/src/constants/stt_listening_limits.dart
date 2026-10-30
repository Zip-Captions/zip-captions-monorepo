import 'package:flutter/foundation.dart';

/// Tunable numbers for continuous listening and the on-device check
/// (Unit 10, NFR-U10-03b and NFR-U10-05).
///
/// All four values are **starting points**, to be confirmed or changed at the
/// physical-device pass (`restartDelay` in particular: Android returns
/// `error_busy` if a recogniser restarts too soon, and a `listen()` within
/// about 80-150 ms of `stop()` or `cancel()` is affected by upstream
/// `speech_to_text` #678, fixed by PR #679 but not yet in a stable release).
/// Changing them is a one-file edit to [defaultSttListeningLimits], not a
/// design change.
@immutable
class SttListeningLimits {
  /// Creates an [SttListeningLimits].
  const SttListeningLimits({
    required this.restartCap,
    required this.immediateFailureWindow,
    required this.restartDelay,
    required this.onDeviceCheckTimeout,
    required this.segmentedSessionLength,
    this.finalResultDrainTimeout = const Duration(seconds: 1),
  });

  /// How many counted failures in a row stop the engine's own restarts.
  ///
  /// The check is increment-then-compare, so with a cap of 3 the third
  /// counted failure reports `restartCapReached`.
  final int restartCap;

  /// A session that ends faster than this, with no result and no silence
  /// code, counts as one failure.
  final Duration immediateFailureWindow;

  /// Wait between a session's end and the next `listen()`.
  final Duration restartDelay;

  /// How long the engine waits for an `OnDeviceSupportChecker` before it
  /// treats the answer as "unsupported".
  final Duration onDeviceCheckTimeout;

  /// How long one segmented engine session lasts before it ends the current
  /// recogniser session and starts the next one (D-2 revised, Amendment 03
  /// section 12).
  ///
  /// 5 minutes is the on-device recogniser's measured maximum: a longer
  /// `EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS` is logged "too high, ignored"
  /// and the recogniser drops the segmented session (the 60-minute first
  /// value did exactly that). A session therefore ends every 5 minutes, which
  /// also bounds what a crash or a platform-side stall can lose; the caption
  /// bus and the transcript writer are unaffected by the change of session.
  final Duration segmentedSessionLength;

  /// How long a stop or a pause waits for the platform to finish recognising
  /// the speech it already captured (BR-U10-55, Amendment 06).
  ///
  /// Both platforms keep recognising what was said before the stop (Android's
  /// `SpeechRecognizer.stopListening()`, iOS
  /// `SFSpeechRecognitionTask.finish()`) and deliver the last phrase shortly
  /// after. The wait ends early at the final result or the platform's end
  /// signal, so this is only the worst case. It is part of the 5 s Stop bound
  /// (BR-U10-58). Optional so existing call sites keep their value; tests pass
  /// a shorter or longer one.
  final Duration finalResultDrainTimeout;
}

/// The Unit 10 starting values (see [SttListeningLimits]).
const defaultSttListeningLimits = SttListeningLimits(
  restartCap: 3,
  immediateFailureWindow: Duration(seconds: 2),
  restartDelay: Duration(milliseconds: 250),
  onDeviceCheckTimeout: Duration(seconds: 2),
  segmentedSessionLength: Duration(minutes: 5),
);
