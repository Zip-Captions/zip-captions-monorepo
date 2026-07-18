// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'obs_connection_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$obsWebSocketTargetHash() =>
    r'4bdaa1eb428b485d671845e9afac77e6a03e7ec8';

/// Singleton [ObsWebSocketTarget] for this app session.
///
/// Re-created only when connection credentials (host, port, password) change.
/// [ObsSettings.connectionVerified] changes are intentionally ignored here to
/// avoid dropping an active connection when the user runs a test in Settings.
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
    r'd6ea4b95e21a68258a0fe72322da0fd2fd86354b';

/// Manages the live OBS WebSocket connection and exposes [ObsConnectionStatus].
///
/// Self-manages connection based on `OutputTargetSettingsNotifier.obsEnabled`
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
