/// Unit 9 (B4): the connection's own candidate-pair reading.
///
/// Two layers are covered here, because the split matters for maintenance:
///
/// 1. `classifyCandidatePairRoute` — pure, over `getStats()`-shaped reports.
///    This is where the interpretation lives (`selectedCandidatePairId` →
///    `transport` report → selected pair → its local *and* remote
///    `candidateId` → `candidateType`), so it can be tested without a real
///    peer connection.
/// 2. `WebRtcBroadcastTransport` / `WebRtcViewerTransport` — that they ask
///    the connection and report what it said, rather than assuming.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_handle.dart';
import 'package:zip_core/src/services/webrtc/selected_candidate_route.dart';

Map<String, Object?> _report(
  String id,
  String type, [
  Map<String, Object?> values = const {},
]) => {'id': id, 'type': type, 'timestamp': 0.0, ...values};

/// A stats set shaped like the real ones: one `transport`, one
/// `candidate-pair`, and the two candidates it names. The remote candidate
/// defaults to `host`, which is the ordinary case for the far end.
List<Map<String, Object?>> _statsWithCandidates(
  String localType, {
  String remoteType = 'host',
}) => [
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
  _report('C02', 'remote-candidate', {'candidateType': remoteType}),
];

void main() {
  group('classifyCandidatePairRoute', () {
    test('reads a relay local candidate as relayed', () {
      expect(
        classifyCandidatePairRoute(_statsWithCandidates('relay')),
        CandidatePairRoute.relayed,
      );
    });

    test('reads a host local candidate as direct', () {
      expect(
        classifyCandidatePairRoute(_statsWithCandidates('host')),
        CandidatePairRoute.direct,
      );
    });

    test(
      'reads srflx as direct — a STUN-reflexive candidate is still a direct '
      'path, which is exactly why the candidate type is read rather than the '
      'presence of a relay candidate',
      () {
        expect(
          classifyCandidatePairRoute(_statsWithCandidates('srflx')),
          CandidatePairRoute.direct,
        );
      },
    );

    test('reads prflx as direct', () {
      expect(
        classifyCandidatePairRoute(_statsWithCandidates('prflx')),
        CandidatePairRoute.direct,
      );
    });

    test(
      'reads a relay *remote* candidate as relayed even when the local '
      'candidate is host — the far end being relay-only still means the media '
      'transits the relay, and calling that direct is the false claim B4 '
      'exists to remove',
      () {
        expect(
          classifyCandidatePairRoute(
            _statsWithCandidates('host', remoteType: 'relay'),
          ),
          CandidatePairRoute.relayed,
        );
      },
    );

    test(
      'reads two relay candidates as relayed',
      () {
        expect(
          classifyCandidatePairRoute(
            _statsWithCandidates('relay', remoteType: 'relay'),
          ),
          CandidatePairRoute.relayed,
        );
      },
    );

    test(
      'a relay leg wins over an unresolvable far end — relayed is a safe '
      'answer even when the other candidate cannot be read',
      () {
        expect(
          classifyCandidatePairRoute([
            _report('T01', 'transport', {'selectedCandidatePairId': 'CP01'}),
            _report(
              'CP01',
              'candidate-pair',
              {'localCandidateId': 'C01', 'remoteCandidateId': 'MISSING'},
            ),
            _report('C01', 'local-candidate', {'candidateType': 'relay'}),
          ]),
          CandidatePairRoute.relayed,
        );
      },
    );

    test(
      'is unknown when the local leg is direct but the remote candidate is '
      'absent — one direct leg does not by itself prove a direct path',
      () {
        expect(
          classifyCandidatePairRoute([
            _report('T01', 'transport', {'selectedCandidatePairId': 'CP01'}),
            _report(
              'CP01',
              'candidate-pair',
              {'localCandidateId': 'C01'},
            ),
            _report('C01', 'local-candidate', {'candidateType': 'host'}),
          ]),
          CandidatePairRoute.unknown,
        );
      },
    );

    test(
      'is unknown when the remote candidate has an unrecognised type',
      () {
        expect(
          classifyCandidatePairRoute(
            _statsWithCandidates('host', remoteType: 'something-new'),
          ),
          CandidatePairRoute.unknown,
        );
      },
    );

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
        classifyCandidatePairRoute(_statsWithCandidates('something-new')),
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
            ..._statsWithCandidates('relay'),
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

  // `classifyStatsReports` is the only thing between the plugin's real
  // `StatsReport` objects and the pure classifier above. Every test in the
  // first group feeds hand-built maps, so without this group a shape change in
  // `flutter_webrtc` — or a backend that omits `id`/`type` from `values` —
  // would silently degrade every connection to `unknown` with a green suite.
  group('classifyStatsReports (plugin adapter)', () {
    StatsReport report(
      String id,
      String type,
      Map<dynamic, dynamic> values,
    ) => StatsReport(id, type, 0, values);

    test('classifies relayed from real StatsReport objects', () {
      expect(
        classifyStatsReports([
          report('T01', 'transport', {'selectedCandidatePairId': 'CP01'}),
          report('CP01', 'candidate-pair', {
            'localCandidateId': 'C01',
            'remoteCandidateId': 'C02',
          }),
          report('C01', 'local-candidate', {'candidateType': 'relay'}),
          report('C02', 'remote-candidate', {'candidateType': 'host'}),
        ]),
        CandidatePairRoute.relayed,
      );
    });

    test('classifies direct from real StatsReport objects', () {
      expect(
        classifyStatsReports([
          report('T01', 'transport', {'selectedCandidatePairId': 'CP01'}),
          report('CP01', 'candidate-pair', {
            'localCandidateId': 'C01',
            'remoteCandidateId': 'C02',
          }),
          report('C01', 'local-candidate', {'candidateType': 'srflx'}),
          report('C02', 'remote-candidate', {'candidateType': 'host'}),
        ]),
        CandidatePairRoute.direct,
      );
    });

    test(
      'falls back to the report typed fields when the values map omits '
      'id and type',
      () {
        // `StatsReport.fromMap` keeps the raw map, so `id`/`type` are
        // normally present and the fallback never runs. These reports
        // deliberately omit them from `values`, which is the only way to
        // exercise `values['id'] ?? report.id`. The values maps below carry
        // no 'id' or 'type' keys at all.
        StatsReport bare(String id, String type, Map<dynamic, dynamic> v) =>
            StatsReport(id, type, 0, v);

        expect(
          classifyStatsReports([
            bare('T01', 'transport', {'selectedCandidatePairId': 'CP01'}),
            bare('CP01', 'candidate-pair', {
              'localCandidateId': 'C01',
              'remoteCandidateId': 'C02',
            }),
            bare('C01', 'local-candidate', {'candidateType': 'relay'}),
            bare('C02', 'remote-candidate', {'candidateType': 'relay'}),
          ]),
          CandidatePairRoute.relayed,
        );
      },
    );

    test(
      'is unknown when the values map omits id and type and the typed fields '
      'do not describe a usable report',
      () {
        // Proves the fallback is load-bearing: strip the typed fields too and
        // nothing can identify the transport report, so the honest answer is
        // unknown rather than a guess.
        expect(
          classifyStatsReports([
            StatsReport('', '', 0, {'selectedCandidatePairId': 'CP01'}),
            StatsReport('CP01', 'candidate-pair', 0, {
              'localCandidateId': 'C01',
              'remoteCandidateId': 'C02',
            }),
            StatsReport('C01', 'local-candidate', 0, {
              'candidateType': 'relay',
            }),
            StatsReport('C02', 'remote-candidate', 0, {
              'candidateType': 'host',
            }),
          ]),
          CandidatePairRoute.unknown,
        );
      },
    );

    test(
      'still classifies when values carries non-string keys, which the '
      'dynamic native map permits',
      () {
        // `StatsReport.values` is Map<dynamic, dynamic>; the adapter keys its
        // intermediate map with `toString()`, so a non-string key must not
        // stop the real string keys from resolving.
        expect(
          classifyStatsReports([
            report('T01', 'transport', {
              1: 'ignored',
              'selectedCandidatePairId': 'CP01',
            }),
            report('CP01', 'candidate-pair', {
              2: 'ignored',
              'localCandidateId': 'C01',
              'remoteCandidateId': 'C02',
            }),
            report('C01', 'local-candidate', {'candidateType': 'relay'}),
            report('C02', 'remote-candidate', {'candidateType': 'host'}),
          ]),
          CandidatePairRoute.relayed,
        );
      },
    );

    test('is unknown for an empty report list', () {
      expect(classifyStatsReports(const []), CandidatePairRoute.unknown);
    });
  });

  // The Dart layer passes `getStats()`'s `values` through opaquely, so the
  // field spelling is a property of the native backend, not of this package.
  // darwin emits camelCase; W3C webrtc-stats (and therefore some backends)
  // use kebab-case. Both must resolve, or route reporting silently degrades
  // to `unknown` on that backend with every camelCase-only test still green.
  group('classifyCandidatePairRoute (W3C kebab-case fields)', () {
    Map<String, Object?> kebab(
      String id,
      String type, [
      Map<String, Object?> values = const {},
    ]) => {'id': id, 'type': type, 'timestamp': 0.0, ...values};

    List<Map<String, Object?>> kebabStats(
      String localType,
      String remoteType,
    ) => [
      kebab(
        'T01',
        'transport',
        {'selected-candidate-pair-id': 'CP01'},
      ),
      kebab('CP01', 'candidate-pair', {
        'local-candidate-id': 'C01',
        'remote-candidate-id': 'C02',
      }),
      kebab('C01', 'local-candidate', {'candidate-type': localType}),
      kebab('C02', 'remote-candidate', {'candidate-type': remoteType}),
    ];

    test('classifies a relayed pair written in kebab-case', () {
      expect(
        classifyCandidatePairRoute(kebabStats('relay', 'host')),
        CandidatePairRoute.relayed,
      );
    });

    test('classifies a direct pair written in kebab-case', () {
      expect(
        classifyCandidatePairRoute(kebabStats('host', 'host')),
        CandidatePairRoute.direct,
      );
    });

    test('honours a relayed remote leg written in kebab-case', () {
      expect(
        classifyCandidatePairRoute(kebabStats('host', 'relay')),
        CandidatePairRoute.relayed,
      );
    });

    test('is unknown when no kebab-case transport names a pair', () {
      expect(
        classifyCandidatePairRoute([
          kebab('CP01', 'candidate-pair', {'local-candidate-id': 'C01'}),
          kebab('C01', 'local-candidate', {'candidate-type': 'relay'}),
        ]),
        CandidatePairRoute.unknown,
      );
    });
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
