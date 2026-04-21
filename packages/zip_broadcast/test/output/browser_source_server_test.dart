import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zip_broadcast/src/output/browser_source/browser_source_server.dart';

// Seam that forces all requests to be treated as remote (non-localhost).
BrowserSourceServer _remoteServer() =>
    BrowserSourceServer(isLocalhost: (_) => false);

// Seam that forces all requests to be treated as localhost.
BrowserSourceServer _localhostServer() =>
    BrowserSourceServer(isLocalhost: (_) => true);

void main() {
  late BrowserSourceServer server;
  late Uri baseUri;

  setUp(() async {
    server = _localhostServer();
    await server.start(port: 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    await server.stop();
  });

  group('port validation', () {
    test('port 0 (OS-assigned) is accepted', () async {
      // Already started with port 0 in setUp — just assert it is running.
      expect(server.port, isNotNull);
      expect(server.port, greaterThan(0));
    });

    test('port 1023 → ArgumentError', () async {
      final s = BrowserSourceServer();
      await expectLater(
        () => s.start(port: 1023),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('port 65536 → ArgumentError', () async {
      final s = BrowserSourceServer();
      await expectLater(
        () => s.start(port: 65536),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('GET /', () {
    test('returns HTML with SSE JS', () async {
      final response = await http.get(baseUri);
      expect(response.statusCode, equals(200));
      expect(
        response.headers['content-type'],
        contains('text/html'),
      );
      expect(response.body, contains('EventSource'));
    });
  });

  group('token auth', () {
    test('localhost bypasses token auth', () async {
      // server is a localhost server; no token needed.
      final client = HttpClient();
      final request =
          await client.getUrl(baseUri.resolve('/captions'));
      final response = await request.close();
      expect(response.statusCode, equals(200));
      client.close(force: true);
    });

    test('remote without token → 401', () async {
      final remote = _remoteServer();
      await remote.start(port: 0);
      final remoteUri =
          Uri.parse('http://127.0.0.1:${remote.port}');
      try {
        final response =
            await http.get(remoteUri.resolve('/captions'));
        expect(response.statusCode, equals(401));
      } finally {
        await remote.stop();
      }
    });

    test('remote with wrong token → 401', () async {
      final remote = _remoteServer();
      await remote.start(port: 0);
      final remoteUri =
          Uri.parse('http://127.0.0.1:${remote.port}');
      try {
        final response = await http.get(
          remoteUri.resolve('/captions?token=wrong-token'),
        );
        expect(response.statusCode, equals(401));
      } finally {
        await remote.stop();
      }
    });

    test('remote with correct token → 200', () async {
      final remote = _remoteServer();
      await remote.start(port: 0);
      final token = remote.token!;
      final remoteUri =
          Uri.parse('http://127.0.0.1:${remote.port}');
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          remoteUri.resolve('/captions?token=$token'),
        );
        final response = await request.close();
        expect(response.statusCode, equals(200));
        expect(
          response.headers.contentType?.mimeType,
          equals('text/event-stream'),
        );
      } finally {
        client.close(force: true);
        await remote.stop();
      }
    });
  });

  group('SSE client cap', () {
    test('5th client accepted; 6th returns 503', () async {
      final clients = <HttpClient>[];
      // Open 5 SSE connections.
      for (var i = 0; i < 5; i++) {
        final c = HttpClient();
        clients.add(c);
        final req = await c.getUrl(baseUri.resolve('/captions'));
        final res = await req.close();
        expect(res.statusCode, equals(200), reason: 'client $i');
        // Keep the connection open by not reading the body.
      }

      // 6th should be rejected.
      final response =
          await http.get(baseUri.resolve('/captions'));
      expect(response.statusCode, equals(503));

      for (final c in clients) {
        c.close(force: true);
      }
    });
  });

  group('pushCaption', () {
    test('new client receives latest caption replay', () async {
      server.pushCaption('hello', isFinal: true);

      final client = HttpClient();
      try {
        final request =
            await client.getUrl(baseUri.resolve('/captions'));
        final response = await request.close();
        expect(response.statusCode, equals(200));

        final lines = response
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        final first = await lines
            .where((l) => l.startsWith('data:'))
            .first
            .timeout(const Duration(seconds: 3));
        expect(first, contains('"text":"hello"'));
      } finally {
        client.close(force: true);
      }
    });

    test('pushCaption broadcasts to connected client', () async {
      final client = HttpClient();
      try {
        final request =
            await client.getUrl(baseUri.resolve('/captions'));
        final response = await request.close();

        final linesFuture = response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .where((l) => l.startsWith('data:'))
            .first
            .timeout(const Duration(seconds: 3));

        server.pushCaption('world', isFinal: false);

        final line = await linesFuture;
        expect(line, contains('"text":"world"'));
      } finally {
        client.close(force: true);
      }
    });
  });
}
