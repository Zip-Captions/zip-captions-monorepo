/// Thrown when Postgres or Realtime rejects an operation as a
/// permission-denied/RLS violation — distinct from a plain network failure
/// (NFR Design Q1).
///
/// Callers (e.g. a broadcaster session notifier) can catch this specifically
/// to distinguish "the server said no" from "the network is down," without
/// this unit needing to enumerate every possible RLS-rejection scenario as
/// its own caller-facing state.
class BroadcastAuthorizationException implements Exception {
  /// Creates a [BroadcastAuthorizationException] wrapping the rejection
  /// described by [message].
  const BroadcastAuthorizationException(this.message);

  /// A human-readable description of the rejection. Never includes
  /// credentials or token content.
  final String message;

  @override
  String toString() => 'BroadcastAuthorizationException: $message';
}
