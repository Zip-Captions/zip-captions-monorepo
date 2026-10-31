// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_stop_reason_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionStopReasonNotifierHash() =>
    r'032174a8b59f7b03a1771f9c4b7a5f9285cc9e55';

/// The reason the session that most recently stopped was stopped by the app.
///
/// `null` means the stop was not an app-initiated one (the user's Stop, an
/// engine error, a refused resume), or the reason has been consumed. The
/// recording notifier writes it just before the stopped state is published;
/// `RecordingScreen` calls [take] when the state becomes stopped. Like the
/// transcript save outcome, it lets the screen show a one-time notice without
/// any `RecordingState` or `RecordingStateNotifier` API change.
///
/// Kept alive for the app lifetime. Carries an enum only, never any
/// recognised text.
///
/// Copied from [SessionStopReasonNotifier].
@ProviderFor(SessionStopReasonNotifier)
final sessionStopReasonNotifierProvider =
    NotifierProvider<SessionStopReasonNotifier, SessionStopReason?>.internal(
      SessionStopReasonNotifier.new,
      name: r'sessionStopReasonNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sessionStopReasonNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SessionStopReasonNotifier = Notifier<SessionStopReason?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
