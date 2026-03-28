// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_locale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$speechLocaleNotifierHash() =>
    r'c288f7b9bf6772d8debf23931f5d36b4fee59560';

/// Manages the user's speech recognition locale (BR-07, BR-08).
///
/// Phase 0: stub returning a placeholder. Phase 1: queries SttEngine.
///
/// Copied from [SpeechLocaleNotifier].
@ProviderFor(SpeechLocaleNotifier)
final speechLocaleNotifierProvider =
    NotifierProvider<SpeechLocaleNotifier, SpeechLocale>.internal(
      SpeechLocaleNotifier.new,
      name: r'speechLocaleNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$speechLocaleNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SpeechLocaleNotifier = Notifier<SpeechLocale>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
