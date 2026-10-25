# On-Device Multilingual STT — Unit Status and Pickup Note

**Status: PARKED (human decision, recorded 2026-10-21).** Functional Design
artifacts are written and committed, awaiting the human FD-approval gate.
Everything downstream has not started. This unit resumes only after the other
session's Unit 8.1 pop-out overnight run completes and its PR merges to
`develop`.

**The one-line pitch.** A new `zip_core` `SttEngine` (chunk-decode /
simulated-streaming mode) on sherpa-onnx: Parakeet TDT 0.6B v3 int8 (~640 MB,
25 European languages, auto-detect) + Silero VAD, closing the de/es/it/nl/pl
gap with interim caption updates while the user speaks and a final on
end-of-speech. No new dependency (`sherpa_onnx: ^1.10.31` already declared),
no ADR-005 contract change, no network in the engine.

> **Added 2026-10-25 — read before the FD approval gate.** New research
> (`../spikes/stt-model-survey-2026-10-25.md`) found that Nemotron 3.5 ASR
> Streaming 0.6B is a sherpa-onnx-supported **true streaming** multilingual
> model, which weakens the premise below that no true-streaming sherpa model
> covers de/es/it/nl/pl. A split is proposed in `execution-plan.md`, section
> "Revision proposal (2026-10-25)". It is a proposal only: nothing in this unit's
> approved or recorded decisions has changed. It also flags that the FD assumes
> an existing audio pipeline while no PCM capture path was found in `zip_core`.
> Spike 1.4 gained Q8 (Nemotron, including phone targets).

## Read order at pickup

1. This file.
2. `execution-plan.md` — scope, binding inputs, stage sequence, gates, and the
   "Parking and Pickup" section (authoritative pickup procedure).
3. `functional-design/handoff-summary.md` — the compressed binding decisions
   for the next stage (NFR Requirements).
4. `functional-design/` — the four FD artifacts (for the approval gate).
5. `../plans/on-device-multilingual-stt-functional-design-plan.md` — the 14
   recorded answers (`[Answer]: A` blocks) and the reasoning.
6. `../spikes/spike-1.4-plan.md` — the spike plan (DRAFT, not executed) and the
   Whistle/Sherpa-ONNX research findings.

## What exists (all committed; lands on `develop` via the pop-out run's PR)

| Path | What it is | State |
|---|---|---|
| `execution-plan.md` | Unit scope, stages, gates, parking record | current |
| `functional-design/business-logic-model.md` | Engine lifecycle + simulated-streaming state machine + adapter operations | written, **unapproved** |
| `functional-design/business-rules.md` | 12 numbered rules, each traced to its Q-answer | written, **unapproved** |
| `functional-design/domain-entities.md` | `MultilingualSttEngineConfig`, catalog-entry extension, `SherpaModelKind`, internal types | written, **unapproved** |
| `functional-design/frontend-components.md` | Picker/catalog row contracts + 4 ARB keys (no new screens — verified: neither app has a picker/catalog UI yet) | written, **unapproved** |
| `functional-design/handoff-summary.md` | FD → NFR handoff (binding decisions, constraints, open questions) | written |
| `../plans/on-device-multilingual-stt-functional-design-plan.md` | FD stage plan, 14/14 answers recorded | complete |
| `../spikes/spike-1.4-plan.md` | Whistle vs Sherpa-ONNX spike plan + sherpa-onnx language-coverage findings | **DRAFT — not approved, not executed** |

## Gate state (exact)

- FD answers: 14/14 collected (2026-10-20, all option A; Q1 refined in review
  for the streaming-caption premise — simulated streaming, not final-only).
- FD approval gate: **NOT passed** — first human action at pickup.
- Spike 1.4: plan DRAFT; needs human approval, then execution (device work).
  Its report **hard-gates Code Generation Parts 1+2** (OQ-2) and supplies the
  NFR param values (Q7 was expanded to measure **interim update latency** at
  1 s / 2 s re-decode cadences over 5/10/20 s utterances, final latency vs the
  < 1 s budget, peak RAM, RTF 1 vs 4 threads).
- NFR Requirements / NFR Design: may be drafted on vendor-flagged data before
  the spike (OQ-2 precedent, Unit 5 / Spike 2.1) — values flagged
  "pending Spike 1.4 verification", revised in place when the report lands.
- Nothing in `aidlc-state.md`/`audit.md` yet (owned by the running session);
  the pickup session registers this unit at its first approval point.

## Binding decisions that must not be re-derived

- New engine (new class + engineId), streaming engine byte-for-byte untouched.
  One `OfflineSttAdapter` seam mirroring `OnlineRecognizerAdapter`; hand-written
  fakes; native lib never loaded in unit tests.
