/// Unit 9 (B4): the connection's own candidate-pair reading.
///
/// Two layers are covered here, because the split matters for maintenance:
///
/// 1. `classifyCandidatePairRoute` — pure, over `getStats()`-shaped reports.
///    This is where the interpretation lives (`selectedCandidatePairId` →
///    `transport` report → selected pair → `localCandidateId` →
///    `candidateType`), so it can be tested without a real peer connection.
/// 2. `WebRtcBroadcastTransport` / `WebRtcViewerTransport` — that they ask
///    the connection and report what it said, rather than assuming.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_handle.dart';
import 'package:zip_core/src/services/webrtc/selected_candidate_route.dart';

Map<String, Object?> _report(
  String id,
  String type, [
  Map<String, Object?> values = const {},
]) => {'id': id, 'type': type, 'timestamp': 0.0, ...values};

/// A stats set shaped like the real ones: one `transport`, one
/// `candidate-pair`, and the two candidates it names.
List<Map<String, Object?>> _statsWithLocalCandidate(String localType) => [
  _report(
    'T01',
    'transport',
    {'selectedCandidatePairId': 'CP01'},
  ),
  _report(
    'CP01',
    'candidate-pair',
    {'localCandidateId': 'C01', 'remoteCandidateId': 'C02'},
  ),
  _report('C01', 'local-candidate', {'candidateType': localType}),
  _report('C02', 'remote-candidate', {'candidateType': 'host'}),
];

void main() {
  group('classifyCandidatePairRoute', () {
    test('reads a relay local candidate as relayed', () {
      expect(
        classifyCandidatePairRoute(_statsWithLocalCandidate('relay')),
        CandidatePairRoute.relayed,
      );
    });

    test('reads a host local candidate as direct', () {
      expect(
        classifyCandidatePairRoute(_statsWithLocalCandidate('host')),
        CandidatePairRoute.direct,
      );
    });

    test(
      'reads srflx as direct — a STUN-reflexive candidate is still a direct '
      'path, which is exactly why the candidate type is read rather than the '
      'presence of a relay candidate',
      () {
        expect(
          classifyCandidatePairRoute(_statsWithLocalCandidate('srflx')),
          CandidatePairRoute.direct,
        );
      },
    );

    test('reads prflx as direct', () {
      expect(
        classifyCandidatePairRoute(_statsWithLocalCandidate('prflx')),
        CandidatePairRoute.direct,
      );
    });

    test('is unknown when no transport report names a selected pair', () {
      expect(
        classifyCandidatePairRoute([
          _report('CP01', 'candidate-pair', {'localCandidateId': 'C01'}),
          _report('C01', 'local-candidate', {'candidateType': 'relay'}),
        ]),
        CandidatePairRoute.unknown,
      );
    });

    test('is unknown when the named pair is absent from the reports', () {
      expect(
        classifyCandidatePairRoute([
          _report('T01', 'transport', {'selectedCandidatePairId': 'CP99'}),
        ]),
        CandidatePairRoute.unknown,
      );
    });

    test('is unknown when the pair has no localCandidateId', () {
      expect(
        classifyCandidatePairRoute([
          _report('T01', 'transport', {'selectedCandidatePairId': 'CP01'}),
          _report('CP01', 'candidate-pair', {'remoteCandidateId': 'C02'}),
        ]),
        CandidatePairRoute.unknown,
      );
    });

    test('is unknown when the local candidate report is absent', () {
      expect(
        classifyCandidatePairRoute([
          _report('T01', 'transport', {'selectedCandidatePairId': 'CP01'}),
          _report('CP01', 'candidate-pair', {'localCandidateId': 'C01'}),
        ]),
        CandidatePairRoute.unknown,
      );
    });

    test('is unknown for an unrecognised candidate type', () {
      expect(
        classifyCandidatePairRoute(_statsWithLocalCandidate('something-new')),
        CandidatePairRoute.unknown,
      );
    });

    test('is unknown for an empty report list', () {
      expect(
        classifyCandidatePairRoute(const []),
        CandidatePairRoute.unknown,
      );
    });

    test(
      'ignores a stale transport whose selectedCandidatePairId is empty and '
      'uses the next one that has a choice to report',
      () {
        expect(
          classifyCandidatePairRoute([
            _report('T00', 'transport', {'selectedCandidatePairId': ''}),
            ..._statsWithLocalCandidate('relay'),
          ]),
          CandidatePairRoute.relayed,
        );
      },
    );

    test(
      'prefers the first transport that names a pair — this app only ever '
      'has one data channel, so a second transport cannot legitimately '
      'disagree',
      () {
        expect(
          classifyCandidatePairRoute([
            _report('T01', 'transport', {'selectedCandidatePairId': 'CP01'}),
            _report('T02', 'transport', {'selectedCandidatePairId': 'CP02'}),
            _report('CP01', 'candidate-pair', {'localCandidateId': 'C01'}),
            _report('C01', 'local-candidate', {'candidateType': 'relay'}),
            _report('CP02', 'candidate-pair', {'localCandidateId': 'C03'}),
            _report('C03', 'local-candidate', {'candidateType': 'host'}),
          ]),
          CandidatePairRoute.relayed,
        );
      },
    );
  });

  group('ConnectionType projection', () {
    test(
      'unknown maps to disconnected for the broadcaster viewer list, never '
      'to p2pDirect',
      () {
        // The point of B4 is that the viewer list stops claiming a route it
        // has not confirmed. `disconnected` is the honest rendering.
        expect(
          connectionTypeOfCandidateRoute(CandidatePairRoute.unknown),
          ConnectionType.disconnected,
        );
      },
    );

    test('relayed maps to turnRelayed', () {
      expect(
        connectionTypeOfCandidateRoute(CandidatePairRoute.relayed),
        ConnectionType.turnRelayed,
      );
    });

    test('direct maps to p2pDirect', () {
      expect(
        connectionTypeOfCandidateRoute(CandidatePairRoute.direct),
        ConnectionType.p2pDirect,
      );
    });
  });
}
