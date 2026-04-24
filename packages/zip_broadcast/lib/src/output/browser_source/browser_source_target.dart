import 'dart:async';

import 'package:zip_broadcast/src/output/browser_source/browser_source_server.dart';
import 'package:zip_core/zip_core.dart';

/// Caption output target that bridges [CaptionEvent]s to [BrowserSourceServer].
///
/// Converts final STT results to SSE caption pushes and maps session lifecycle
/// events to clear/stop signals so browser overlay clients stay in sync.
///
/// Call [start] before registering with [CaptionOutputTargetRegistry] and
/// [stop] (or [dispose]) when removing.
class BrowserSourceTarget implements CaptionOutputTarget {
  /// Creates a [BrowserSourceTarget] backed by [server].
  BrowserSourceTarget({required BrowserSourceServer server})
      : _server = server;

  final BrowserSourceServer _server;

  // Serializes start/stop calls so a concurrent stop cannot race a start.
  Future<void> _lifecycleLock = Future.value();

  static const _targetIdValue = 'browser_source';

  @override
  String get targetId => _targetIdValue;

  /// Whether the server is currently bound and accepting connections.
  bool get isRunning => _server.port != null;

  /// Starts the browser source HTTP server on [port].
  ///
  /// Throws [BrowserSourceStartException] if the port is already in use.
  Future<void> start({int port = 8080}) {
    return _lifecycleLock = _lifecycleLock
        .then((_) => _server.start(port: port));
  }

  /// Stops the server and disconnects all SSE clients.
  Future<void> stop() {
    return _lifecycleLock = _lifecycleLock
        .then((_) => _server.stop())
        .onError<Object>((_, __) {});
  }

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
  void dispose() {
    unawaited(stop());
  }

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
