import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:zip_broadcast/src/models/browser_source_start_exception.dart';

/// HTTP server that serves a browser-source overlay page and an SSE caption
/// stream to OBS Browser Source and compatible clients.
///
/// **Usage**:
/// 1. Call [start] to bind to a port and generate an auth token.
/// 2. Call [pushCaption] / [pushSessionState] to broadcast events.
/// 3. Call [stop] to shut down.
///
/// **Security (SEC-U3.3)**: Remote clients must supply the UUID token via
/// `?token=<value>`. Localhost clients bypass token auth.
///
/// **Reliability (REL-U3.2)**: At most 5 simultaneous SSE clients. A 503 is
/// returned when the cap is reached.
class BrowserSourceServer {
  /// Creates a [BrowserSourceServer].
  ///
  /// [isLocalhost] is a `@visibleForTesting` seam that overrides the default
  /// localhost detection so tests can simulate remote-address requests.
  BrowserSourceServer({
    @visibleForTesting bool Function(Request)? isLocalhost,
  }) : _isLocalhost = isLocalhost ?? _defaultIsLocalhost;

  final bool Function(Request) _isLocalhost;

  HttpServer? _server;
  final _clients = <StreamController<List<int>>>[];
  int _activeClientCount = 0;
  String? _token;
  String? _latestCaption;

  static const _maxClients = 5;
  static const _uuid = Uuid();
  static final _log = Logger('zip_broadcast.BrowserSourceServer');

  /// The port the server is listening on, or `null` if not started.
  int? get port => _server?.port;

  /// The current auth token, or `null` if not started.
  String? get token => _token;

  /// Starts the server on [port].
  ///
  /// If [port] is `0` the OS assigns an ephemeral port (useful in tests).
  /// Throws [ArgumentError] if [port] is outside [1024, 65535] (and non-zero).
  /// Throws [BrowserSourceStartException.portInUse] on `SocketException`.
  Future<void> start({int? port}) async {
    final p = port ?? 4455;
    if (p != 0 && (p < 1024 || p > 65535)) {
      throw ArgumentError.value(
        p,
        'port',
        'Port must be in range [1024, 65535].',
      );
    }

    _token = _uuid.v4();
    _log.fine('starting on port $p; token generated');

    final router = Router()
      ..get('/', _handleIndex)
      ..get('/captions', _handleCaptions);

    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(
          router.call,
        );

    try {
      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, p);
      _log.fine('listening on port ${_server!.port}');
    } on SocketException {
      _token = null;
      throw BrowserSourceStartException.portInUse;
    }
  }

  /// Stops the server and disconnects all SSE clients.
  Future<void> stop() async {
    _log.fine('stopping; closing ${_clients.length} client(s)');
    for (final c in List.of(_clients)) {
      unawaited(c.close());
    }
    _clients.clear();
    _activeClientCount = 0;
    _latestCaption = null;
    await _server?.close(force: true);
    _server = null;
    _token = null;
  }

  /// Pushes a caption event to all connected SSE clients and caches it for
  /// replay to new clients.
  void pushCaption(String text, {required bool isFinal}) {
    final payload = json.encode({'text': text, 'isFinal': isFinal});
    final event = 'data: $payload\n\n';
    _latestCaption = event;
    _log.finest(
      'pushCaption: $_activeClientCount client(s); isFinal=$isFinal',
    );
    _broadcast(event);
  }

  /// Pushes a session-state event (e.g. `'stopped'`) to all connected clients.
  void pushSessionState(String state) {
    final event = 'event: session\ndata: $state\n\n';
    _log.finest('pushSessionState: $state');
    _broadcast(event);
  }

  // ---------------------------------------------------------------------------
  // Route handlers
  // ---------------------------------------------------------------------------

  Response _handleIndex(Request request) {
    final t = _token ?? '';
    final html = _buildHtml(t);
    return Response.ok(
      html,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  Future<Response> _handleCaptions(Request request) async {
    if (!_isLocalhost(request)) {
      final supplied = request.url.queryParameters['token'];
      if (supplied != _token) {
        _log.warning('captions: rejected unauthorized request');
        return Response(401, body: 'Unauthorized');
      }
    }

    if (_activeClientCount >= _maxClients) {
      _log.warning('captions: client cap reached ($_maxClients)');
      return Response(503, body: 'Too many clients');
    }

    _activeClientCount++;
    _log.fine('captions: client connected; count=$_activeClientCount');

    final controller = StreamController<List<int>>();
    _clients.add(controller);

    // Send a comment immediately so shelf flushes response headers to the
    // socket before any caption arrives (SSE comment lines start with ':').
    controller.add(utf8.encode(': connected\n\n'));

    // Replay last known caption to the newly connected client.
    final latest = _latestCaption;
    if (latest != null) {
      controller.add(utf8.encode(latest));
    }

    // Detect clean disconnect via sink.done.
    unawaited(
      controller.sink.done.then((_) => _removeClient(controller)),
    );

    return Response.ok(
      controller.stream,
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        'x-accel-buffering': 'no',
      },
      context: {'shelf.io.buffer_output': false},
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _broadcast(String event) {
    final bytes = utf8.encode(event);
    for (final client in List.of(_clients)) {
      try {
        client.add(bytes);
      } on SocketException {
        _removeClient(client);
      }
    }
  }

  void _removeClient(StreamController<List<int>> controller) {
    if (_clients.remove(controller)) {
      _activeClientCount--;
      _log.fine('client disconnected; count=$_activeClientCount');
    }
  }

  static bool _defaultIsLocalhost(Request request) {
    final context = request.context['shelf.io.connection_info'];
    if (context is HttpConnectionInfo) {
      final addr = context.remoteAddress.address;
      return addr == '127.0.0.1' ||
          addr == '::1' ||
          addr == 'localhost';
    }
    // Default to localhost-safe when connection info is unavailable.
    return true;
  }

  String _buildHtml(String token) => '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Zip Captions Browser Source</title>
<style>
  body { margin: 0; background: transparent; }
  #captions {
    font-family: sans-serif; font-size: 2em;
    color: white; text-shadow: 1px 1px 2px black;
    padding: 8px; word-wrap: break-word;
  }
</style>
</head>
<body>
<div id="captions"></div>
<script>
(function () {
  var token = '$token';
  var url = '/captions?token=' + encodeURIComponent(token);
  var es = new EventSource(url);
  var el = document.getElementById('captions');
  es.onmessage = function (e) {
    try {
      var d = JSON.parse(e.data);
      if (d.text !== undefined) el.textContent = d.text;
    } catch (_) {}
  };
  es.addEventListener('session', function (e) {
    if (e.data === 'stopped') el.textContent = '';
  });
})();
</script>
</body>
</html>
''';
}
