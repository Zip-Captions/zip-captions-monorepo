// Tests for S-19: Zip Captions Viewer, `ViewerSessionResources` teardown
// (Unit 7, NFR Design Q1/Q4, F-7.7).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/output/on_screen_caption_target.dart';
import 'package:zip_core/src/services/broadcast/viewer_session_resources.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/caption/caption_output_target_registry.dart';
import 'package:zip_core/src/services/caption/remote_caption_receiver.dart';

import '../../helpers/fake_broadcast_session_collaborators.dart';

/// Records teardown order across the fake/real collaborators.
class _OrderLog {
  final events = <String>[];
}

class _LoggingStatusChannel extends FakeStatusChannel {
  _LoggingStatusChannel(this.log);

  final _OrderLog log;

  @override
  Future<void> close() async {
    log.events.add('statusChannel.close');
    await super.close();
  }
}

class _LoggingTransport extends FakeViewerTransport {
  _LoggingTransport(this.log);

  final _OrderLog log;

  @override
  Future<void> disconnect() async {
    log.events.add('transport.disconnect');
    await super.disconnect();
  }
}

/// The collaborators a test observes after building the holder.
typedef _Built = ({
  ViewerSessionResources resources,
  CaptionOutputTargetRegistry registry,
  RemoteCaptionReceiver receiver,
  _LoggingStatusChannel statusChannel,
  _LoggingTransport transport,
});

_Built _build(_OrderLog log) {
  final transport = _LoggingTransport(log);
  final bus = CaptionBus();
  final target = OnScreenCaptionTarget(targetId: 'viewer');
  final registry = CaptionOutputTargetRegistry(bus)..add(target);
  final receiver = RemoteCaptionReceiver(transport: transport, viewerBus: bus);
  final statusChannel = _LoggingStatusChannel(log);

  final resources = ViewerSessionResources(
    broadcastId: BroadcastId.parse('K7M9X2'),
    sessionId: 'session-1',
    transport: transport,
    receiver: receiver,
    bus: bus,
    registry: registry,
    target: target,
    statusChannel: statusChannel,
    statusWatch: statusChannel.watch().listen((_) {{}}),
    statusSub: transport.status.listen((_) {{}}),
    activitySub: receiver.activity.listen((_) {{}}),
    endedSub: receiver.ended.listen((_) {{}}),
    windowTimer: Timer(const Duration(seconds: 120), () {}),
  );
  return (
    resources: resources,
    registry: registry,
    receiver: receiver,
    statusChannel: statusChannel,
    transport: transport,
  );
}

void main() {
  final log = Logger('zip_core.ViewerSessionResourcesTest');

  test('AC: disposeAll runs F-7.7 steps in order and releases every field',
      () async {
    final order = _OrderLog();
    final built = _build(order);
    final resources = built.resources;

    await resources.disposeAll(log);

    expect(
      order.events,
      equals(['statusChannel.close', 'transport.disconnect']),
    );
    expect(resources.windowTimer, isNull);
    expect(resources.statusWatch, isNull);
    expect(resources.statusChannel, isNull);
    expect(resources.transport, isNull);
    expect(resources.receiver, isNull);
    expect(resources.target, isNull);
    expect(resources.registry, isNull);
    expect(resources.bus, isNull);
    expect(resources.statusSub, isNull);
    expect(resources.activitySub, isNull);
    expect(resources.endedSub, isNull);
    // The identity fields survive teardown: they describe the session, not
    // a releasable resource.
    expect(resources.broadcastId.value, equals('K7M9X2'));
    expect(resources.sessionId, equals('session-1'));
  });

  test('AC: a failing disconnect is caught and later steps still run',
      () async {
    final order = _OrderLog();
    final built = _build(order);
    built.transport.disconnectError = Exception('native stack gone');

    await expectLater(built.resources.disposeAll(log), completes);

    expect(built.transport.disconnectCalls, equals(1));
    // Receiver/registry/bus were still released despite the failure.
    expect(built.resources.receiver, isNull);
    expect(built.resources.registry, isNull);
    expect(built.resources.bus, isNull);
  });

  test('AC: releaseTransport false skips disconnect', () async {
    final order = _OrderLog();
    final built = _build(order);

    await built.resources.disposeAll(log, releaseTransport: false);

    expect(built.transport.disconnectCalls, isZero);
    expect(built.resources.transport, isNotNull);
    expect(built.resources.receiver, isNull);
  });

  test('AC: a second disposeAll is a no-op and never throws', () async {
    final order = _OrderLog();
    final built = _build(order);

    await built.resources.disposeAll(log);
    await expectLater(built.resources.disposeAll(log), completes);

    expect(
      order.events,
      equals(['statusChannel.close', 'transport.disconnect']),
    );
    expect(built.statusChannel.closeCalls, equals(1));
    expect(built.transport.disconnectCalls, equals(1));
  });

  test('AC: releasing the target disposes its registry entry', () async {
    final order = _OrderLog();
    final built = _build(order);

    await built.resources.disposeAll(log);

    expect(built.registry.activeTargets, isEmpty);
  });

  test('AC: lastStatus is writable as the F-7.4 audit trail', () async {
    final order = _OrderLog();
    final built = _build(order);
    expect(built.resources.lastStatus, isNull);

    built.resources.lastStatus = const BroadcastStatus.offline();
    expect(built.resources.lastStatus, isA<BroadcastStatusOffline>());

    await built.resources.disposeAll(log);
  });
}
