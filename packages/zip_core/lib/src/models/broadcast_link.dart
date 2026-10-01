import 'package:zip_core/src/models/broadcast_id.dart';

/// Parses free-form user input (pasted URL or bare code) into a validated
/// [BroadcastId].
///
/// This is the boundary between untrusted input and the typed domain model
/// — `parseInput` never throws, so callers (e.g. a viewer's "join" screen)
/// can treat "invalid input" as a plain `null` result without a network
/// call, rather than catching an exception.
abstract final class BroadcastLink {
  /// The canonical base URL broadcast links are generated under.
  static const String baseUrl = 'https://zipcaptions.app/b/';

  /// Accepts a bare code (`k7m9x2`), a bare host+path
  /// (`zipcaptions.app/b/k7m9x2`), or the full `https://` form. Returns
  /// `null` for anything else — never throws.
  static BroadcastId? parseInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final direct = BroadcastId.tryParse(trimmed);
    if (direct != null) return direct;

    Uri? uri;
    try {
      uri = Uri.parse(
        trimmed.contains('://') ? trimmed : 'https://$trimmed',
      );
    } on FormatException {
      return null;
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;

    return BroadcastId.tryParse(segments.last);
  }

  /// Builds the shareable URL for [id], using the lowercase display form
  /// (SR-02 §3) — parsing it back is case-insensitive either way.
  static Uri toUrl(BroadcastId id) =>
      Uri.parse('$baseUrl${id.value.toLowerCase()}');
}
