import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/models/obs_settings.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/obs_web_socket_target.dart';
import 'package:zip_core/zip_core.dart';

part 'obs_connection_notifier.g.dart';

// ---------------------------------------------------------------------------
// Real ObsWebSocketTarget implementation
// ---------------------------------------------------------------------------

class _ObsWebSocketTargetImpl implements ObsWebSocketTarget {
  _ObsWebSocketTargetImpl({
    required ObsSettings settings,
    @visibleForTesting
    Future<ObsWebSocket> Function(String url, {String? password})? connector,
  })  : _settings = settings,
        _connector = connector ?? ObsWebSocket.connect;

  final ObsSettings _settings;
  final Future<ObsWebSocket> Function(String url, {String? password}) _connector;

  ObsWebSocket? _client;
  Timer? _reconnectTimer;
  int? _retryStartMs;
  int _retryAttempt = 0;
  bool _enabled = false;
  int _gen = 0;

  final _statusController =
      StreamController<ObsConnectionStatus>.broadcast();

  static const _maxRetryMs = 30000;
  static const _timeoutMs = 600000; // 10 minutes
  static final _log = Logger('zip_broadcast.ObsConnectionNotifier');

  @override
  Stream<ObsConnectionStatus> get statusStream => _statusController.stream;

  @override
  Future<void> connect() async {
    _enabled = true;
    _gen++;
    _retryAttempt = 0;
    _retryStartMs = null;
    _log.fine('connect: host=${_settings.host} port=${_settings.port}');
    _connectOnce();
  }

  @override
  Future<void> disconnect() async {
    _enabled = false;
    _gen++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final client = _client;
    _client = null;
    if (client != null) unawaited(client.close());
    _emit(ObsConnectionStatus.disconnected);
  }

  @override
  Future<ObsConnectionStatus> testConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final url = _buildUrl(_settings);
      final client = await _connector(
        url,
        password: _settings.password.isEmpty ? null : _settings.password,
      ).timeout(timeout);
      await client.close();
      return ObsConnectionStatus.connected;
    } on Object {
      return ObsConnectionStatus.error;
    }
  }

  @override
  Future<void> send(String captionText) async {
    final client = _client;
    if (client == null || !_enabled) return;
    try {
      await client.stream.sendStreamCaption(captionText);
    } on Object catch (e) {
      _log.warning('send failed: ${e.runtimeType}');
      _client = null;
      unawaited(client.close());
      if (_enabled) _scheduleReconnect();
    }
  }

  void dispose() {
    _enabled = false;
    _reconnectTimer?.cancel();
    final client = _client;
    _client = null;
    if (client != null) unawaited(client.close());
    if (!_statusController.isClosed) unawaited(_statusController.close());
  }

  void _connectOnce() {
    if (!_enabled) return;
    final gen = _gen;
    _emit(
      _retryAttempt == 0
          ? ObsConnectionStatus.connecting
          : ObsConnectionStatus.reconnecting,
    );

    final url = _buildUrl(_settings);
    unawaited(
      _connector(
        url,
        password: _settings.password.isEmpty ? null : _settings.password,
      ).timeout(const Duration(seconds: 10)).then((client) {
        if (!_enabled || _gen != gen) {
          unawaited(client.close());
          return;
        }
        _client = client;
        _retryAttempt = 0;
        _retryStartMs = null;
        _emit(ObsConnectionStatus.connected);
      }).onError<Object>((_, __) {
        if (!_enabled || _gen != gen) return;
        _scheduleReconnect();
      }),
    );
  }

  void _scheduleReconnect() {
    final now = clock.now().millisecondsSinceEpoch;
    _retryStartMs ??= now;

    if (now - _retryStartMs! >= _timeoutMs) {
      _enabled = false;
      _emit(ObsConnectionStatus.error);
      return;
    }

    _retryAttempt++;
    final delay = _backoffMs(_retryAttempt);
    _emit(ObsConnectionStatus.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), _connectOnce);
  }

  void _emit(ObsConnectionStatus status) {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  static String _buildUrl(ObsSettings s) {
    final raw = s.host;
    final base = (raw.startsWith('ws://') || raw.startsWith('wss://'))
        ? raw
        : 'ws://$raw';
    return '$base:${s.port}';
  }

  static int _backoffMs(int attempt) =>
      min((1000 * pow(2, attempt - 1)).toInt(), _maxRetryMs);
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Singleton [ObsWebSocketTarget] for this app session.
///
/// Re-created when [ObsSettingsNotifier] changes.
@Riverpod(keepAlive: true)
ObsWebSocketTarget obsWebSocketTarget(Ref ref) {
  final settings = ref.watch(obsSettingsNotifierProvider);
  final impl = _ObsWebSocketTargetImpl(settings: settings);
  ref.onDispose(impl.dispose);
  return impl;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the live OBS WebSocket connection and exposes [ObsConnectionStatus].
///
/// Self-manages connection based on [OutputTargetSettingsNotifier.obsEnabled]
/// (FD H2). Forwards final captions from [CaptionBus] to OBS when connected.
@Riverpod(keepAlive: true)
class ObsConnectionNotifier extends _$ObsConnectionNotifier {
  static final _log = Logger('zip_broadcast.ObsConnectionNotifier');

  StreamSubscription<ObsConnectionStatus>? _statusSub;
  StreamSubscription<CaptionEvent>? _busSub;
  ObsWebSocketTarget? _target;

  @override
  ObsConnectionStatus build() {
    _target = ref.watch(obsWebSocketTargetProvider);

    _statusSub?.cancel();
    _statusSub = _target!.statusStream.listen((status) {
      state = status;
    });

    ref.onDispose(() {
      _statusSub?.cancel();
      _busSub?.cancel();
    });

    ref.listen(
      outputTargetSettingsNotifierProvider.select((s) => s.obsEnabled),
      (_, enabled) {
        if (enabled) {
          final bus = ref.read(captionBusProvider);
          _busSub?.cancel();
          _busSub = bus.stream.listen(_onCaptionEvent);
          unawaited(_target!.connect());
          _log.fine('OBS enabled — connecting');
        } else {
          _busSub?.cancel();
          _busSub = null;
          unawaited(_target!.disconnect());
          _log.fine('OBS disabled — disconnecting');
        }
      },
      fireImmediately: true,
    );

    return ObsConnectionStatus.disconnected;
  }

  /// Runs a one-shot test connection and returns the result.
  Future<ObsConnectionStatus> testConnection({
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _target!.testConnection(timeout: timeout);

  void _onCaptionEvent(CaptionEvent event) {
    if (event case SttResultEvent(:final result) when result.isFinal) {
      if (state == ObsConnectionStatus.connected) {
        unawaited(_target!.send(result.text));
      }
    }
  }
}
