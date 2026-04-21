import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the async callback that must complete before the stopped state is
/// published. The transcript writer target provider sets the callback when a
/// target is active and clears it on dispose. The recording state notifier
/// reads it to await transcript finalization before navigation fires.
///
/// Uses a plain mutable holder (not Riverpod state) so that the callback can
/// be assigned during provider build without triggering the Riverpod assertion
/// that forbids modifying other providers during initialization.
/// Mutable holder for the session-stop async callback.
class SessionStopCallbackHolder {
  /// The callback to invoke before the stopped state is published, or null.
  Future<void> Function()? callback;
}

/// Provider for the singleton [SessionStopCallbackHolder].
final sessionStopCallbackProvider = Provider<SessionStopCallbackHolder>(
  (_) => SessionStopCallbackHolder(),
);
