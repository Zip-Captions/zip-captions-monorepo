// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resolved_locale_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$resolvedLocaleIdHash() => r'9f2353d61eddeaa954fc333b9112cc31ff80879d';

/// Resolves the best locale ID to use for the active STT engine.
///
/// Implements the fallback chain from the FD:
/// 1. Exact match for the active locale ID in supported locales
/// 2. Language-only match (e.g., 'en' prefix)
/// 3. First supported locale (when no explicit selection)
/// 4. `activeLocaleId` passed through — the engine or `SttSessionManager`
///    surfaces a `localeNotSupported` error if it cannot handle it
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
