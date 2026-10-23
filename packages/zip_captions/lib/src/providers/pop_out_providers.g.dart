// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pop_out_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$captionsEngineAvailableHash() =>
    r'5765c73006708f7601a8cdb62da280bf82662d09';

/// Whether Zip Captions can caption at all — the app's own gate, which the
/// pop-out's availability rule reuses (FD domain-entities §3.1, RQ-2 A).
///
/// This app builds its engine at startup and publishes it through
/// [sttEngineProvider]; nothing registers into the registry here either, so
/// the gate is that one value and nothing else (BR-PIP-13).
///
/// Copied from [captionsEngineAvailable].
@ProviderFor(captionsEngineAvailable)
final captionsEngineAvailableProvider = AutoDisposeProvider<bool>.internal(
  captionsEngineAvailable,
  name: r'captionsEngineAvailableProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$captionsEngineAvailableHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CaptionsEngineAvailableRef = AutoDisposeProviderRef<bool>;
String _$popOutWindowControllerHash() =>
    r'fd6a1ff9e1a77095e6d067c1a7bbaa779f94ad84';

/// The pop-out window controller, alive for the app container.
///
/// Built from the engine's one host (NFR Design §2), so the external display
/// and the pop-out share a router, a display observer and a close channel.
///
/// Copied from [popOutWindowController].
@ProviderFor(popOutWindowController)
final popOutWindowControllerProvider =
    Provider<OverlayWindowController>.internal(
      popOutWindowController,
      name: r'popOutWindowControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$popOutWindowControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PopOutWindowControllerRef = ProviderRef<OverlayWindowController>;
String _$displayListHash() => r'db4c6626dc9087cc9f851dd7d5393a8dc93811a6';

/// The connected displays, per the enumerator's event contract.
///
/// Copied from [displayList].
@ProviderFor(displayList)
final displayListProvider =
    AutoDisposeStreamProvider<List<DisplayInfo>>.internal(
      displayList,
      name: r'displayListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$displayListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DisplayListRef = AutoDisposeStreamProviderRef<List<DisplayInfo>>;
String _$popOutStatusHash() => r'2423e201a14b9009f016481f0801f4076354df06';

/// The pop-out's status, replaying the current one first (the stream is a
/// broadcast, and the controller starts `Off`).
///
/// The shell watches this rather than reading `controller.status` once at
/// build, so a status change — a failed display probe leaves the controller
/// `Unsupported` — reaches the chrome and its toggle (review round 3,
/// finding 3). It mirrors `zip_broadcast`'s provider of the same name.
///
/// Copied from [popOutStatus].
@ProviderFor(popOutStatus)
final popOutStatusProvider =
    AutoDisposeStreamProvider<ExternalDisplayStatus>.internal(
      popOutStatus,
      name: r'popOutStatusProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$popOutStatusHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PopOutStatusRef = AutoDisposeStreamProviderRef<ExternalDisplayStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
