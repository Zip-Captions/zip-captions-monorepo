import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/models/speech_locale.dart';

part 'locale_info_provider.g.dart';

/// Exposes the list of locales available for speech recognition.
///
/// Phase 0: returns an empty list (no STT engine to query).
/// Unit 2: queries active SttEngine.supportedLocales() via SttEngineProvider.
@riverpod
List<SpeechLocale> localeInfo(Ref ref) {
  return const [];
}
