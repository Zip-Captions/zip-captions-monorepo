import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';

/// Bridges `BroadcastSessionNotifier` (zip_core) to whichever recording
/// machinery the host app actually uses (new seam, Functional Design Q1).
///
/// Application Design's F2 step 8 ("explicit call to the recording
/// notifier's start") and its coupling note never specify how a `zip_core`
/// notifier reaches the app's recording notifier — `zip_broadcast`'s
/// `BroadcastRecordingNotifier` is a `zip_broadcast` class, unreachable
/// from `zip_core` by dependency direction. [DefaultCaptioningStarter]
/// (below) covers `zip_captions`' own single-engine
/// [RecordingStateNotifier]; `zip_broadcast`'s `main.dart` overrides
/// `captioningStarterProvider` with an implementation backed by
/// `BroadcastRecordingNotifier` instead — same override pattern as
/// `authServiceProvider`/`supabaseClientProvider` (Unit 2).
abstract interface class CaptioningStarter {
  /// The app's current captioning activity, derived from its recording
  /// state. Mapping mirrors `RemoteBroadcastTarget._mapActivity` exactly.
  CaptionActivity get currentActivity;

  /// Starts captioning if it is currently idle. A no-op if
  /// [currentActivity] is already [CaptionActivity.active] or
  /// [CaptionActivity.paused] — an already-running session is never
  /// restarted or interrupted (`business-rules.md` Rule 3).
  Future<void> start();
}

/// Default [CaptioningStarter], wrapping `zip_captions`'
/// [RecordingStateNotifier] (single-engine). `zip_broadcast` overrides
/// `captioningStarterProvider` with a `BroadcastRecordingNotifier`-backed
/// implementation instead (Q1).
///
/// Takes a [Ref] rather than the notifier instance directly: a
/// [Notifier]'s own `state` getter is `@protected`, readable only from
/// within the notifier itself — reading the current value from outside
/// goes through the provider, not the notifier object.
class DefaultCaptioningStarter implements CaptioningStarter {
  /// Creates a [DefaultCaptioningStarter] reading
  /// `recordingStateNotifierProvider` through [_ref].
  DefaultCaptioningStarter(this._ref);

  final Ref _ref;

  @override
  CaptionActivity get currentActivity =>
      switch (_ref.read(recordingStateNotifierProvider)) {
        RecordingActiveState() => CaptionActivity.active,
        PausedState() || ReconnectingState() => CaptionActivity.paused,
        IdleState() || StoppedState() => CaptionActivity.inactive,
      };

  @override
  Future<void> start() =>
      _ref.read(recordingStateNotifierProvider.notifier).start();
}
