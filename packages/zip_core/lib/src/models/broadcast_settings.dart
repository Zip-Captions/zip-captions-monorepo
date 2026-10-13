import 'package:freezed_annotation/freezed_annotation.dart';

part 'broadcast_settings.freezed.dart';

/// The maximum number of UTF-16 code units a session name may contain
/// (`business-rules.md` Rule 7, Functional Design Q7).
const broadcastSessionNameMaxLength = 100;

/// A single [BroadcastSettings.validateSessionName] failure category
/// (`business-rules.md` Rule 7). UI strings for each key live in the ARB
/// files — never hardcoded here.
enum SessionNameError {
  /// The trimmed name is empty.
  empty,

  /// The name exceeds [broadcastSessionNameMaxLength] code units.
  tooLong,

  /// The name contains a control character (U+0000–U+001F or U+007F).
  controlChar,
}

/// Persisted broadcaster-local settings for Zip Broadcast's Broadcast UI
/// (fixed shape, Application Design). Loaded/persisted by
/// `BroadcastSettingsNotifier` (Phase 1 settings pattern).
@freezed
abstract class BroadcastSettings with _$BroadcastSettings {
  /// Creates a [BroadcastSettings].
  const factory BroadcastSettings({
    /// The session name shown to viewers; validated by
    /// [validateSessionName] before `goLive()` ever reads it.
    @Default('') String sessionName,

    /// Whether `goLive()` should start captioning automatically if it is
    /// currently idle (`business-rules.md` Rule 3). Independent-by-default
    /// (Application Design Q3).
    @Default(false) bool autoStartCaptioning,
  }) = _BroadcastSettings;

  const BroadcastSettings._();

  /// Validates [name] against the three categories in `business-rules.md`
  /// Rule 7, checked in this fixed order. Returns the failing category, or
  /// `null` if [name] is valid. Never returns more than one category for a
  /// single input (PBT-03 invariant, NFR Requirements Q6).
  static SessionNameError? validateSessionName(String name) {
    if (name.trim().isEmpty) return SessionNameError.empty;
    if (name.length > broadcastSessionNameMaxLength) {
      return SessionNameError.tooLong;
    }
    final hasControlChar = name.codeUnits.any(
      (c) => (c >= 0x00 && c <= 0x1F) || c == 0x7F,
    );
    if (hasControlChar) return SessionNameError.controlChar;
    return null;
  }
}
