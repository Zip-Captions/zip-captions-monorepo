// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ice_server_provider_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$iceServerProviderHash() => r'4fd3f887d6f387b803bdf8285eca4c881900d0ca';

/// Provides the app's [IceServerProvider].
///
/// No app-startup override needed — the real implementation needs only
/// [turnCredentialServiceProvider]. Unlike `logical-components.md`'s
/// original sketch, no separately-injected STUN/TURN URL list is needed
/// here: `get_turn_credentials()` already returns them as part of
/// [TurnCredentials.urls], so [SupabaseIceServerProvider] reads them
/// straight from the fetched credentials.
///
/// Copied from [iceServerProvider].
@ProviderFor(iceServerProvider)
final iceServerProviderProvider = Provider<IceServerProvider>.internal(
  iceServerProvider,
  name: r'iceServerProviderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$iceServerProviderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IceServerProviderRef = ProviderRef<IceServerProvider>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
