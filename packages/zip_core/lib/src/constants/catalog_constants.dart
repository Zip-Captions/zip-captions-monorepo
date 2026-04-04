/// Constants for the Sherpa-ONNX model catalog.
///
/// The catalog URL is a compile-time constant (SEC-U2.4).
/// It is not configurable at runtime or sourced from user input.
abstract final class CatalogConstants {
  /// HTTPS URL for the static model catalog JSON.
  ///
  /// Phase 1: static JSON on CDN (Q10=C).
  /// Phase 2: dynamic proxy (same URL, server-side change only).
  static const String catalogUrl =
      'https://cdn.zipcaptions.app/models/catalog.json';

  /// Download size threshold in bytes above which user confirmation
  /// is required before starting a download (USA-U2.1).
  static const int downloadConfirmationThresholdBytes = 100 * 1024 * 1024;

  /// Duration after which the cached catalog is considered stale
  /// and a background revalidation is triggered (REL-U2.3).
  static const Duration catalogFreshnessDuration = Duration(hours: 24);
}
