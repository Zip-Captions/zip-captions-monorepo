// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_window_controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$overlayWindowControllerHash() =>
    r'47b6af6efa155fe8987790e9f7e82702d6520e08';

/// The one external display window controller, alive for the app container.
///
/// Built from the engine's one host (NFR Design §2), exactly like the pop-out,
/// so the router is the only writer of `desktop_multi_window`'s single
/// method-handler slot and both controllers share one display observer and one
/// close channel (review round 5, finding 1).
///
/// Keeping the controller alive is what keeps its window, timer and display
/// observer alive: it is a resource, not a per-watch value.
///
/// Copied from [overlayWindowController].
@ProviderFor(overlayWindowController)
final overlayWindowControllerProvider =
    Provider<OverlayWindowController>.internal(
      overlayWindowController,
      name: r'overlayWindowControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$overlayWindowControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OverlayWindowControllerRef = ProviderRef<OverlayWindowController>;
String _$externalDisplayStatusHash() =>
    r'586d0ce072209f2b6b6aedc78d09f3928e53098c';

/// The state the external display controls render.
///
/// Replays the current status first: [OverlayWindowController.statusChanges]
/// is a broadcast stream, so a plain subscription would stay in
/// `AsyncLoading` on a capable machine (the controller starts `Off` and emits
/// nothing until a transition), and the controls would never render.
///
/// Copied from [externalDisplayStatus].
@ProviderFor(externalDisplayStatus)
final externalDisplayStatusProvider =
    AutoDisposeStreamProvider<ExternalDisplayStatus>.internal(
      externalDisplayStatus,
      name: r'externalDisplayStatusProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$externalDisplayStatusHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ExternalDisplayStatusRef =
    AutoDisposeStreamProviderRef<ExternalDisplayStatus>;
String _$displayListHash() => r'0c10ad315c3322914ddd0b3b32411d5424c31813';

/// The connected displays, per the enumerator's event contract.
///
/// Reads the host's shared list rather than the controller's lease: the host
/// owns the one observer now, and the controls want the engine's list.
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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
