// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$obsSettingsNotifierHash() =>
    r'1de78823897b92d20660ec8529f7ade67de8a298';

/// Manages [ObsSettings] persistence.
///
/// Host and port are stored in `SharedPreferences` (`obs.host`, `obs.port`).
/// Password is stored in `FlutterSecureStorage` key `obs.password` — never
/// logged (SEC-U3.2).
///
/// Copied from [ObsSettingsNotifier].
@ProviderFor(ObsSettingsNotifier)
final obsSettingsNotifierProvider =
    NotifierProvider<ObsSettingsNotifier, ObsSettings>.internal(
      ObsSettingsNotifier.new,
      name: r'obsSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$obsSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ObsSettingsNotifier = Notifier<ObsSettings>;
String _$outputTargetSettingsNotifierHash() =>
    r'96bdcfff21780499113e202372b1afcf17946c6e';

/// Manages [OutputTargetSettings] persistence via `SharedPreferences`.
///
/// Copied from [OutputTargetSettingsNotifier].
@ProviderFor(OutputTargetSettingsNotifier)
final outputTargetSettingsNotifierProvider =
    NotifierProvider<
      OutputTargetSettingsNotifier,
      OutputTargetSettings
    >.internal(
      OutputTargetSettingsNotifier.new,
      name: r'outputTargetSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$outputTargetSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OutputTargetSettingsNotifier = Notifier<OutputTargetSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
