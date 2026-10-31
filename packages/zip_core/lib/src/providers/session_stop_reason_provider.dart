import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_stop_reason_provider.g.dart';

/// Why a session was stopped by the app itself rather than by the user or an
/// engine error (Unit 10 Amendment 05, BR-U10-53).
enum SessionStopReason {
  /// No recognition result arrived for the inactivity timeout (BR-U10-51).
  inactivity,
}

/// The reason the session that most recently stopped was stopped by the app.
///
/// `null` means the stop was not an app-initiated one (the user's Stop, an
/// engine error, a refused resume), or the reason has been consumed. The
/// recording notifier writes it just before the stopped state is published;
/// `RecordingScreen` calls [take] when the state becomes stopped. Like the
/// transcript save outcome, it lets the screen show a one-time notice without
/// any `RecordingState` or `RecordingStateNotifier` API change.
///
/// Kept alive for the app lifetime. Carries an enum only, never any
/// recognised text.
@Riverpod(keepAlive: true)
class SessionStopReasonNotifier extends _$SessionStopReasonNotifier {
  @override
  SessionStopReason? build() => null;

  /// The recorded reason, or `null` when there is none.
  SessionStopReason? get reason => state;

  /// Records the cause of the stop that is under way.
  set reason(SessionStopReason? value) => state = value;

  /// Returns the recorded reason and resets it, so it is shown once.
  SessionStopReason? take() {
    final taken = state;
    state = null;
    return taken;
  }

  /// Forgets the recorded reason.
  void clear() => state = null;
}
