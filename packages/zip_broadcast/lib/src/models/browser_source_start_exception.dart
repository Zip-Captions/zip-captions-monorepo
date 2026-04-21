/// Thrown by `BrowserSourceServer.start()` when the server cannot bind.
class BrowserSourceStartException implements Exception {
  /// Creates a [BrowserSourceStartException] with the given [reason] code.
  const BrowserSourceStartException({required this.reason});

  /// A pre-constructed instance for the common port-already-in-use case.
  static const portInUse =
      BrowserSourceStartException(reason: 'port_in_use');

  /// Machine-readable reason code.
  final String reason;

  @override
  String toString() => 'BrowserSourceStartException: $reason';
}
