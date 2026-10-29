import 'package:flutter/foundation.dart';

/// Why an engine reports a lasting error after `startListening` succeeded.
///
/// Mapped to existing `RecordingErrorFactories` by `SttSessionManager`
/// (Unit 10, Amendment 01 section 3.3 and Amendment 02 section 5).
enum SttEngineErrorKind {
  /// The recogniser cannot be used (not installed, service unavailable).
  recognizerUnavailable,

  /// On-device recognition is not available, so the engine refused to listen
  /// (the on-device check was false, or the platform reported a missing
  /// on-device language pack). Nothing is recognised off the device.
  onDeviceModelMissing,

  /// The requested locale is not supported by the recogniser.
  localeUnsupported,

  /// Microphone or speech permission was revoked while listening.
  permissionRevoked,

  /// The engine's own restarts kept failing and it gave up.
  restartCapReached,
}

/// A lasting engine error. By construction it carries **no free text**, so it
/// cannot carry a transcript (SECURITY-03).
@immutable
final class SttEngineError {
  /// Creates an [SttEngineError].
  const SttEngineError(this.kind);

  /// What went wrong.
  final SttEngineErrorKind kind;

  @override
  bool operator ==(Object other) =>
      other is SttEngineError && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'SttEngineError(${kind.name})';
}

/// An engine that can report lasting errors after `startListening` succeeded.
///
/// This is a sibling capability of `SttEngine`, not a member of it, so
/// existing engines and test doubles need no change. `SttSessionManager`
/// checks `engine is SttErrorSource` and registers its listener.
///
/// It is a method rather than a setter because `very_good_analysis` enables
/// `avoid_setters_without_getters`.
///
/// A mixin with one abstract member, used only through `implements`: engines
/// opt in by implementing it, and `is SttErrorSource` is the check.
mixin SttErrorSource {
  /// Sets (or clears, with `null`) the listener.
  ///
  /// The engine calls it at most once per lasting error.
  void setErrorListener(void Function(SttEngineError error)? listener);
}
