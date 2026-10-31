// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resolved_locale_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$resolvedLocaleIdHash() => r'6e6bee9bb027499bdf7b7ff0ca315d5e398b4e7a';

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
///
/// Copied from [resolvedLocaleId].
@ProviderFor(resolvedLocaleId)
final resolvedLocaleIdProvider = Provider<String>.internal(
  resolvedLocaleId,
  name: r'resolvedLocaleIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$resolvedLocaleIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ResolvedLocaleIdRef = ProviderRef<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
