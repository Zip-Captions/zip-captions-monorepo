import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/providers/active_locale_id_provider.dart';
import 'package:zip_core/src/providers/device_locales_provider.dart';
import 'package:zip_core/src/providers/locale_info_provider.dart';

part 'resolved_locale_id_provider.g.dart';

/// The locale the app falls back to when nothing else matches
/// (Amendment 03 section 6: "a piece of software built and maintained in
/// Canada by Canadians").
const String kDefaultSpeechLocaleId = 'en-CA';

/// Resolves the best locale ID to use for the active STT engine.
///
/// Implements the resolution order of Amendment 03 section 6, which replaces
/// the Phase 1 "first supported locale when no explicit selection" rule. The
/// result is never an arbitrary first supported locale:
/// 1. The app's explicit choice (`activeLocaleId`), when set: an exact match,
///    else a language-only match, else passed through — the engine or
///    `SttSessionManager` surfaces a `localeNotSupported` error if it cannot
///    handle it.
/// 2. Otherwise the phone's preferred languages ([deviceLocalesProvider]), in
///    order: each an exact match, then a language-only match. First hit wins.
/// 3. Otherwise `en-CA`: an exact match, then a language-only match (`en`).
/// 4. Otherwise `en-CA` is passed through, so the engine or the session
///    manager reports `localeNotSupported`.
/// 5. While the supported list is empty (loading): the first device locale if
///    there is one, else `en-CA`.
///
/// Matching ignores case and treats `-` and `_` as the same; a match returns
/// the supported list's own id string. A language-only tie prefers region
/// `CA`, then `US`, then the first listed.
///
/// Kept alive, and watches [deviceLocalesProvider] so a device language
/// change re-resolves. `zip_broadcast`'s `BroadcastRecordingNotifier` reads
/// this same resolver, so its default changes the same way.
@Riverpod(keepAlive: true)
String resolvedLocaleId(Ref ref) {
  final activeLocaleId = ref.watch(activeLocaleIdNotifierProvider);
  final localeInfoAsync = ref.watch(localeInfoProvider);
  final deviceLocales = ref.watch(deviceLocalesProvider);
  final supportedLocales =
      localeInfoAsync.valueOrNull ?? const <SpeechLocale>[];

  if (activeLocaleId != null) {
    // Step 1: exact, then language-only, else pass it through as today.
    return _exactMatch(supportedLocales, activeLocaleId) ??
        _languageOnlyMatch(supportedLocales, activeLocaleId) ??
        activeLocaleId;
  }

  if (supportedLocales.isEmpty) {
    // Step 5 (loading): the first device locale if there is one, else en-CA.
    return deviceLocales.isNotEmpty
        ? deviceLocales.first
        : kDefaultSpeechLocaleId;
  }

  // Step 2: the phone's preferred languages, in order.
  for (final tag in deviceLocales) {
    final match =
        _exactMatch(supportedLocales, tag) ??
        _languageOnlyMatch(supportedLocales, tag);
    if (match != null) return match;
  }

  // Steps 3 and 4: en-CA exact, then language-only, then passed through.
  return _exactMatch(supportedLocales, kDefaultSpeechLocaleId) ??
      _languageOnlyMatch(supportedLocales, kDefaultSpeechLocaleId) ??
      kDefaultSpeechLocaleId;
}

/// The comparison form of a locale tag: lower-case, `-` and `_` equal.
String _canonical(String localeId) =>
    localeId.toLowerCase().replaceAll('_', '-');

/// The supported locale whose id equals [wanted], ignoring case and the
/// `-`/`_` separator; returns the supported list's own id string.
String? _exactMatch(List<SpeechLocale> supported, String wanted) {
  final target = _canonical(wanted);
  for (final locale in supported) {
    if (_canonical(locale.localeId) == target) return locale.localeId;
  }
  return null;
}

/// The supported locale whose language equals [wanted]'s language, with the
/// Amendment 03 tie-break: region `CA` first, then `US`, then the first
/// listed.
String? _languageOnlyMatch(List<SpeechLocale> supported, String wanted) {
  final language = _languageOf(wanted);
  if (language == null) return null;
  String? usMatch;
  String? firstMatch;
  for (final locale in supported) {
    if (locale.languageCode != language) continue;
    final region = _regionOf(locale.localeId);
    if (region == 'ca') return locale.localeId;
    if (region == 'us') usMatch ??= locale.localeId;
    firstMatch ??= locale.localeId;
  }
  return usMatch ?? firstMatch;
}

String? _languageOf(String localeId) {
  final canonical = _canonical(localeId);
  final separator = canonical.indexOf('-');
  final language = separator == -1
      ? canonical
      : canonical.substring(0, separator);
  return language.isEmpty ? null : language;
}

/// The region subtag, lower-cased: the subtag after the language, skipping a
/// four-letter script subtag (`zh-Hant-CA` has region `ca`). `null` when the
/// tag has no region (`zh`, `zh-Hant`).
String? _regionOf(String localeId) {
  final parts = _canonical(localeId).split('-');
  var index = 1;
  if (index < parts.length && _isScript(parts[index])) index++;
  return index < parts.length && parts[index].isNotEmpty ? parts[index] : null;
}

/// A script subtag is exactly four ASCII letters (BCP 47), such as `hant`.
bool _isScript(String subtag) => RegExp(r'^[a-z]{4}$').hasMatch(subtag);
