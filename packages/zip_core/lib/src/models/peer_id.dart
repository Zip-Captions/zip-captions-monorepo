import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a fresh, single-use peer id for one connection attempt
/// (domain-entities.md, Signaling Channel Privacy — Unit 3.1).
///
/// A v4 UUID has 122 bits of randomness (RFC 9562 §5.4 — 6 of the 128 bits
/// are fixed version/variant markers, not random) — astronomically
/// unguessable for this purpose, and never derived from account identity.
/// **Corrected 2026-10-07**: the design's earlier "128 bits" figure
/// (`domain-entities.md`, `logical-components.md`) overstated what a v4
/// UUID actually provides; both were corrected to the real 122-bit figure
/// rather than switching to a different generator, since 122 bits already
/// exceeds what unguessability needs here by a wide margin.
/// Call this again (never reuse a prior value) for every `connect()`/
/// `restart()` attempt, per business-rules.md Rule 5: a fresh `peerId` per
/// attempt means a leaked or logged one has no ongoing value once that one
/// connection attempt ends.
String peerId() => _uuid.v4();
