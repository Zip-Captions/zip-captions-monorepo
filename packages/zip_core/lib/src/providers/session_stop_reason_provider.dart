import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// Carries an enum only, never any recognised text.
class SessionStopReasonNotifier extends Notifier<SessionStopReason?> {
  @override
  SessionStopReason? build() => null;

  /// Records [reason] as the cause of the stop that is under way.
  // ignore: use_setters_to_change_properties
  void record(SessionStopReason? reason) => state = reason;

  /// Returns the recorded reason and resets it, so it is shown once.
  SessionStopReason? take() {
    final reason = state;
    state = null;
    return reason;
  }

  /// Forgets the recorded reason.
  void clear() => state = null;
}

/// Provider for [SessionStopReasonNotifier], kept alive for the app lifetime.
final sessionStopReasonProvider =
    NotifierProvider<SessionStopReasonNotifier, SessionStopReason?>(
  SessionStopReasonNotifier.new,
);
