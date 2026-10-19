// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$viewerSessionNotifierHash() =>
    r'01b38d27a6622646cba7851367c2e351f5e06ed3';

/// The viewer's own session orchestration (fixed shape, Application Design;
/// behaviour designed in `business-logic-model.md` F-7.2-F-7.9).
///
/// One app-lifetime notifier: at most one viewing session, surviving
/// navigation. Every repeated network attempt originates with a user action
/// or the status watch — never with a notifier-owned retry loop
/// (`business-rules.md` Rule 14).
///
/// Copied from [ViewerSessionNotifier].
@ProviderFor(ViewerSessionNotifier)
final viewerSessionNotifierProvider =
    NotifierProvider<ViewerSessionNotifier, ViewerSessionState>.internal(
      ViewerSessionNotifier.new,
      name: r'viewerSessionNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$viewerSessionNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ViewerSessionNotifier = Notifier<ViewerSessionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
