import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/providers/settings_notifier.dart';
import 'package:zip_captions/src/widgets/appearance_panel.dart';
import 'package:zip_captions/src/widgets/language_pack_section.dart';
import 'package:zip_captions/src/widgets/pop_out_controls.dart';
import 'package:zip_captions/src/widgets/pop_out_scope.dart';
import 'package:zip_captions/src/widgets/recording_controls_bar.dart';
import 'package:zip_captions/src/widgets/speech_explainer_gate.dart';
import 'package:zip_captions/src/widgets/start_failure_view.dart';
import 'package:zip_core/zip_core.dart';

/// Recording screen — shows the live caption feed and playback controls.
///
/// Auto-navigates to `/history` when [RecordingState] transitions to
/// [StoppedState] (BR-U5-01). Invalidates [transcriptSessionListProvider]
/// before navigation so HistoryScreen loads fresh data (REL-U5.1, NFR-DQ2=A).
class RecordingScreen extends ConsumerStatefulWidget {
  /// Creates a [RecordingScreen].
  ///
  /// [platform] is only for tests: it pins the platform the iOS explainer gate
  /// and the failure panel decide on.
  const RecordingScreen({this.platform, super.key});

  /// The platform to decide for, or `null` to read the real one.
  final TargetPlatform? platform;

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _showAppearancePanel = false;

  /// The failure `start()` left behind, or `null` while captioning is fine.
  ///
  /// Set only after `start()` has finished (BR-U10-10), so the panel never
  /// flashes while a slow start is still in flight.
  RecordingError? _startFailure;

  /// The session whose stop notice has already been shown, so the notice is
  /// one-time per session (BR-U10-23).
  String? _noticeShownFor;

  /// The session whose "no transcript was saved" notice has already been
  /// shown, so that notice too is one-time per session (Amendment 03
  /// section 7, Q-2).
  String? _noTranscriptNoticeShownFor;

  TargetPlatform get _platform => widget.platform ?? Theme.of(context).platform;

  /// Runs the screen's entry sequence.
  ///
  /// [SpeechExplainerGate] is the only caller, on every platform: it fires
  /// immediately where no explainer is needed and from "Continue" on iOS. The
  /// screen must not start the session as well, or a fresh install runs
  /// `start()` twice in one frame (Q-1).
  Future<void> _startIfNeeded() async {
    if (!mounted) return;
    final notifier = ref.read(recordingStateNotifierProvider.notifier);
    final current = ref.read(recordingStateNotifierProvider);
    if (current is StoppedState) {
      notifier.clearSession();
    } else if (current is! IdleState) {
      // recording / paused / reconnecting: a session is already active, so
      // leave it alone.
      return;
    }
    await _runStart();
  }

  /// Awaits `start()` and records the failure it left behind (BR-U10-10).
  Future<void> _runStart() async {
    final notifier = ref.read(recordingStateNotifierProvider.notifier);
    // Cleared before the await so a retry does not flash the old panel. The
    // gate may call this from its own build, so the clear is deferred.
    if (mounted && _startFailure != null) {
      setState(() => _startFailure = null);
    }
    await notifier.start();
    if (!mounted) return;
    final state = ref.read(recordingStateNotifierProvider);
    final error = notifier.lastError;
    setState(() {
      _startFailure = state is IdleState && error != null ? error : null;
    });
  }

  /// Re-runs `start()` from the failure panel's "Try again".
  Future<void> _retry() async {
    ref.read(recordingStateNotifierProvider.notifier).clearSession();
    await _runStart();
  }

