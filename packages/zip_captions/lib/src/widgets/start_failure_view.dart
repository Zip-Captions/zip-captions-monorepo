import 'package:flutter/material.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_core/zip_core.dart';

/// The kinds of start failure the panel distinguishes (Unit 10, P9).
///
/// The set is closed: every error classifies to exactly one of these, so the
/// panel always has text to show and never falls through to nothing.
enum StartFailureKind {
  /// Microphone permission was denied but can be asked for again.
  micDenied,

  /// Microphone permission is permanently denied; only settings can fix it.
  micPermanentlyDenied,

  /// The speech engine failed to initialise.
  engineInitFailed,

  /// The speech engine failed to start listening.
  engineStartFailed,

  /// On-device speech recognition is unavailable for this device or language.
  onDeviceUnavailable,

  /// Anything the factories do not name.
  other,
}

/// What the failure panel should show for one [RecordingError].
///
/// Built only through `StartFailureView.from`, which classifies through the
/// [RecordingErrorFactories] messages rather than retyped strings
/// (BR-U10-11). The same classification feeds the mid-session notice
/// (BR-U10-23), so the two can never disagree.
@immutable
class StartFailureView {
  const StartFailureView._({
    required this.kind,
    required this.showTryAgain,
    required this.showOpenSettings,
    required this.errorMessage,
  });

  /// Classifies [error] for [platform] and [isWeb] (TP-8).
  ///
  /// "Open settings" is offered only where app settings can actually help:
  /// iOS and Android, for a permanently denied microphone and for an engine
  /// that failed to initialise. It is never offered on desktop or web (there
  /// is no engine to fix, and on macOS `permission_handler` has no plugin, so
  /// the call would throw `MissingPluginException`), and never for
  /// [StartFailureKind.onDeviceUnavailable] (no app setting enables an
  /// on-device model).
  factory StartFailureView.from(
    RecordingError error, {
    required TargetPlatform platform,
    required bool isWeb,
  }) {
    final kind = _kindOf(error);
    final mobile = !isWeb &&
        (platform == TargetPlatform.iOS ||
            platform == TargetPlatform.android);
    final canOpenSettings = mobile &&
        (kind == StartFailureKind.micPermanentlyDenied ||
            kind == StartFailureKind.engineInitFailed);
    return StartFailureView._(
      kind: kind,
      showTryAgain: true,
      showOpenSettings: canOpenSettings,
      errorMessage: error.message,
    );
  }

  /// The classified kind.
  final StartFailureKind kind;

  /// Whether to offer "Try again". True for every kind.
  final bool showTryAgain;

  /// Whether to offer "Open settings".
  final bool showOpenSettings;

  /// The error's own message, shown for [StartFailureKind.other].
  ///
  /// It comes from a `RecordingErrorFactories` message or from the notifier's
  /// own error and never carries transcript text (SECURITY-03): the notifier
  /// builds every error it reports from the factories.
  final String errorMessage;

  /// The classification test itself, kept here so the panel and the notice
  /// share exactly one mapping.
  ///
  /// The factories' messages are compared, never presented: the UI text comes
  /// from the ARB by way of [StartFailureKind].
  static StartFailureKind _kindOf(RecordingError error) {
    final message = error.message;
    if (message == RecordingErrorFactories.permissionDenied().message) {
      return StartFailureKind.micDenied;
    }
    if (message ==
        RecordingErrorFactories.permissionPermanentlyDenied().message) {
      return StartFailureKind.micPermanentlyDenied;
    }
    if (message == RecordingErrorFactories.engineInitFailed().message) {
      return StartFailureKind.engineInitFailed;
    }
    if (message == RecordingErrorFactories.engineStartFailed().message) {
      return StartFailureKind.engineStartFailed;
    }
    if (message ==
        RecordingErrorFactories.onDeviceRecognitionUnavailable().message) {
      return StartFailureKind.onDeviceUnavailable;
    }
    // Everything else, including engineRequiresModelDownload (an engine that
    // needs its own model, which is not "this device cannot do on-device
    // speech") and localeNotSupported, shows its own message.
    return StartFailureKind.other;
  }

  /// The localised title for [kind].
  String title(ZcStrings strings) => switch (kind) {
        StartFailureKind.micDenied => strings.failureMicDeniedTitle,
        StartFailureKind.micPermanentlyDenied =>
          strings.failureMicPermanentlyDeniedTitle,
        StartFailureKind.engineInitFailed =>
          strings.failureEngineInitFailedTitle,
        StartFailureKind.engineStartFailed =>
          strings.failureEngineStartFailedTitle,
        StartFailureKind.onDeviceUnavailable =>
          strings.onDeviceUnavailableTitle,
        StartFailureKind.other => strings.failureOtherTitle,
      };

  /// The body for [kind]: localised copy, or the error's own message for
  /// [StartFailureKind.other] (BR-U10-11 shows the factory message).
  String body(ZcStrings strings) => switch (kind) {
        StartFailureKind.micDenied => strings.failureMicDeniedBody,
        StartFailureKind.micPermanentlyDenied =>
          strings.failureMicPermanentlyDeniedBody,
        StartFailureKind.engineInitFailed =>
          strings.failureEngineInitFailedBody,
        StartFailureKind.engineStartFailed =>
          strings.failureEngineStartFailedBody,
        StartFailureKind.onDeviceUnavailable =>
          strings.onDeviceUnavailableBody,
        StartFailureKind.other =>
          errorMessage.isEmpty ? strings.failureOtherBody : errorMessage,
      };
}

/// The failure panel shown in place of the caption area (BR-U10-10).
///
/// Every label comes from [ZcStrings]; nothing here is a literal. The panel
/// offers "Try again" always, "Open settings" when [StartFailureView]
/// allows it, and "Back" always.
class StartFailurePanel extends StatelessWidget {
  /// Creates the panel.
  const StartFailurePanel({
    required this.view,
    required this.strings,
    required this.onTryAgain,
    required this.onBack,
    this.onOpenSettings,
    this.languagePackSection,
    super.key,
  });

  /// The classified failure.
  final StartFailureView view;

  /// The localised copy.
  final ZcStrings strings;

  /// Re-runs `start()`.
  final VoidCallback onTryAgain;

  /// Leaves the screen for Home.
  final VoidCallback onBack;

  /// Opens the platform microphone settings. Required when
  /// [StartFailureView.showOpenSettings] is true.
  final VoidCallback? onOpenSettings;

  /// What recovers a missing on-device language (Amendment 04, BR-U10-46):
  /// the download, its progress, or the iOS instructions. Given only for
  /// [StartFailureKind.onDeviceUnavailable]; shown between the body and the
  /// buttons. It never starts captioning: [onTryAgain] stays the only way
  /// back to `start()`.
  final Widget? languagePackSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                view.title(strings),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                view.body(strings),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (languagePackSection != null) ...[
                const SizedBox(height: 16),
                languagePackSection!,
              ],
              const SizedBox(height: 24),
              if (view.showTryAgain)
                FilledButton(
                  onPressed: onTryAgain,
                  child: Text(strings.failureTryAgain),
                ),
              if (view.showOpenSettings) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onOpenSettings,
                  child: Text(strings.failureOpenSettings),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: onBack,
                child: Text(strings.failureBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
