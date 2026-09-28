// Spike 2.1 — throwaway fan-out broadcaster harness. Never merged; see spikes/phase2/README.md.
//
// Connects to the throwaway signaling relay, accepts N synthetic viewer connections, opens one
// WebRTC data channel per viewer, sends a synthetic caption-sized payload once per second on every
// open channel (mimicking real captioning cadence), and self-reports:
//   - resident memory (desktop only; dart:io ProcessInfo is unavailable on web)
//   - join-to-first-message latency per viewer (data channel open -> first message received back)
//   - active channel count
//
// CPU is intentionally not self-measured — sample it externally per spikes/phase2/README.md.
//
// Headless automation (no manual UI interaction) is driven entirely by --dart-define flags:
//   RELAY_URL, BROADCAST_ID, AUTO_CONNECT=true, TEST_DURATION_SECONDS (0 = run indefinitely),
//   RESULTS_FILE. When TEST_DURATION_SECONDS elapses, the app writes RESULTS_FILE and exits(0),
//   so an orchestrating script can launch it, wait for the process to end, and read the file —
//   no window interaction needed. Status lines are also printed to stdout for live log-tailing.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, ProcessInfo, exit;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _relayUrlEnv = String.fromEnvironment('RELAY_URL', defaultValue: 'ws://localhost:8090');
const _broadcastIdEnv = String.fromEnvironment('BROADCAST_ID', defaultValue: 'spike-2.1');
const _autoConnectEnv = bool.fromEnvironment('AUTO_CONNECT');
const _testDurationSecondsEnv = int.fromEnvironment('TEST_DURATION_SECONDS');
const _resultsFileEnv = String.fromEnvironment('RESULTS_FILE', defaultValue: 'broadcaster-results.json');
const _stunUrlEnv = String.fromEnvironment('STUN_URL', defaultValue: 'stun:stun.l.google.com:19302');
// Experiment: serialize + pace data-channel creation instead of handling every viewer-joined
// event concurrently. Default 0 preserves the original (unpaced/concurrent) behavior.
const _channelCreationPacingMsEnv = int.fromEnvironment('CHANNEL_CREATION_PACING_MS');

void main() => runApp(const BroadcasterApp());

class BroadcasterApp extends StatelessWidget {
  const BroadcasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Spike 2.1 Broadcaster',
      home: BroadcasterScreen(),
    );
  }
}

class ViewerConnection {
  ViewerConnection(this.viewerId, this.peerConnection);

  final String viewerId;
  final RTCPeerConnection peerConnection;
  RTCDataChannel? dataChannel;
  DateTime? channelOpenedAt;
  Duration? firstMessageLatency;
}

class BroadcasterScreen extends StatefulWidget {
  const BroadcasterScreen({super.key});

  @override
  State<BroadcasterScreen> createState() => _BroadcasterScreenState();
}

class _BroadcasterScreenState extends State<BroadcasterScreen> {
  final _relayController = TextEditingController(text: _relayUrlEnv);
  final _broadcastIdController = TextEditingController(text: _broadcastIdEnv);

  WebSocketChannel? _signaling;
  final Map<String, ViewerConnection> _viewers = {};
  Timer? _memorySampler;
  Timer? _captionSender;
  Timer? _testDurationTimer;
  int _currentRssBytes = 0;
  int _messagesSent = 0;
  final List<String> _log = [];
  final List<int> _rssSamplesBytes = [];
  Future<void> _channelCreationChain = Future<void>.value();
  final DateTime _startedAt = DateTime.now();

  static final _iceServers = {
    'iceServers': [
      {'urls': _stunUrlEnv},
    ],
  };