  /// The one notice for a stop (Amendment 07, BR-U10-65/66), or `null` for
  /// none.
  ///
  /// The cause is [errorTitle] (BR-U10-23) or, without an error, the
  /// inactivity stop after [inactivityMinutes] (BR-U10-53). The save outcome
  /// is [outcome]: `nothingRecognised`, `saveFailed` or `null` (BR-U10-60).
  static String? _stopNotice(
    ZcStrings strings, {
    required String? errorTitle,
    required int? inactivityMinutes,
    required TranscriptSaveResult? outcome,
  }) {
    final outcomeNotice = switch (outcome) {
      TranscriptSaveResult.nothingRecognised => strings.noTranscriptSavedNotice,
      TranscriptSaveResult.saveFailed => strings.transcriptSaveFailedNotice,
      TranscriptSaveResult.saved || null => null,
    };
    if (errorTitle != null) {
      return outcomeNotice == null
          ? errorTitle
          : strings.stopErrorWithSaveOutcomeNotice(
              errorTitle: errorTitle,
              saveOutcomeNotice: outcomeNotice,
            );
    }
    if (inactivityMinutes != null) {
      return switch (outcome) {
        TranscriptSaveResult.nothingRecognised =>
          strings.inactivityStopNoTranscriptNoticeFor(inactivityMinutes),
        TranscriptSaveResult.saveFailed =>
          strings.inactivityStopSaveFailedNoticeFor(inactivityMinutes),
        TranscriptSaveResult.saved ||
        null => strings.inactivityStopNoticeFor(inactivityMinutes),
      };
    }
    return outcomeNotice;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingStateNotifierProvider);
    final entriesAsync = ref.watch(onScreenCaptionTargetProvider);
    final settings = ref.watch(displaySettingsProvider);
    final notifier = ref.read(displaySettingsProvider.notifier);
    final recordingNotifier = ref.read(recordingStateNotifierProvider.notifier);

