// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localeNotifierHash() => r'639d137f7e61f4816bf9fea3938203c3f640053d';

/// Manages the user's display locale (BR-06).
///
/// Persistence key: `app_locale` (unprefixed — shared across apps).
///
/// Fallback chain:
/// 1. User-persisted locale
/// 2. Device locale
/// 3. English (`en`)
///
/// Copied from [LocaleNotifier].
@ProviderFor(LocaleNotifier)
final localeNotifierProvider =
    NotifierProvider<LocaleNotifier, Locale>.internal(
      LocaleNotifier.new,
      name: r'localeNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$localeNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LocaleNotifier = Notifier<Locale>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