  @override
  void initState() {
    super.initState();
    if (_autoConnectEnv) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    }
  }

  void _appendLog(String line) {
    // Also print to stdout so `flutter run`'s terminal output can be tailed by an orchestrating
    // script without needing to read the (headless-driven) app's UI.
    // ignore: avoid_print
    print('[broadcaster] $line');
    setState(() {
      _log.insert(0, '${DateTime.now().toIso8601String()}  $line');
      if (_log.length > 200) _log.removeLast();
    });
  }

  Future<void> _writeResultsAndExit() async {
    final latencies = _viewers.values
        .map((v) => v.firstMessageLatency?.inMilliseconds)
        .whereType<int>()
        .toList()
      ..sort();

    final summary = {
      'startedAt': _startedAt.toIso8601String(),
      'endedAt': DateTime.now().toIso8601String(),
      'testDurationSeconds': _testDurationSecondsEnv,
      'viewerCount': _viewers.length,
      'messagesSent': _messagesSent,
      'rssSamplesBytes': _rssSamplesBytes,
      'peakRssBytes': _rssSamplesBytes.isEmpty ? null : _rssSamplesBytes.reduce((a, b) => a > b ? a : b),
      'latencyMsMin': latencies.isEmpty ? null : latencies.first,
      'latencyMsP50': latencies.isEmpty ? null : latencies[latencies.length ~/ 2],
      'latencyMsMax': latencies.isEmpty ? null : latencies.last,
      'latenciesMs': latencies,
    };

    if (!kIsWeb) {
      await File(_resultsFileEnv).writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
      _appendLog('Wrote results to $_resultsFileEnv');
    } else {
      _appendLog('Results (web — copy from log, no filesystem access): ${jsonEncode(summary)}');
    }

    if (!kIsWeb) {
      exit(0);
    }
  }

  Future<void> _connect() async {
    final relayUrl = _relayController.text.trim();
    final broadcastId = _broadcastIdController.text.trim();

    final channel = WebSocketChannel.connect(Uri.parse(relayUrl));
    _signaling = channel;
    channel.sink.add(jsonEncode({'type': 'broadcaster-hello', 'broadcastId': broadcastId}));
    _appendLog('Connected to relay, broadcasting as "$broadcastId"');

    channel.stream.listen(
      (raw) => _handleSignalingMessage(jsonDecode(raw as String) as Map<String, dynamic>),
      onDone: () => _appendLog('Signaling connection closed'),
      onError: (Object e) => _appendLog('Signaling error: $e'),
    );

    if (!kIsWeb) {
      _memorySampler = Timer.periodic(const Duration(seconds: 2), (_) {
        final rss = ProcessInfo.currentRss;
        _rssSamplesBytes.add(rss);
        setState(() => _currentRssBytes = rss);
      });
    }

    if (_testDurationSecondsEnv > 0) {
      _testDurationTimer = Timer(const Duration(seconds: _testDurationSecondsEnv), _writeResultsAndExit);
      _appendLog('Auto-exit scheduled in ${_testDurationSecondsEnv}s');
    }

    // Mimic real captioning cadence: one synthetic caption per second, fanned out to every
    // currently-open data channel, so CPU/memory reflect steady-state load, not just connection churn.
    _captionSender = Timer.periodic(const Duration(seconds: 1), (_) {
      final payload = jsonEncode({
        'type': 'caption',
        'seq': _messagesSent,
        'sentAt': DateTime.now().toIso8601String(),
        // Padded to a realistic caption-line size (~120 chars) for representative bandwidth.
        'text': 'Spike 2.1 synthetic caption payload #$_messagesSent ' * 2,
      });
      for (final viewer in _viewers.values) {
        final dc = viewer.dataChannel;
        if (dc != null && dc.state == RTCDataChannelState.RTCDataChannelOpen) {
          dc.send(RTCDataChannelMessage(payload));
        }
      }
      _messagesSent++;
    });

    setState(() {});
  }

  Future<void> _handleSignalingMessage(Map<String, dynamic> msg) async {
    switch (msg['type']) {
      case 'viewer-joined':
        // Serialize channel creation through _channelCreationChain instead of letting concurrent
        // viewer-joined events race each other into createPeerConnection/createOffer at once —
        // this is the experiment testing whether unpaced concurrent creation is what stalls the
        // SCTP/DCEP handshake for a subset of channels under load (see spike-2.1-report.md).
        final viewerId = msg['viewerId'] as String;
        _channelCreationChain = _channelCreationChain.then((_) async {
          if (_channelCreationPacingMsEnv > 0) {
            await Future<void>.delayed(const Duration(milliseconds: _channelCreationPacingMsEnv));
          }
          await _createViewerConnection(viewerId);
        });
        await _channelCreationChain;
        break;
      case 'answer':
        final viewer = _viewers[msg['viewerId'] as String];
        if (viewer == null) return;
        await viewer.peerConnection.setRemoteDescription(
          RTCSessionDescription(msg['sdp']['sdp'] as String, msg['sdp']['type'] as String),
        );
        break;
      case 'ice':
        if (msg['from'] != 'viewer') return;
        final viewer = _viewers[msg['viewerId'] as String];
        if (viewer == null) return;
        final c = msg['candidate'] as Map<String, dynamic>;
        await viewer.peerConnection.addCandidate(
          RTCIceCandidate(c['candidate'] as String?, c['sdpMid'] as String?, c['sdpMLineIndex'] as int?),
        );
        break;
      case 'error':
        _appendLog('Relay error: ${msg['reason']}');
        break;
    }
  }

  Future<void> _createViewerConnection(String viewerId) async {
    final pc = await createPeerConnection(_iceServers);
    final viewer = ViewerConnection(viewerId, pc);
    _viewers[viewerId] = viewer;

    pc.onIceCandidate = (candidate) {
      _signaling?.sink.add(jsonEncode({
        'type': 'ice',
        'viewerId': viewerId,
        'candidate': candidate.toMap(),
      }));
    };

    final dc = await pc.createDataChannel('captions', RTCDataChannelInit()..ordered = true);
    viewer.dataChannel = dc;
    dc.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        viewer.channelOpenedAt = DateTime.now();
        _appendLog('Data channel open for $viewerId');
      }
    };
    dc.onMessage = (message) {
      if (viewer.firstMessageLatency == null && viewer.channelOpenedAt != null) {
        viewer.firstMessageLatency = DateTime.now().difference(viewer.channelOpenedAt!);
        _appendLog('$viewerId first-message latency: ${viewer.firstMessageLatency!.inMilliseconds}ms');
        setState(() {});
      }
    };

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _signaling?.sink.add(jsonEncode({
      'type': 'offer',
      'viewerId': viewerId,
      'sdp': {'sdp': offer.sdp, 'type': offer.type},
    }));

    setState(() {});
  }

  @override
  void dispose() {
    _memorySampler?.cancel();
    _captionSender?.cancel();
    _testDurationTimer?.cancel();
    _signaling?.sink.close();
    for (final v in _viewers.values) {
      v.dataChannel?.close();
      v.peerConnection.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latencies = _viewers.values
        .map((v) => v.firstMessageLatency)
        .whereType<Duration>()
        .map((d) => d.inMilliseconds)
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Spike 2.1 — Fan-Out Broadcaster')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _relayController,
                    decoration: const InputDecoration(labelText: 'Signaling relay URL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _broadcastIdController,
                    decoration: const InputDecoration(labelText: 'Broadcast ID'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _connect, child: const Text('Connect')),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              children: [
                Text('Active viewers: ${_viewers.length}'),
                Text('Messages sent: $_messagesSent'),
                if (!kIsWeb) Text('RSS: ${(_currentRssBytes / (1024 * 1024)).toStringAsFixed(1)} MB'),
                if (latencies.isNotEmpty)
                  Text(
                    'Latency ms — min ${latencies.first}, '
                    'p50 ${latencies[latencies.length ~/ 2]}, '
                    'max ${latencies.last}',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, i) => Text(_log[i], style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