- Simulated streaming = the design, not a fallback: interim re-decodes of the
  whole VAD segment on a cadence (non-final `SttResult` → caption pipeline's
  trailing-interim line), final on VAD end-of-speech (commits the line). One
  segment and one decode in flight at a time; cadence ticks skipped, not queued.
- Cadence / max-segment / min-buffer / VAD / thread parameters are
  `MultilingualSttEngineConfig` fields — **values set at NFR from Spike 1.4 Q7**,
  never invented at FD.
- Auto-detect only in v1 (selected locale not used for decoding); catalog entry
  extended additively (`localeIds`, `kind`, `engineId`; schema-1 compatible —
  `primaryLocaleId` stays required); engine registered iff **all** entries
  sharing its `engineId` are downloaded, unregistered when any is deleted.
- Fail-soft: init failure → unavailable; interim failure → drop update; final
  failure → best-effort commit (last good interim, or drop). `pause()` discards;
  `stopListening()` flushes only ≥ `minSpeechDuration`.
- SECURITY-03 includes native error messages (log the type, not the message) +
  a record-level redaction audit test. Engine never touches the network
  (paths via `SherpaModelManager`). VAD is engine-internal; pipeline, session
  manager, caption bus, other engines, download lifecycle: unchanged.
- "Offline" = model family, never network posture (terminology fixed in review).
- `SttResult` mapping fixed (Rule 12); **no** word-timestamp field (ADR-005).

## Expensive-to-rediscover facts (verified 2026-10-20 against indexed docs)

- Simulated streaming is a documented sherpa-onnx mode
  (`sherpa-onnx-vad-microphone-simulated-streaming-asr`); an **official
  Parakeet TDT 0.6B v3 simulated-streaming APK** exists in sherpa-onnx's
  release set — the combination is vendor-supported.
- No true-streaming (causal) pretrained sherpa model for de/es/it/nl/pl (the
  streaming zoo is en/zh/fr/ko/bn/ru/ja/th/vi). Whistle (16.9 MB, 7 languages,
  2-bit, Apache-2.0, C API `needle_*`, WASM) is the only true-streaming
  multilingual candidate — deliberately a **separate future unit**, decided by
  Spike 1.4 Q1/Q2/Q5/Q6.
- Parakeet TDT 0.6B v3 int8: encoder 622 M + decoder 12 M + joiner 6.1 M +
  tokens; FLEURS WER de 5.04 / es 3.45 / fr 5.15 / it 3.00 / nl 7.48 /
  pl 7.31 / en 4.85; CC-BY-4.0; transducer (hotword-capable — config seam kept,
  no v1 hotword source). All figures vendor-flagged until Spike 1.4 Q7.
- Omnilingual 300M (348 MB, 1600+ languages) is license-unverified — out of
  v1 scope; the catalog `kind` discriminator makes it a future row addition.
- Neither app has an engine-picker or model-catalog UI yet
  (`packages/zip_captions/lib/main.dart:57` registers only `FakeSttEngine`);
  this unit contributes row contracts + ARB strings + registration, not screens.

## Environment / collision facts at parking

- Other session: Unit 8.1 pop-out overnight run (config in
  `.agent/overnight-pipeline.md`), working **in this checkout** on
  `feature/popout-live-captions` (local only, never pushed; opens its own PR at
  the end of the run). At parking: FD/NFR-R/NFR-D approved and committed
  (`72c7cd8` before this unit's planning commits); Infrastructure Design and
  Code Generation not started. **Do not touch** that session's files
  (`.agent/`, `aidlc-state.md`, `audit.md`, `aidlc-docs/construction/pop-out/**`)
  or its branch.
- This unit's planning docs ride on `feature/popout-live-captions` (commits
  `a8fad31`…`218eba7` + the parking commit) and reach `develop` through that
  run's PR — the pickup worktree branched from `develop` therefore contains the
  full corpus with no cherry-picking.
- `develop` at parking = `5e3bd3b` (PR #39). PR #40
  (`fix/zip-broadcast-runner-callbacks`) is NOT on `develop` yet — it is the
  pop-out run's stated kickoff precondition; verify it is merged before
  creating the pickup worktree.
- docs-mcp has `sherpa-onnx` and `cactus-needle` indexes live — use them for
  any model/API re-checks (`docs-mcp_search_docs`).

## What the pickup session must not do

- Start any Construction stage without passing the FD approval gate.
- Begin Code Generation (Parts 1 or 2) without the Spike 1.4 report.
- Edit `docs/`, `stories/`, `aidlc-docs/inception/**`, or state/audit files
  except at the approval points the AI-DLC rules define (unit number, story-map
  row, roadmap line land in Documentation Refinement with per-change approval).
- Add dependencies, or touch the streaming engine, the audio pipeline, the
  caption bus, or the download lifecycle.
- Work in this checkout — create the unit's own worktree from `develop` first
  (one unit per worktree, one worktree per PR).
