import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/active_locale_id_provider.dart';
import 'package:zip_core/src/providers/locale_info_provider.dart';

part 'resolved_locale_id_provider.g.dart';

/// Resolves the best locale ID to use for the active STT engine.
///
/// Implements the fallback chain from the FD:
/// 1. Exact match for the active locale ID in supported locales
/// 2. Language-only match (e.g., 'en' prefix)
/// 3. First supported locale (when no explicit selection)
/// 4. `activeLocaleId` passed through — the engine or `SttSessionManager`
///    surfaces a `localeNotSupported` error if it cannot handle it
@Riverpod(keepAlive: true)
String resolvedLocaleId(Ref ref) {
  final activeLocaleId = ref.watch(activeLocaleIdNotifierProvider);
  final localeInfoAsync = ref.watch(localeInfoProvider);

  // While locales are loading, use activeLocaleId or fallback.
  final supportedLocales = localeInfoAsync.valueOrNull ?? const [];

  // No explicit selection — use first supported or 'en-US'.
  if (activeLocaleId == null) {
    if (supportedLocales.isNotEmpty) {
      return supportedLocales.first.localeId;
    }
    return 'en-US';
  }

  // Exact match.
  final exact = supportedLocales.where(
    (l) => l.localeId == activeLocaleId,
  );
  if (exact.isNotEmpty) return activeLocaleId;

  // Language-only match.
  final lang =
      activeLocaleId.split('-').first.split('_').first.toLowerCase();
  final langMatch = supportedLocales.where(
    (l) => l.languageCode == lang,
  );
  if (langMatch.isNotEmpty) return langMatch.first.localeId;

  // No match in supported locales — return the activeLocaleId anyway.
  // The engine may handle it internally, or SttSessionManager will
  // surface a localeNotSupported error.
  if (supportedLocales.isEmpty) return activeLocaleId;

  return activeLocaleId;
}
