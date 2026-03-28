import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/models/speech_locale.dart';

part 'speech_locale_provider.g.dart';

/// Manages the user's speech recognition locale (BR-07, BR-08).
///
/// Phase 0: stub returning a placeholder. Phase 1: queries SttEngine.
@Riverpod(keepAlive: true)
class SpeechLocaleNotifier extends _$SpeechLocaleNotifier {
  @override
  SpeechLocale build() {
    return const SpeechLocale(
      localeId: 'en-US',
      displayName: 'English (United States)',
    );
  }

  /// Distinct languages from available locales (BR-07).
  ///
  /// Phase 0: returns a single-entry stub list.
  List<({String languageCode, String displayName})>
      get availableLanguages {
    return [
      (languageCode: 'en', displayName: 'English'),
    ];
  }

  /// Regional variants for a given language code (BR-07).
  ///
  /// Phase 0: returns the stub locale for 'en', empty for others.
  List<SpeechLocale> regionsForLanguage(String languageCode) {
    if (languageCode == 'en') {
      return const [
        SpeechLocale(
          localeId: 'en-US',
          displayName: 'English (United States)',
        ),
      ];
    }
    return const [];
  }

  /// Updates the selected speech locale and notifies listeners.
  // ignore: use_setters_to_change_properties
  void select(SpeechLocale locale) {
    state = locale;
  }
}
