// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_input_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioInputSettingsNotifierHash() =>
    r'e6cb6404d8e4b17dee3d397cc0515d8a8e3ea5f2';

/// Manages the list of audio input configurations for Zip Broadcast.
///
/// Persists a list of preferred [AudioDevice] entries in SharedPreferences.
/// Default: a single system-default microphone entry.
///
/// Shell implementation — multi-engine wiring is deferred to Unit 6.
///
/// Copied from [AudioInputSettingsNotifier].
@ProviderFor(AudioInputSettingsNotifier)
final audioInputSettingsNotifierProvider =
    NotifierProvider<AudioInputSettingsNotifier, List<AudioDevice>>.internal(
      AudioInputSettingsNotifier.new,
      name: r'audioInputSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$audioInputSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AudioInputSettingsNotifier = Notifier<List<AudioDevice>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
