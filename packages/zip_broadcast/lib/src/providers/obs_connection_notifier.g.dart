// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'obs_connection_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$obsWebSocketTargetHash() =>
    r'f0d9de4c890ee56a505da5b90190599970ce071c';

/// Singleton [ObsWebSocketTarget] for this app session.
///
/// Re-created when [ObsSettingsNotifier] changes.
///
/// Copied from [obsWebSocketTarget].
@ProviderFor(obsWebSocketTarget)
final obsWebSocketTargetProvider = Provider<ObsWebSocketTarget>.internal(
  obsWebSocketTarget,
  name: r'obsWebSocketTargetProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$obsWebSocketTargetHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ObsWebSocketTargetRef = ProviderRef<ObsWebSocketTarget>;
String _$obsConnectionNotifierHash() =>
    r'83943080b1394e9d81f372456729d25b681ea2c3';

/// Manages the live OBS WebSocket connection and exposes [ObsConnectionStatus].
///
/// Self-manages connection based on [OutputTargetSettingsNotifier.obsEnabled]
/// (FD H2). Forwards final captions from [CaptionBus] to OBS when connected.
///
/// Copied from [ObsConnectionNotifier].
@ProviderFor(ObsConnectionNotifier)
final obsConnectionNotifierProvider =
    NotifierProvider<ObsConnectionNotifier, ObsConnectionStatus>.internal(
      ObsConnectionNotifier.new,
      name: r'obsConnectionNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$obsConnectionNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ObsConnectionNotifier = Notifier<ObsConnectionStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
