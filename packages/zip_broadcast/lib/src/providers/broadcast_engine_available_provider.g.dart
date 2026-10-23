// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_engine_available_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$broadcastEngineAvailableHash() =>
    r'1356eb47bd089d68ca8950be66bee1a686025001';

/// Whether Zip Broadcast can start captioning right now — the app's own gate,
/// which the pop-out's availability rule reuses (FD domain-entities §3.1,
/// R-M1 resolved: RQ-2 A).
///
/// It derives from the configured audio inputs, not from
/// `SttEngineRegistry`. Nothing in this app registers into the registry: it
/// builds one engine per audio source through `sttEngineFactoryProvider`, so
/// the registry is permanently empty here and would disable the pop-out with
/// "No speech recognition engine" on every machine. Watching the config list
/// also means the value rebuilds when the user adds or removes a source, which
/// watching the registry could not do.
///
/// It does not consult `sttEngineFactoryProvider`: that provider throws when
/// it has no override, and a provider that throws is not a value a control can
/// render. The factory is an app-startup precondition (main overrides it in
/// every build), so the gate is the source list and nothing else.
///
/// Copied from [broadcastEngineAvailable].
@ProviderFor(broadcastEngineAvailable)
final broadcastEngineAvailableProvider = AutoDisposeProvider<bool>.internal(
  broadcastEngineAvailable,
  name: r'broadcastEngineAvailableProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$broadcastEngineAvailableHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BroadcastEngineAvailableRef = AutoDisposeProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
