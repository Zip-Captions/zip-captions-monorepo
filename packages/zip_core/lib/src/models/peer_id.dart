import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a fresh, single-use peer id for one connection attempt
/// (domain-entities.md, Signaling Channel Privacy — Unit 3.1).
///
/// A v4 UUID has 122 bits of randomness — far more than the "at least 128
/// bits" entropy requirement, and is never derived from account identity.
/// Call this again (never reuse a prior value) for every `connect()`/
/// `restart()` attempt, per business-rules.md Rule 5: a fresh `peerId` per
/// attempt means a leaked or logged one has no ongoing value once that one
/// connection attempt ends.
String peerId() => _uuid.v4();
