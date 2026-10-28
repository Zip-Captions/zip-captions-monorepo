import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_locales_provider.g.dart';

/// The phone's preferred languages, most preferred first, as BCP-47 tags
/// (e.g. `['en-CA', 'fr-CA']`).
///
/// The default reads the platform dispatcher's locale list. Tests override
/// this provider so the locale resolution order
/// (`resolvedLocaleIdProvider`, Amendment 03 section 6) is deterministic and
/// driver-free.
@Riverpod(keepAlive: true)
List<String> deviceLocales(Ref ref) {
  return WidgetsBinding.instance.platformDispatcher.locales
      .map((locale) => locale.toLanguageTag())
      .toList(growable: false);
}
