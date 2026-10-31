import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'zc_strings.g.dart';

/// The viewer's copy, read from the English ARB file (Design Q6).
///
/// This is the **only** reader of `l10n/arb/app_en.arb` in the app: no
/// `gen-l10n`, no `flutter_localizations`, no `intl`. The ARB is loaded once
/// through `rootBundle` and exposed as one getter per key, so widget tests
/// can substitute a sentinel map and prove the screens render ARB values
/// rather than inline literals.
class ZcStrings {
  /// Creates a [ZcStrings] over the decoded ARB values (used by [load]
  /// and by tests).
  const ZcStrings.fromMap(this._values);

  /// The ARB asset path declared in `pubspec.yaml`.
  static const assetPath = 'l10n/arb/app_en.arb';

  final Map<String, String> _values;

  /// The copy this instance carries, keyed by ARB key and containing only
  /// `String` values. ARB metadata (`@key` blocks, `@@locale`) is stripped
  /// by [load].
  Map<String, String> get values => UnmodifiableMapView(_values);

  /// Whether this instance carries [key].
  bool containsKey(String key) => _values.containsKey(key);

  /// Loads and parses the bundled ARB file.
  ///
  /// ARB files carry `@key` description objects and `@@locale` alongside the
  /// copy. Those entries are dropped here rather than deferred to a lazy
  /// `Map.cast`: a cast keeps the original map and throws on any later read
  /// of a metadata value, which would surface as a runtime error in any code
  /// that walks the map.
  static Future<ZcStrings> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ZcStrings.fromMap({
      for (final entry in decoded.entries)
        if (!entry.key.startsWith('@') && entry.value is String)
          entry.key: entry.value as String,
    });
  }

  String _value(String key) => _values[key] ?? key;

  /// Fills the one `{sessionName}` placeholder in [key].
  String _withName(String key, String sessionName) =>
      _value(key).replaceAll('{sessionName}', sessionName);

  /// Title of the join-broadcast screen.
  String get joinBroadcastTitle => _value('joinBroadcastTitle');

  /// Label of the drawer's join affordance (a shorter wording).
  String get navJoinBroadcast => _value('navJoinBroadcast');

  /// Label of the join screen text field.
  String get joinBroadcastFieldLabel => _value('joinBroadcastFieldLabel');

  /// Label of the join submit button.
  String get joinBroadcastSubmit => _value('joinBroadcastSubmit');

  /// Inline error for unparseable join input.
  String get joinBroadcastInvalidInput => _value('joinBroadcastInvalidInput');

  /// App bar title of the viewer screen while a broadcast is open.
  String get viewerTitle => _value('viewerTitle');

  /// Label of the viewer Leave control.
  String get viewerLeave => _value('viewerLeave');

  /// Title of the leave confirmation dialog.
  String get confirmLeaveTitle => _value('viewerConfirmLeaveTitle');

  /// Body of the leave confirmation dialog.
  String get confirmLeaveBody => _value('viewerConfirmLeaveBody');

  /// Confirm button of the leave dialog.
  String get confirmLeaveConfirm => _value('viewerConfirmLeaveConfirm');

  /// Cancel button of the leave dialog.
  String get confirmLeaveCancel => _value('viewerConfirmLeaveCancel');

  /// Label of the retry action.
  String get tryAgain => _value('viewerTryAgain');

  /// Status title while the handshake is in flight.
  String get stateTitleConnecting => _value('viewerStateTitleConnecting');

  /// Status title while captions are flowing.
  String get stateTitleLive => _value('viewerStateTitleLive');

  /// Status title while reconnecting.
  String get stateTitleReconnecting => _value('viewerStateTitleReconnecting');

  /// Inline reconnect notice over the captions.
  String get reconnectingNotice => _value('viewerReconnectingNotice');

  /// Status title when nobody is live.
  String get stateTitleNotBroadcasting =>
      _value('viewerStateTitleNotBroadcasting');

  /// Status title after the broadcast ends.
  String get stateTitleEnded => _value('viewerStateTitleEnded');

  /// Status title when the broadcast is at capacity.
  String get stateTitleFull => _value('viewerStateTitleFull');

  /// Status title for every cannot-connect state.
  String get stateTitleCannotConnect => _value('viewerStateTitleCannotConnect');

  /// Status title for an invalid link.
  String get stateTitleInvalidInput => _value('viewerStateTitleInvalidInput');

  /// Copy shown when the broadcast is at capacity.
  String get fullBody => _value('viewerFullBody');

  /// Inline notice while the broadcaster paused.
  String get captionsPausedNotice => _value('viewerCaptionsPausedNotice');

  /// Cannot-connect copy for a non-existent code.
  String get cannotConnectNotFoundBody =>
      _value('viewerCannotConnectNotFoundBody');

  /// Cannot-connect copy for a rate-limited request.
  String get cannotConnectRateLimitedBody =>
      _value('viewerCannotConnectRateLimitedBody');

  /// Cannot-connect copy when liveness is unknown.
  String get cannotConnectResolutionFailedBody =>
      _value('viewerCannotConnectResolutionFailedBody');

  /// Cannot-connect copy for a failed connection.
  String get cannotConnectIceFailedBody =>
      _value('viewerCannotConnectIceFailedBody');

  /// Cannot-connect copy for the reconnect timeout.
  String get cannotConnectReconnectTimeoutBody =>
      _value('viewerCannotConnectReconnectTimeoutBody');

  /// Cannot-connect copy for a rejected join.
  String get cannotConnectSignalingRejectedBody =>
      _value('viewerCannotConnectSignalingRejectedBody');

  /// Cannot-connect copy for an unresponsive broadcaster.
  String get cannotConnectTimeoutBody =>
      _value('viewerCannotConnectTimeoutBody');

  /// Copy shown for an invalid deep link.
  String get invalidInputBody => _value('viewerInvalidInputBody');

  /// "Joining {sessionName}".
  String joining(String sessionName) =>
      _withName('viewerStateJoining', sessionName);

  /// The not-broadcasting copy with the session name.
  String notBroadcastingBodyNamed(String sessionName) =>
      _withName('viewerNotBroadcastingBodyNamed', sessionName);

  /// The not-broadcasting copy when the name is unknown.
  String get notBroadcastingBodyNameless =>
      _value('viewerNotBroadcastingBodyNameless');

  /// The ended copy with the session name.
  String endedBodyNamed(String sessionName) =>
      _withName('viewerEndedBodyNamed', sessionName);

  /// The ended copy when the name is unknown.
  String get endedBodyNameless => _value('viewerEndedBodyNameless');

  /// The pop-out's enter label (UX-PIP-01).
  String get popOutEnter => _value('popOutEnter');

  /// The pop-out's exit label (UX-PIP-01).
  String get popOutExit => _value('popOutExit');

  /// The hint above the caption surface while popped out (UX-PIP-05).
  String get popOutHint => _value('popOutHint');

  /// The banner's return action (UX-PIP-05).
  String get popOutReturn => _value('popOutReturn');

  /// The disabled reason when no session is running (BR-PIP-12/13).
  String get popOutUnavailableNoSession => _value('popOutUnavailableNoSession');

  /// The disabled reason when the device has no recognition engine.
  String get popOutUnavailableNoEngine => _value('popOutUnavailableNoEngine');

  /// Shown next to the toggle while the controller reports a failure.
  String get popOutOpenFailed => _value('popOutOpenFailed');

  /// The sub-window's fallback frame when its payload does not decode.
  String get overlayWindowUnavailable => _value('overlayWindowUnavailable');

  // Unit 10 (Amendment 02): the iOS speech explainer and the start-failure
  // copy. British English; see the ARB descriptions for the source of each.

  /// Title of the iOS speech explainer shown once before the first start.
  String get speechExplainerTitle => _value('speechExplainerTitle');

  /// Body of the iOS speech explainer.
  String get speechExplainerBody => _value('speechExplainerBody');

  /// Explainer action that records the onboarding flag and continues.
  String get speechExplainerContinue => _value('speechExplainerContinue');

  /// Explainer action that sets no flag and returns to Home.
  String get speechExplainerNotNow => _value('speechExplainerNotNow');

  /// Failure title when on-device recognition is unavailable.
  String get onDeviceUnavailableTitle => _value('onDeviceUnavailableTitle');

  /// Failure body when on-device recognition is unavailable.
  String get onDeviceUnavailableBody => _value('onDeviceUnavailableBody');

  /// Fills `{language}` and `{percent}` in [key]. The percent goes first so a
  /// language name that looks like a placeholder stays literal.
  String _withLanguage(String key, String language, {int? percent}) {
    var text = _value(key);
    if (percent != null) text = text.replaceAll('{percent}', '$percent');
    return text.replaceAll('{language}', language);
  }

  /// Panel button that downloads the missing on-device [language]
  /// (Amendment 04, BR-U10-46).
  String languagePackDownload(String language) =>
      _withLanguage('languagePackDownload', language);

  /// Download progress for [language] with a [percent] (BR-U10-47).
  String languagePackDownloadingPercent(String language, int percent) =>
      _withLanguage(
        'languagePackDownloadingPercent',
        language,
        percent: percent,
      );

  /// Download progress for [language] with no percentage (BR-U10-47).
  String languagePackDownloading(String language) =>
      _withLanguage('languagePackDownloading', language);

  /// Shown when the platform deferred the download of [language]
  /// (BR-U10-47a).
  String languagePackScheduled(String language) =>
      _withLanguage('languagePackScheduled', language);

  /// Shown once [language] is installed (BR-U10-47).
  String languagePackReady(String language) =>
      _withLanguage('languagePackReady', language);

  /// Shown when the download of [language] failed or timed out (BR-U10-47).
  String languagePackFailed(String language) =>
      _withLanguage('languagePackFailed', language);

  /// iOS instructions for adding [language] through Dictation (BR-U10-46).
  String languagePackIosInstructions(String language) =>
      _withLanguage('languagePackIosInstructions', language);

  /// Failure title for a denied (re-requestable) microphone permission.
  String get failureMicDeniedTitle => _value('failureMicDeniedTitle');

  /// Failure body for a denied (re-requestable) microphone permission.
  String get failureMicDeniedBody => _value('failureMicDeniedBody');

  /// Failure title for a permanently denied microphone permission.
  String get failureMicPermanentlyDeniedTitle =>
      _value('failureMicPermanentlyDeniedTitle');

  /// Failure body for a permanently denied microphone permission.
  String get failureMicPermanentlyDeniedBody =>
      _value('failureMicPermanentlyDeniedBody');

  /// Failure title when the engine failed to initialise.
  String get failureEngineInitFailedTitle =>
      _value('failureEngineInitFailedTitle');

  /// Failure body when the engine failed to initialise.
  String get failureEngineInitFailedBody =>
      _value('failureEngineInitFailedBody');

  /// Failure title when the engine failed to start listening.
  String get failureEngineStartFailedTitle =>
      _value('failureEngineStartFailedTitle');

  /// Failure body when the engine failed to start listening.
  String get failureEngineStartFailedBody =>
      _value('failureEngineStartFailedBody');

  /// Fallback failure title for an unclassified error.
  String get failureOtherTitle => _value('failureOtherTitle');

  /// Fallback failure body for an unclassified error.
  String get failureOtherBody => _value('failureOtherBody');

  /// Failure panel action that re-runs `start()`.
  String get failureTryAgain => _value('failureTryAgain');

  /// Failure panel action that opens the platform microphone settings.
  String get failureOpenSettings => _value('failureOpenSettings');

  /// Failure panel action that leaves the screen for Home.
  String get failureBack => _value('failureBack');

  /// One-time notice when a session with capture enabled ended without any
  /// recognised speech, so no transcript row was ever created (Amendment 03
  /// section 7, Q-2).
  String get noTranscriptSavedNotice => _value('noTranscriptSavedNotice');

  /// One-time notice when a session with capture enabled recognised speech
  /// but its transcript could not be saved (Amendment 06, BR-U10-60).
  String get transcriptSaveFailedNotice => _value('transcriptSaveFailedNotice');

  /// One-time notice when the app stopped a session after [minutes] minutes
  /// without speech (Amendment 05, BR-U10-53).
  ///
  /// The ARB sentence is written in the plural ("{minutes} minutes"); for 1
  /// the unit becomes the singular, so it reads "1 minute".
  String inactivityStopNoticeFor(int minutes) =>
      _withMinutes(_value('inactivityStopNotice'), minutes);

  /// The single notice when the app stopped a session after [minutes]
  /// minutes without speech and nothing was recognised (Amendment 07,
  /// BR-U10-66). The singular reads "1 minute", as above.
  String inactivityStopNoTranscriptNoticeFor(int minutes) =>
      _withMinutes(_value('inactivityStopNoTranscriptNotice'), minutes);

  /// The single notice when the app stopped a session after [minutes]
  /// minutes without speech and the transcript could not be saved
  /// (Amendment 07, BR-U10-66).
  String inactivityStopSaveFailedNoticeFor(int minutes) =>
      _value('inactivityStopSaveFailedNotice')
          .replaceAll('{inactivityNotice}', inactivityStopNoticeFor(minutes))
          .replaceAll('{saveFailedNotice}', transcriptSaveFailedNotice);

  /// The single notice when a session stopped with an error whose failure
  /// title is [errorTitle], and the save outcome's notice is
  /// [saveOutcomeNotice] (Amendment 07, BR-U10-66).
  String stopErrorWithSaveOutcomeNotice({
    required String errorTitle,
    required String saveOutcomeNotice,
  }) => _value('stopErrorWithSaveOutcomeNotice')
      .replaceAll('{errorTitle}', errorTitle)
      .replaceAll('{saveOutcomeNotice}', saveOutcomeNotice);

  /// Fills `{minutes}` in a sentence written in the plural, reading the
  /// singular as "1 minute".
  static String _withMinutes(String template, int minutes) {
    if (minutes == 1) {
      return template.replaceAll('{minutes} minutes', '1 minute');
    }
    return template.replaceAll('{minutes}', '$minutes');
  }
}

/// Provides the loaded [ZcStrings] for the app lifetime.
///
/// Kept alive so the asset is read once; widget tests override it with a
/// sentinel map (Design Q6).
@Riverpod(keepAlive: true)
Future<ZcStrings> zcStrings(Ref ref) => ZcStrings.load();
