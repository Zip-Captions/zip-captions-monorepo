import 'dart:async';

import 'fake_speech_to_text.dart';

/// A scripted fake with the shape of `OnDeviceSupportChecker`.
///
/// Each call consumes the next scripted outcome (a `bool`, an exception to
/// throw, or [FakeOnDeviceChecker.hang] to never complete); when the script
/// is empty it answers [defaultResult]. Every call is logged to the shared
/// [CallLog] as `check:<localeId>:<outcome>`.
class FakeOnDeviceChecker {
  /// Creates a checker, optionally sharing a [CallLog].
  FakeOnDeviceChecker([CallLog? log]) : log = log ?? CallLog();

  /// A scripted outcome meaning "never completes" (to exercise the timeout).
  static const Object hang = #hang;

  /// The shared call log.
  final CallLog log;

  /// What the checker answers when the script is empty.
  bool defaultResult = true;

  /// Scripted outcomes, consumed in order.
  final List<Object> script = [];

  /// When set, the next call waits for this future before it answers (it is
  /// consumed after one call), so a test can hold the check open and let
  /// something else happen in between.
  Future<void>? hangNext;

  /// The locales passed to each call, oldest first.
  final List<String> localesChecked = [];

  /// The checker function to hand to the engine.
  Future<bool> call(String localeId) {
    localesChecked.add(localeId);
    final held = hangNext;
    hangNext = null;
    if (held != null) {
      // Logged only when it answers, so "a true check just before listen"
      // still reads correctly after a held check.
      return held.then((_) {
        log.add('check:$localeId:${defaultResult ? 'true' : 'false'}');
        return defaultResult;
      });
    }
    final outcome = script.isEmpty ? defaultResult : script.removeAt(0);
    if (identical(outcome, hang)) {
      log.add('check:$localeId:hang');
      return Completer<bool>().future;
    }
    if (outcome is bool) {
      log.add('check:$localeId:$outcome');
      return Future<bool>.value(outcome);
    }
    log.add('check:$localeId:throws');
    return Future<bool>.error(outcome);
  }
}
