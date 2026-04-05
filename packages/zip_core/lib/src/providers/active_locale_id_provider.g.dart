// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_locale_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeLocaleIdNotifierHash() =>
    r'7f4c53575bc7ce70dfe00cfb8ff2a3b3531418d1';

/// User-selected locale ID for speech recognition, persisted in
/// SharedPreferences.
///
/// `null` means no explicit selection — the app uses the fallback locale.
///
/// Copied from [ActiveLocaleIdNotifier].
@ProviderFor(ActiveLocaleIdNotifier)
final activeLocaleIdNotifierProvider =
    NotifierProvider<ActiveLocaleIdNotifier, String?>.internal(
      ActiveLocaleIdNotifier.new,
      name: r'activeLocaleIdNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activeLocaleIdNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ActiveLocaleIdNotifier = Notifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
