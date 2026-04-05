// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localeInfoHash() => r'9a54500405095b7b87b551978daf772cfefd3581';

/// Exposes the list of locales available for speech recognition.
///
/// Queries the active [SttEngine]'s `supportedLocales()`. Returns an empty
/// list when no engine is available.
///
/// Copied from [localeInfo].
@ProviderFor(localeInfo)
final localeInfoProvider =
    AutoDisposeFutureProvider<List<SpeechLocale>>.internal(
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
typedef LocaleInfoRef = AutoDisposeFutureProviderRef<List<SpeechLocale>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
