// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ice_server_provider_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$iceServerProviderHash() => r'b1455469d0ba666e5b795a0aab9cffd4f52dca69';

/// Provides the app's [IceServerProvider].
///
/// No app-startup override needed — the real implementation needs only
/// [turnCredentialServiceProvider] and [iceServerUrls] (the
/// `--dart-define`-overridable STUN/TURN URL list, matching
/// `supabaseUrl`'s pattern).
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
