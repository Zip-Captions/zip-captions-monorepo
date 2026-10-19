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

  /// Label of the join screen text field.
  String get joinBroadcastFieldLabel => _value('joinBroadcastFieldLabel');

  /// Label of the join submit button.
  String get joinBroadcastSubmit => _value('joinBroadcastSubmit');

  /// Inline error for unparseable join input.
  String get joinBroadcastInvalidInput => _value('joinBroadcastInvalidInput');

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
}

/// Provides the loaded [ZcStrings] for the app lifetime.
///
/// Kept alive so the asset is read once; widget tests override it with a
/// sentinel map (Design Q6).
@Riverpod(keepAlive: true)
Future<ZcStrings> zcStrings(Ref ref) => ZcStrings.load();
