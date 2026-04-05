/// Thrown when a downloaded model archive fails SHA-256 verification
/// (REL-U2.4).
class ModelIntegrityException implements Exception {
  /// Creates a [ModelIntegrityException].
  const ModelIntegrityException({
    required this.modelId,
    required this.expected,
    required this.actual,
  });

  /// The model that failed verification.
  final String modelId;

  /// The expected SHA-256 hex digest from the catalog.
  final String expected;

  /// The actual SHA-256 hex digest of the downloaded file.
  final String actual;

  @override
  String toString() =>
      'ModelIntegrityException: model $modelId checksum mismatch '
      '(expected: $expected, actual: $actual)';
}
