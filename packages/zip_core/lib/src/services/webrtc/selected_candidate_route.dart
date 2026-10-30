import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_handle.dart';

/// Classifies a `getStats()` result set by the candidate pair actually
/// carrying traffic (Unit 9, B4).
///
/// Kept as a pure function over plain maps, deliberately: the interpretation
/// is the part worth testing, and it should be testable without a native peer
/// connection. The live handle does nothing but pass
/// `RTCPeerConnection.getStats()`'s own `values` maps in here.
///
/// The shape being navigated (W3C webrtc-stats):
///
/// - a `transport` report carries `selectedCandidatePairId`;
/// - that id names a `candidate-pair` report, which carries both
///   `localCandidateId` and `remoteCandidateId`;
/// - those ids name candidate reports carrying `candidateType`
///   (`host` / `srflx` / `prflx` / `relay`).
///
/// Both ends are read, not just the local one. A pair is relayed if *either*
/// candidate is a relay: when the viewer sits behind an ordinary NAT but the
/// broadcaster is relay-only, the viewer's own candidate is `host` while the
/// media still transits Coturn. Reading only `localCandidateId` would report
/// that connection as `direct`, which is the precise false claim this
/// classifier exists to prevent.
///
/// Anything that does not resolve cleanly is [CandidatePairRoute.unknown] —
/// never a guess. Erring towards "unknown" is the whole point: the failure
/// this replaces was a hardcoded optimistic answer.
CandidatePairRoute classifyCandidatePairRoute(
  Iterable<Map<String, Object?>> reports,
) {
  final byId = <String, Map<String, Object?>>{};
  String? selectedPairId;
  for (final report in reports) {
    final id = report['id'];
    if (id is String) byId[id] = report;
    if (selectedPairId != null) continue;
    if (report['type'] != 'transport') continue;
    final selected = report['selectedCandidatePairId'];
    if (selected is String && selected.isNotEmpty) selectedPairId = selected;
  }
  if (selectedPairId == null) return CandidatePairRoute.unknown;

  final pair = byId[selectedPairId];
  final localType = _candidateTypeOf(byId, pair?['localCandidateId']);
  final remoteType = _candidateTypeOf(byId, pair?['remoteCandidateId']);

  // Either leg relayed means the media transits the relay. Checked before the
  // unknown case so a resolvable relay leg cannot be downgraded by an
  // unresolvable far end.
  if (localType == 'relay' || remoteType == 'relay') {
    return CandidatePairRoute.relayed;
  }
  if (_isDirectCandidateType(localType) && _isDirectCandidateType(remoteType)) {
    return CandidatePairRoute.direct;
  }
  return CandidatePairRoute.unknown;
}

/// The `candidateType` of the candidate report named by [id], or `null` when
/// the id is absent, not a string, or names no report.
String? _candidateTypeOf(
  Map<String, Map<String, Object?>> byId,
  Object? id,
) {
  if (id is! String) return null;
  final type = byId[id]?['candidateType'];
  return type is String ? type : null;
}

bool _isDirectCandidateType(String? type) =>
    type == 'host' || type == 'srflx' || type == 'prflx';

/// Projects a [CandidatePairRoute] onto the [ConnectionType] vocabulary the
/// viewer list exposes (FR-4.6).
///
/// Classifies the plugin's own `StatsReport` list by delegating to
/// [classifyCandidatePairRoute].
///
/// `StatsReport.values` is what `RTCPeerConnection.getStats()` actually
/// returns, and it is a raw `Map<dynamic, dynamic>` whose `'type'` /
/// `'id'` / `'candidateType'` / `'localCandidateId'` / `'remoteCandidateId'`
/// entries are plain strings on every native backend. Both candidate ids
/// reach the classifier, since either leg being a relay means relayed.
/// Anything unexpected yields [CandidatePairRoute.unknown] rather than
/// throwing — a malformed stats map must not be able to fail a live session.
CandidatePairRoute classifyStatsReports(Iterable<StatsReport> reports) {
  final maps = <Map<String, Object?>>[];
  for (final report in reports) {
    final values = report.values;
    maps.add({
      for (final entry in values.entries) entry.key.toString(): entry.value,
      // `fromMap` keeps the raw map, whose own 'id'/'type' entries are what
      // the classifier reads; the report's typed fields are the fallback for
      // any backend that omits them from the map.
      'id': values['id'] ?? report.id,
      'type': values['type'] ?? report.type,
    });
  }
  return classifyCandidatePairRoute(maps);
}

/// [CandidatePairRoute.unknown] becomes [ConnectionType.disconnected] — the
/// honest rendering of an unconfirmed route. Mapping it to `p2pDirect`
/// would restore exactly the silent claim Unit 9 removed.
ConnectionType connectionTypeOfCandidateRoute(CandidatePairRoute route) =>
    switch (route) {
      CandidatePairRoute.relayed => ConnectionType.turnRelayed,
      CandidatePairRoute.direct => ConnectionType.p2pDirect,
      CandidatePairRoute.unknown => ConnectionType.disconnected,
    };
