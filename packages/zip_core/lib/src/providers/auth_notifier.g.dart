// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authNotifierHash() => r'd8991a9cdf7b2abe4f30fa4398b51a489cf6d424';

/// Broadcaster authentication orchestration (S-15).
///
/// Calls [AuthService] explicitly (this project's Riverpod convention is
/// explicit calls from notifiers, not reactive watchers) and republishes its
/// [AuthState] stream. Session restore (F-BA-2) reads [AuthService] state
/// synchronously in [build] — no network round trip blocks app start.
///
/// Copied from [AuthNotifier].
@ProviderFor(AuthNotifier)
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>.internal(
  AuthNotifier.new,
  name: r'authNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthNotifier = Notifier<AuthState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
