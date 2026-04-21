import 'package:zip_broadcast/src/output/browser_source/browser_source_server.dart';
import 'package:zip_core/zip_core.dart';

/// Caption output target that bridges [CaptionEvent]s to [BrowserSourceServer].
///
/// Converts final STT results to SSE caption pushes and maps session lifecycle
/// events to clear/stop signals so browser overlay clients stay in sync.
class BrowserSourceTarget implements CaptionOutputTarget {
  /// Creates a [BrowserSourceTarget] backed by [server].
  BrowserSourceTarget({required BrowserSourceServer server})
      : _server = server;

  final BrowserSourceServer _server;

  static const _targetIdValue = 'browser_source';

  @override
  String get targetId => _targetIdValue;

  @override
  void onCaptionEvent(CaptionEvent event) {
    switch (event) {
      case SttResultEvent(:final result):
        _server.pushCaption(result.text, isFinal: result.isFinal);
      case SessionStateEvent(:final state):
        _handleSessionState(state);
    }
  }

  @override
  void dispose() {}

  void _handleSessionState(RecordingState state) {
    switch (state) {
      case RecordingActiveState():
        // Clear overlay text on new session.
        _server.pushCaption('', isFinal: false);
      case StoppedState():
        _server.pushSessionState('stopped');
      case IdleState() || PausedState() || ReconnectingState():
        break;
    }
  }
}
