import 'package:flutter/widgets.dart'
    show Locale, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_locales_provider.g.dart';

/// The phone's preferred languages, most preferred first, as BCP-47 tags
/// (e.g. `['en-CA', 'fr-CA']`).
///
/// The default reads the platform dispatcher's locale list, and rebuilds when
/// the system locale list changes (a device language change), so
/// `resolvedLocaleIdProvider` re-resolves. The provider listens through a
/// [WidgetsBindingObserver], never by replacing the dispatcher's
/// `onLocaleChanged`, which the framework owns. Tests override this provider
/// so the locale resolution order (`resolvedLocaleIdProvider`, Amendment 03
/// section 6) is deterministic and driver-free.
@Riverpod(keepAlive: true)
List<String> deviceLocales(Ref ref) {
  final binding = WidgetsBinding.instance;
  final observer = _LocalesObserver(ref.invalidateSelf);
  binding.addObserver(observer);
  ref.onDispose(() => binding.removeObserver(observer));
  return binding.platformDispatcher.locales
      .map((locale) => locale.toLanguageTag())
      .toList(growable: false);
}

/// Invalidates the provider when the system locale list changes.
class _LocalesObserver with WidgetsBindingObserver {
  _LocalesObserver(this._onChanged);

  final void Function() _onChanged;

  @override
  void didChangeLocales(List<Locale>? locales) => _onChanged();
}
