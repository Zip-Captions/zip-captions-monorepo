import 'package:flutter/foundation.dart';
import 'package:zip_core/zip_core.dart';

/// What the on-device-unavailable panel offers for a missing language
/// (BR-U10-46). Closed: every input maps to exactly one.
enum LanguagePackAction {
  /// A "Download" button naming the language.
  download,

  /// The scheduled state: the platform has the download pending and will
  /// satisfy it later (BR-U10-47a).
  scheduled,

  /// The existing text plus the iOS instructions (Dictation and a keyboard).
  instructions,

  /// The existing text and nothing else.
  none,
}

/// The first iOS major version where the app can download the language
/// itself (`DictationTranscriber` and `AssetInventory`, iOS 26.0+).
const int kIosLanguagePackMajor = 26;

/// BR-U10-46, TP-28: the panel action as a pure, total function of the
/// platform, the OS version and the language-pack [status].
///
/// [osVersion] is the iOS major version or the Android SDK level, or null when
/// unreadable. Android never branches on it: the runner already answers
/// `unknown` below API 33, and API 33 and 34 differ only in how progress
/// arrives, not in what the panel offers.
///
/// - iOS 26 and later (or an unreadable version): downloadable is download,
///   downloading is scheduled, unknown is instructions, installed and
///   unsupported are none.
/// - iOS below 26: instructions, whatever the status.
/// - Android: downloadable is download, downloading is scheduled, installed,
///   unsupported and unknown are none.
/// - Any other platform: none.
LanguagePackAction languagePackActionFor({
  required TargetPlatform platform,
  required int? osVersion,
  required LanguagePackStatus status,
}) {
  switch (platform) {
    case TargetPlatform.iOS:
      if (osVersion != null && osVersion < kIosLanguagePackMajor) {
        return LanguagePackAction.instructions;
      }
      return switch (status) {
        LanguagePackStatus.downloadable => LanguagePackAction.download,
        LanguagePackStatus.downloading => LanguagePackAction.scheduled,
        LanguagePackStatus.unknown => LanguagePackAction.instructions,
        LanguagePackStatus.installed ||
        LanguagePackStatus.unsupported => LanguagePackAction.none,
      };
    case TargetPlatform.android:
      return switch (status) {
        LanguagePackStatus.downloadable => LanguagePackAction.download,
        LanguagePackStatus.downloading => LanguagePackAction.scheduled,
        LanguagePackStatus.installed ||
        LanguagePackStatus.unsupported ||
        LanguagePackStatus.unknown => LanguagePackAction.none,
      };
    case TargetPlatform.fuchsia ||
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows:
      return LanguagePackAction.none;
  }
}
