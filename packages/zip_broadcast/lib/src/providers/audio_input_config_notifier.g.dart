// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_input_config_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioInputConfigNotifierHash() =>
    r'88ad68df48c822b460f1aa670258a7616b38b955';

/// Manages [List<AudioInputConfig>] with SharedPreferences persistence.
///
/// Replaces the Unit 5 shell [AudioInputSettingsNotifier] for Zip Broadcast.
/// Key: `zip_broadcast.audioInputConfigs`. JSON-serialised list (Q9=A).
///
/// Copied from [AudioInputConfigNotifier].
@ProviderFor(AudioInputConfigNotifier)
final audioInputConfigNotifierProvider =
    NotifierProvider<AudioInputConfigNotifier, List<AudioInputConfig>>.internal(
      AudioInputConfigNotifier.new,
      name: r'audioInputConfigNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$audioInputConfigNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AudioInputConfigNotifier = Notifier<List<AudioInputConfig>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
