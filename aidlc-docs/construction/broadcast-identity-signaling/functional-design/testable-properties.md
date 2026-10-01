# Testable Properties — Broadcast Identity + Signaling (PBT-01)

| Component / Behavior | Property | Category |
|---|---|---|
| `BroadcastId.parse` / `.value` | For any valid-alphabet 6-character string, `BroadcastId.parse(s).value == s` — parsing never mutates a valid code. | Invariant |
| `BroadcastLink.parseInput` / `BroadcastLink.toUrl` | For any generated `BroadcastId`, `BroadcastLink.parseInput(BroadcastLink.toUrl(id).toString()) == id` — formatting to a URL and parsing it back recovers the original id. | Round-trip |
| `BroadcastLink.parseInput` | For any generated arbitrary string (not just valid codes — includes garbage, empty, oversized, non-ASCII), `parseInput` never throws; it returns either a valid `BroadcastId` or `null`. | Invariant |
| `SignalingCodec.encode` / `.decode` | For any generated valid `SignalingMessage` of any variant, `decode(encode(message)) == message`. | Round-trip |
| `SignalingCodec.decode` | For any generated arbitrary JSON-shaped input (malformed structure, unknown `type`, wrong `version`, oversized payloads, wrong field types), `decode` never throws; it returns either a valid `SignalingMessage` or `null` (FR-3.2, Rule 4). | Invariant |

## Marked N/A

- **Idempotence**: no operation in this unit claims idempotence in the PBT-04 sense
  (`f(f(x)) == f(x)`) — `getOrCreateMine()`'s "calling it again returns the same value"
  is a *stateful* property (depends on prior database state, not a pure function of its
  input), covered as a stateful/integration concern below, not a pure-function
  idempotence property.
- **Oracle**: no reference/brute-force implementation exists to compare against.
- **Commutativity**: no commutative operation exists in this unit's domain.
- **Induction**: no recursive/tree-shaped structures exist in this unit's domain.

## Stateful / Integration-Level Properties (Carried to Code Generation, Not Pure-Dart PBT)

`get_or_create_my_broadcast_id()`'s uniqueness and reuse guarantees (SR-02 §1/§3, Rule 1)
are enforced by Postgres constraints and function logic, not pure Dart code — they
cannot be exercised by this project's in-process PBT shim (`test/helpers/pbt.dart`,
which has no database). These are covered instead by integration tests against the
local Supabase stack at Code Generation (per NFR-7.3's "integration tests run against
the local Supabase stack"), not by a `Glados`-style property test:
- Calling `getOrCreateMine()` twice for the same authenticated user returns the same
  `BroadcastId` both times.
- Two concurrent `getOrCreateMine()` calls for two different users never collide on the
  same generated code (or, if they by chance generate the same random candidate, the
  unique constraint forces a retry rather than a silent duplicate).

## Carried to Code Generation

Generator quality (PBT-07) for `SignalingMessage`: the generator must produce every
sealed variant with realistic field values (valid peer-id-shaped strings, valid SDP/ICE
placeholder shapes for `SdpOffer`/`SdpAnswer`/`IceCandidate` — not arbitrary strings for
fields that have real structure), plus a separate "adversarial" generator layer for the
`decode`-never-throws property that deliberately produces malformed variants (missing
fields, wrong types, unknown `type` values, huge strings) — these are two different
generators serving two different properties above, not one generator reused for both.