    ref.listen<RecordingState>(recordingStateNotifierProvider, (prev, next) {
      if (next is StoppedState && context.mounted) {
        final strings = ref.read(zcStringsProvider).valueOrNull;
        // Amendment 07 (BR-U10-65/66): one notice per stop, built from the
        // stop's cause and its save outcome, instead of two queued SnackBars.
        //
        // The cause. BR-U10-23: an error stop -> the failure title,
        // classified the same way as the failure panel, and never with
        // "Open settings". Once per session.
        final error = recordingNotifier.lastError;
        String? errorTitle;
        if (error != null && _noticeShownFor != next.sessionId) {
          _noticeShownFor = next.sessionId;
          if (strings != null) {
            errorTitle = StartFailureView.from(
              error,
              platform: _platform,
              isWeb: kIsWeb,
            ).title(strings);
          }
        }
        // BR-U10-53 (Amendment 05): the app stopped the session after a long
        // silence, read once from zip_core's stop-reason provider (`take`
        // resets it). A user, error or refused-resume stop records no reason.
        final stopReason = ref
            .read(sessionStopReasonNotifierProvider.notifier)
            .take();
        int? inactivityMinutes;
        if (stopReason == SessionStopReason.inactivity) {
          final timeout = ref.read(speechInactivityTimeoutProvider);
          inactivityMinutes = timeout.inMinutes < 1 ? 1 : timeout.inMinutes;
        }
        // The save outcome. Q-2 (Amendment 03 section 7, Step 29b): the
        // outcome read here is this session's, because the writer target owns
        // its lifetime: it records the result on stop and forgets it when a
        // new session starts. The screen only reads it, never writes or
        // clears it; a provider write from inside this listener re-created
        // the provider's notifier and threw riverpod 2.6's
        // `LateInitializationError`. BR-U10-60: only nothing recognised and a
        // failed save have a notice, and only with capture on. Once per
        // session.
        final captureOn = ref
            .read(transcriptSettingsNotifierProvider)
            .captureEnabled;
        final read = ref.read(transcriptSaveOutcomeProvider);
        TranscriptSaveResult? outcome;
        if (captureOn &&
            (read == TranscriptSaveResult.nothingRecognised ||
                read == TranscriptSaveResult.saveFailed) &&
            _noTranscriptNoticeShownFor != next.sessionId) {
          _noTranscriptNoticeShownFor = next.sessionId;
          outcome = read;
        }
        final notice = strings == null
            ? null
            : _stopNotice(
                strings,
                errorTitle: errorTitle,
                inactivityMinutes: inactivityMinutes,
                outcome: outcome,
              );
        if (notice != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(notice)),
          );
        }
        ref.invalidate(transcriptSessionListProvider);
        context.go('/history');
      }
    });

    final entries = entriesAsync.valueOrNull ?? const [];
    final popOut = PopOutScope.of(context);

    final strings = ref.watch(zcStringsProvider).valueOrNull;
    final failure = _startFailure;

    // The gate stays mounted whatever happens, because it owns the start
    // sequence: replacing it with the panel would mount a fresh gate on
    // "Try again" and its `initState` would start the session a second time
    // (Q-1). A failure can only exist after the gate has been passed, so the
    // panel never has to show over the explainer.
    return SpeechExplainerGate(
      platform: _platform,
      strings: strings ?? const ZcStrings.fromMap({}),
      onStart: _startIfNeeded,
      onBackToHome: () => context.go('/'),
      builder: (context) {
        if (failure != null && strings != null) {
          // BR-U10-10: the failure panel replaces the caption area, and the
          // controls bar is gone with it (it would spin forever on
          // IdleState).
          final view = StartFailureView.from(
            failure,
            platform: _platform,
            isWeb: kIsWeb,
          );
          return Scaffold(
            body: StartFailurePanel(
              view: view,
              strings: strings,
              // Amendment 04 (BR-U10-46): only the on-device refusal can be
              // fixed by fetching the language, and only for the locale this
              // session resolved.
              languagePackSection:
                  view.kind == StartFailureKind.onDeviceUnavailable
                  ? LanguagePackSection(
                      localeId: ref.read(resolvedLocaleIdProvider),
                      strings: strings,
                      platform: _platform,
                    )
                  : null,
              onTryAgain: () => unawaited(_retry()),
              onOpenSettings: () =>
                  unawaited(recordingNotifier.openMicrophoneSettings()),
              onBack: () => context.go('/'),
            ),
          );
        }
        return _buildCaptionBody(
          popOut: popOut,
          entries: entries,
          settings: settings,
          state: state,
          notifier: notifier,
          recordingNotifier: recordingNotifier,
        );
      },
    );
  }

  Widget _buildCaptionBody({
    required PopOutState? popOut,
    required List<CaptionDisplayEntry> entries,
    required DisplaySettings settings,
    required RecordingState state,
    required DisplaySettingsNotifier notifier,
    required RecordingStateNotifier recordingNotifier,
  }) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showAppearancePanel = false),
            child: Column(
              children: [
                // UX-PIP-05 as v1 ships it: while popped out the captions are
                // in the pop-out, so the hint and the return action take the
                // caption surface's place in the main window. They go with
                // the flag (R-M6: every close path except the lazy `'-1'`
                // fallback). The caption target stays watched above, so the
                // pop-out keeps its source.
                if (popOut?.enabled ?? false)
                  Expanded(
                    child: PopOutBanner(onReturn: popOut!.onToggle),
                  )
                else
                  Expanded(
                    child: CaptionDisplayWidget(
                      entries: entries,
                      settings: settings,
                      // UX-PIP-04 / BR-U8.1-11: on a platform that cannot
                      // host a sub-window nothing renders, not even a
                      // disabled pill.
                      controls: popOut == null || !popOut.visible
                          ? null
                          : PopOutInSurfaceToggle(
                              isPoppedOut: popOut.enabled,
                              enabled: popOut.available,
                              onToggle: popOut.onToggle,
                              reason: popOut.reason,
                              openFailed: popOut.openFailed,
                            ),
                    ),
                  ),
                RecordingControlsBar(
                  state: state,
                  onPause: recordingNotifier.pause,
                  onResume: recordingNotifier.resume,
                  onStop: recordingNotifier.stop,
                ),
              ],
            ),
          ),
          if (_showAppearancePanel)
            Positioned(
              bottom: 80,
              right: 16,
              child: AppearancePanel(
                settings: settings,
                notifier: notifier,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Appearance',
        onPressed: () => setState(
          () => _showAppearancePanel = !_showAppearancePanel,
        ),
        child: const Icon(Icons.text_fields),
      ),
    );
  }
}
