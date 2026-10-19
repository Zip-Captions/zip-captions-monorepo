import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_core/zip_core.dart';

/// The copy a viewer state renders: one-line title, optional body and
/// whether a manual retry action belongs on screen (Rule 5).
class ViewerStatusPresentation {
  /// Creates the presentation.
  const ViewerStatusPresentation({
    required this.title,
    this.body,
    this.canRetry = false,
  });

  /// The one-line status title, shown by the status region.
  final String title;

  /// Supporting copy under the title, if any.
  final String? body;

  /// Whether the cannot-connect/full state offers "Try again".
  ///
  /// `NotFound` and `RateLimited` deliberately offer none: the ID is the
  /// problem, or waiting is the only remedy (Rule 5).
  final bool canRetry;
}

/// Maps a [ViewerSessionState] to [ZcStrings] copy.
///
/// Exhaustive over the sealed state, so a new variant fails to compile here
/// rather than rendering a blank screen. Carries no caption content.
ViewerStatusPresentation presentViewerState(
  ViewerSessionState state,
  ZcStrings strings, {
  String? sessionName,
}) {
  final name = sessionName;

  return switch (state) {
    ViewerIdleState() => ViewerStatusPresentation(
      title: strings.stateTitleLive,
    ),
    ResolvingState() => ViewerStatusPresentation(
      title: strings.stateTitleConnecting,
    ),
    ConnectingState() => ViewerStatusPresentation(
      title: name == null
          ? strings.stateTitleConnecting
          : strings.joining(name),
    ),
    LiveViewState() => ViewerStatusPresentation(
      title: strings.stateTitleLive,
    ),
    ViewerReconnectingState() => ViewerStatusPresentation(
      title: strings.stateTitleReconnecting,
    ),
    NotBroadcastingState() => ViewerStatusPresentation(
      title: strings.stateTitleNotBroadcasting,
      body: name == null
          ? strings.notBroadcastingBodyNameless
          : strings.notBroadcastingBodyNamed(name),
    ),
    EndedState() => ViewerStatusPresentation(
      title: strings.stateTitleEnded,
      body: name == null
          ? strings.endedBodyNameless
          : strings.endedBodyNamed(name),
    ),
    FullState() => ViewerStatusPresentation(
      title: strings.stateTitleFull,
      body: strings.fullBody,
      canRetry: true,
    ),
    CannotConnectState(:final reason) => ViewerStatusPresentation(
      title: strings.stateTitleCannotConnect,
      body: switch (reason) {
        NotFound() => strings.cannotConnectNotFoundBody,
        RateLimited() => strings.cannotConnectRateLimitedBody,
        ResolutionFailed() => strings.cannotConnectResolutionFailedBody,
        IceFailed() => strings.cannotConnectIceFailedBody,
        Timeout() => strings.cannotConnectTimeoutBody,
        SignalingRejected() => strings.cannotConnectSignalingRejectedBody,
        BroadcastFull() => strings.fullBody,
      },
      canRetry: switch (reason) {
        NotFound() || RateLimited() => false,
        BroadcastFull() ||
        IceFailed() ||
        Timeout() ||
        SignalingRejected() ||
        ResolutionFailed() => true,
      },
    ),
    InvalidInputState() => ViewerStatusPresentation(
      title: strings.stateTitleInvalidInput,
      body: strings.invalidInputBody,
    ),
  };
}

/// Whether the broadcaster's captions are currently paused or inactive, so
/// the viewer shows the paused notice over the last received captions.
bool isCaptionActivityPaused(ViewerSessionState state) => switch (state) {
  LiveViewState(:final captionActivity) =>
    captionActivity != CaptionActivity.active,
  _ => false,
};
