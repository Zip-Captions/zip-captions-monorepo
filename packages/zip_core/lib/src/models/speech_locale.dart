import 'package:freezed_annotation/freezed_annotation.dart';

part 'speech_locale.freezed.dart';

/// Represents a locale available for speech recognition.
///
/// The granularity of locale identifiers varies by STT engine. The [localeId]
/// field stores whatever the engine provides and is treated as an opaque key.
@immutable
@freezed
abstract class SpeechLocale with _$SpeechLocale {
  /// Creates a [SpeechLocale] with the given identifier and display name.
  const factory SpeechLocale({
    /// Locale identifier as reported by the STT engine. May be language-only
    /// (e.g., `en`), language-region (e.g., `en-US`), or engine-specific.
    required String localeId,

    /// Human-readable name in the user's current display locale.
    required String displayName,
  }) = _SpeechLocale;

  const SpeechLocale._();

  /// Extracts the language portion of [localeId].
  ///
  /// Returns everything before the first hyphen or underscore. If neither is
  /// present, returns the full [localeId]. Used for fallback matching when an
  /// exact match is unavailable.
  String get languageCode {
    final separatorIndex = localeId.indexOf(RegExp('[_-]'));
    if (separatorIndex == -1) return localeId.toLowerCase();
    return localeId.substring(0, separatorIndex).toLowerCase();
  }

  /// Two [SpeechLocale] instances are equal if [localeId] matches
  /// (case-insensitive).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeechLocale &&
          localeId.toLowerCase() == other.localeId.toLowerCase();

  @override
  int get hashCode => localeId.toLowerCase().hashCode;
}
