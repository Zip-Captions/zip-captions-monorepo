import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:zip_broadcast/src/models/obs_connection_state.dart';
import 'package:zip_broadcast/src/models/obs_settings.dart';
import 'package:zip_core/zip_core.dart';

/// Caption output target that forwards final captions to OBS via WebSocket v5.
///
/// Call [connect] when the user enables OBS output. The target implements
/// exponential backoff reconnection (1 s → 30 s cap) and gives up after
/// 10 minutes, emitting an [ObsError] state (REL-U3.4).
///
/// **Security (SEC-U3.2)**: The OBS password is never logged. Only the host
/// and port appear in log output.
class ObsWebSocketTarget implements CaptionOutputTarget {
  /// Creates an [ObsWebSocketTarget].
  ///
  /// [connector] is a `@visibleForTesting` seam. When provided, it is called
  /// instead of [ObsWebSocket.connect], allowing tests to inject failures
  /// without touching the network.
  ObsWebSocketTarget({
    @visibleForTesting
    Future<ObsWebSocket> Function(
      String url, {
      String? password,
    })? connector,
  }) : _connector = connector ?? ObsWebSocket.connect;

  final Future<ObsWebSocket> Function(String url, {String? password})
      _connector;

  ObsWebSocket? _client;
  ObsSettings? _settings;
  ObsConnectionState _connectionState = const ObsDisconnected();
  Timer? _reconnectTimer;
  int? _retryStartMs;
  int _retryAttempt = 0;
  bool _enabled = false;
  int _gen = 0;

  final _stateController =
      StreamController<ObsConnectionState>.broadcast();

  static const _maxRetryMs = 30000;
  static const _timeoutMs = 600000; // 10 minutes
  static final _log = Logger('zip_broadcast.ObsWebSocketTarget');

  @override
  String get targetId => 'obs_websocket';

  /// The current connection state.
  ObsConnectionState get connectionState => _connectionState;

  /// Stream of [ObsConnectionState] changes for the UI layer.
  Stream<ObsConnectionState> get connectionStateStream =>
      _stateController.stream;

  /// Initiates a connection to OBS with [settings].
  ///
  /// Reconnects automatically on failure using exponential backoff until the
  /// 10-minute timeout is reached.
  void connect(ObsSettings settings) {
    _settings = settings;
    _enabled = true;
    _gen++;
    _retryAttempt = 0;
    _retryStartMs = null;
    _log.fine(
      'connect: host=${settings.host} port=${settings.port}',
    );
    _connectOnce();
  }

  /// Disconnects from OBS and cancels any pending reconnect timer.
  void disconnect() {
    _enabled = false;
    _gen++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _log.fine('disconnect requested');
    final client = _client;
    _client = null;
    if (client != null) unawaited(client.close());
    _setState(const ObsDisconnected());
  }

  @override
  void onCaptionEvent(CaptionEvent event) {
    if (event case SttResultEvent(:final result) when result.isFinal) {
      if (_connectionState is ObsConnected) {
        _log.finest(
          'sendStreamCaption: ${result.text.length} chars',
        );
        unawaited(_sendCaption(result.text));
      }
    }
  }

  @override
  void dispose() => disconnect();

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _connectOnce() {
    if (!_enabled) return;
    final settings = _settings;
    if (settings == null) return;

    final gen = _gen;

    _setState(
      _retryAttempt == 0
          ? const ObsConnecting()
          : ObsReconnecting(
              attempt: _retryAttempt,
              nextRetryMs: _backoffMs(_retryAttempt),
            ),
    );

    final url = '${settings.host}:${settings.port}';
    _log.fine(
      'connection attempt ${_retryAttempt + 1}: url=$url',
    );

    unawaited(
      _connector(
        url,
        password: settings.password.isEmpty ? null : settings.password,
      ).timeout(const Duration(seconds: 10)).then((client) {
        if (!_enabled || _gen != gen) {
          unawaited(client.close());
          return;
        }
        _client = client;
        _retryAttempt = 0;
        _retryStartMs = null;
        _log.fine('connected: url=$url');
        _setState(const ObsConnected());
      }).onError<Object>((error, stack) {
        if (!_enabled || _gen != gen) return;
        _log.warning(
          'connection failed (attempt ${_retryAttempt + 1}): $error',
        );
        _scheduleReconnect();
      }),
    );
  }

  Future<void> _sendCaption(String text) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.stream.sendStreamCaption(text);
    } on Object catch (error) {
      _log.warning('sendStreamCaption failed: $error');
      _client = null;
      unawaited(client.close());
      if (_enabled) _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    final now = clock.now().millisecondsSinceEpoch;
    _retryStartMs ??= now;

    if (now - _retryStartMs! >= _timeoutMs) {
      _log.severe('OBS reconnect timeout after 10 minutes');
      _enabled = false;
      _setState(
        const ObsError(message: 'Could not connect to OBS after 10 minutes.'),
      );
      return;
    }

    _retryAttempt++;
    final delay = _backoffMs(_retryAttempt);
    _log.fine(
      'scheduling reconnect attempt $_retryAttempt in ${delay}ms',
    );

    _setState(
      ObsReconnecting(attempt: _retryAttempt, nextRetryMs: delay),
    );

    _reconnectTimer = Timer(Duration(milliseconds: delay), _connectOnce);
  }

  void _setState(ObsConnectionState state) {
    _connectionState = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  /// Returns the backoff delay for [attempt] (1-based), capped at 30 s.
  static int _backoffMs(int attempt) =>
      min((1000 * pow(2, attempt - 1)).toInt(), _maxRetryMs);
}
