import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';

part 'locale_info_provider.g.dart';

/// Exposes the list of locales available for speech recognition.
///
/// Queries the active [SttEngine]'s `supportedLocales()`. Returns an empty
/// list when no engine is available.
@riverpod
Future<List<SpeechLocale>> localeInfo(Ref ref) async {
  final engine = ref.watch(sttEngineProvider);
  if (engine == null) return const [];
  return engine.supportedLocales();
}
