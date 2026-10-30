import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_core/zip_core.dart';

/// A [ZcStrings] whose every value is derived from its key.
///
/// Widget tests assert on these sentinels to prove a screen renders ARB
/// copy rather than an inline literal; placeholder keys keep their
/// `{sessionName}` shape so formatting is still exercised.
const sentinelStrings = ZcStrings.fromMap({});

/// The provider override for [zcStringsProvider].
Override sentinelStringsOverride() =>
    zcStringsProvider.overrideWith((ref) async => sentinelStrings);

/// Fake [BroadcastResolver]: scripted results, no network.
class FakeViewerResolver implements BroadcastResolver {
  /// Creates a resolver that yields [resolutions] in order, then repeats
  /// the last one.
  FakeViewerResolver(List<BroadcastResolution> resolutions)
    : _resolutions = [...resolutions];

  final List<BroadcastResolution> _resolutions;

  /// The IDs passed to [resolve].
  final resolvedIds = <BroadcastId>[];

  @override
  Future<BroadcastResolution> resolve(BroadcastId id) async {
    resolvedIds.add(id);
    if (_resolutions.length > 1) return _resolutions.removeAt(0);
    return _resolutions.first;
  }
}

/// Fake [StatusChannel] whose liveness stream a test drives by hand.
class FakeViewerStatusChannel implements StatusChannel {
  final _controller = StreamController<BroadcastStatus>.broadcast();

  @override
  Stream<BroadcastStatus> watch() => _controller.stream;

  /// Emits [status] to the viewer's status watch.
  void emit(BroadcastStatus status) => _controller.add(status);

  @override
  Future<void> publishLive({
    required String sessionId,
    required String sessionName,
  }) async {}

  @override
  Future<void> publishOffline() async {}

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

/// Fake [SignalingService] that hands out one [FakeViewerStatusChannel].
///
/// Only `statusChannel` is reached by the viewer notifier; the other members
/// throw so an accidental broadcaster-side call fails loudly.
class FakeViewerSignalingService implements SignalingService {
  /// The channel returned by every [statusChannel] call.
  final channel = FakeViewerStatusChannel();

  /// The broadcast IDs whose status channel was opened.
  final openedFor = <BroadcastId>[];

  @override
  StatusChannel statusChannel(BroadcastId id) {
    openedFor.add(id);
    return channel;
  }

  @override
  Future<void> submitJoinRequest(BroadcastId broadcastId, String peerId) =>
      throw UnimplementedError('viewer never submits join requests');

  @override
  Stream<JoinRequest> joinRequests(BroadcastId broadcastId) =>
      throw UnimplementedError();

  @override
  SessionSignalingChannel sessionChannel(String sessionId, String peerId) =>
      throw UnimplementedError();
}

/// Fake [ViewerTransport] whose status and messages a test drives by hand.
class FakeViewerTransport implements ViewerTransport {
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messagesController = StreamController<CaptionWireMessage>.broadcast();

  /// How many times [connect] ran.
  int connectCalls = 0;

  /// How many times [disconnect] ran.
  int disconnectCalls = 0;

  @override
  Future<void> connect(ViewerTransportContext context) async {
    connectCalls++;
  }

  @override
  Future<void> restart() async {}

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  Stream<CaptionWireMessage> get messages => _messagesController.stream;

  @override
  Stream<ConnectionStatus> get status => _statusController.stream;

  /// Emits [status] on the transport status stream.
  void emitStatus(ConnectionStatus status) => _statusController.add(status);

  /// Emits [message] on the message stream.
  void emitMessage(CaptionWireMessage message) =>
      _messagesController.add(message);

  /// Closes the internal controllers (call from `tearDown`).
  Future<void> dispose() async {
    await _statusController.close();
    await _messagesController.close();
  }
}

/// An [IceServerProvider] returning [servers] (one entry by default, so the
/// notifier does not treat the configuration as missing).
class FakeViewerIceServerProvider implements IceServerProvider {
  /// Creates the fake; [servers] defaults to a single placeholder entry.
  FakeViewerIceServerProvider({List<IceServer>? servers})
    : servers = servers ?? const [_placeholder];

  static const _placeholder = IceServer(urls: ['stun:invalid.invalid']);

  /// The servers returned by [iceServersFor].
  final List<IceServer> servers;

  @override
  Future<List<IceServer>> iceServersFor(String sessionId) async => servers;

  @override
  Future<List<IceServer>> iceServersForBroadcast(String broadcastId) async =>
      servers;
}

/// A [ViewerTransport] factory returning a fresh [FakeViewerTransport].
class RecordingViewerTransportFactory {
  /// Every transport this factory produced, in creation order.
  final transports = <FakeViewerTransport>[];

  /// The most recently produced transport.
  FakeViewerTransport get latest => transports.last;

  /// Creates a transport and records it.
  ViewerTransport call() {
    final transport = FakeViewerTransport();
    transports.add(transport);
    return transport;
  }
}
