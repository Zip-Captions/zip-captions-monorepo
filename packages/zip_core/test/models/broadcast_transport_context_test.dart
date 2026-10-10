import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_limits.dart';
import 'package:zip_core/src/models/broadcast_transport_context.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';
import 'package:zip_core/src/services/webrtc/viewer_admission.dart';

class _FakeSignalingService implements SignalingService {
  @override
  StatusChannel statusChannel(BroadcastId id) => throw UnimplementedError();

  @override
  Future<void> submitJoinRequest(BroadcastId broadcastId, String peerId) =>
      throw UnimplementedError();

  @override
  Stream<JoinRequest> joinRequests(BroadcastId broadcastId) =>
      throw UnimplementedError();

  @override
  SessionSignalingChannel sessionChannel(String sessionId, String peerId) =>
      throw UnimplementedError();
}

void main() {
  group('BroadcastTransportContext', () {
    test('creates with all required fields', () {
      final signalingService = _FakeSignalingService();
      final broadcastId = BroadcastId.parse('K7M9X2');
      const iceServers = [
        IceServer(urls: ['stun:localhost:3478']),
        IceServer(
          urls: ['turn:localhost:3478'],
          username: 'turn-user',
          credential: 'turn-credential',
        ),
      ];
      final admission = ViewerAdmission(
        const BroadcastLimits(
          maxViewers: 50,
          presenceTimeout: Duration(seconds: 60),
          reconnectWindow: Duration(seconds: 120),
        ),
      );
      final context = BroadcastTransportContext(
        sessionId: 'session-1',
        broadcastId: broadcastId,
        signalingService: signalingService,
        iceServers: iceServers,
        admission: admission,
      );

      expect(context.sessionId, 'session-1');
      expect(context.broadcastId, same(broadcastId));
      expect(context.signalingService, same(signalingService));
      expect(context.iceServers, same(iceServers));
      expect(context.admission, same(admission));
    });
  });
}
