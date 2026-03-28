// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localeInfoHash() => r'ef882a5268b0c45e4230cb2e9cb48d32247454ab';

/// Exposes the list of locales available for speech recognition.
///
/// Phase 0: returns an empty list (no STT engine to query).
/// Phase 1: queries SttEngine.getAvailableLocales().
///
/// Copied from [localeInfo].
@ProviderFor(localeInfo)
final localeInfoProvider = AutoDisposeProvider<List<SpeechLocale>>.internal(
  localeInfo,
  name: r'localeInfoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localeInfoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocaleInfoRef = AutoDisposeProviderRef<List<SpeechLocale>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
