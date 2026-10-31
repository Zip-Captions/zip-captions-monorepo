import 'package:freezed_annotation/freezed_annotation.dart';

part 'language_pack_service.freezed.dart';

/// Whether the phone has the on-device speech model for a language
/// (Amendment 04 section 3).
enum LanguagePackStatus {
  /// The model is on the phone and ready for use.
  installed,

  /// A download is scheduled or running.
  downloading,

  /// Supported on-device, but the model has to be downloaded first.
  downloadable,

  /// The platform has no on-device model for the language.
  unsupported,

  /// The check failed, or this platform version cannot say.
  unknown,
}

/// The answer to "what is the state of this language's model?".
@freezed
abstract class LanguagePackInfo with _$LanguagePackInfo {
  /// Creates an answer.
  const factory LanguagePackInfo({
    /// The model's state.
    required LanguagePackStatus status,

    /// The language's name in the app's language, from the platform (Flutter
    /// has no locale display names). The locale tag when the platform gave
    /// none.
    required String displayName,
  }) = _LanguagePackInfo;
}

/// One thing the platform reported about a language-pack download.
///
/// Sealed so the panel can switch exhaustively. No field carries free text:
/// a locale tag, a percentage, or a platform error code.
@immutable
sealed class LanguagePackEvent {
  const LanguagePackEvent(this.localeId);

  /// The locale tag the download is for.
  final String localeId;
}

/// The download is under way; [percent] is 0 to 100, or null when the
/// platform reports none.
final class LanguagePackProgress extends LanguagePackEvent {
  /// Creates an event.
  const LanguagePackProgress(super.localeId, {this.percent});

  /// Percent complete, or null when unknown.
  final int? percent;
}

/// The platform scheduled the download but will not satisfy it immediately
/// (for example until the phone is on Wi-Fi), and sends no further updates
/// for it (BR-U10-47a). Not a failure.
final class LanguagePackScheduled extends LanguagePackEvent {
  /// Creates an event.
  const LanguagePackScheduled(super.localeId);
}

/// The download finished and the model is installed.
final class LanguagePackDone extends LanguagePackEvent {
  /// Creates an event.
  const LanguagePackDone(super.localeId);
}

/// The download failed.
final class LanguagePackFailed extends LanguagePackEvent {
  /// Creates an event.
  const LanguagePackFailed(super.localeId, {this.code});

  /// The platform's error code, or null when it gave none (iOS).
  final int? code;
}

/// Asks the platform about, and fetches, on-device speech models.
///
/// Declared here and implemented by the app over method and event channels,
/// the same split as the on-device support checker. The download fetches the
/// platform's model only; recognition stays on-device (BR-U10-49).
abstract interface class LanguagePackService {
  /// The state of [localeId]'s model. Never throws for a platform that cannot
  /// say: that is [LanguagePackStatus.unknown].
  Future<LanguagePackInfo> status(String localeId);

  /// Starts the download for [localeId]. The outcome arrives on [events]. A
  /// platform that cannot start it throws.
  Future<void> download(String localeId);

  /// Download progress and outcomes, for every locale, in order. A single
  /// broadcast stream.
  Stream<LanguagePackEvent> get events;
}
