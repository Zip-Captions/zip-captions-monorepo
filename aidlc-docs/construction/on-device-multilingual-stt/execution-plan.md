# Execution Plan: On-Device Multilingual STT

**Date**: 2026-10-20
**Status**: PARKED (human decision, recorded 2026-10-21). OQ-1/OQ-2/OQ-3 RESOLVED (all option A). Functional Design plan answers collected 2026-10-20 (14/14, all option A; Q1 refined in review for the streaming-caption premise — the engine's decode strategy is sherpa-onnx's documented **simulated-streaming** pattern: interim re-decodes while the user speaks + final on VAD end-of-speech). The four FD artifacts + handoff summary are **written and committed, awaiting the human FD-approval gate** — that gate has NOT been passed. Pickup path: Section "Parking and Pickup" below and the unit `README.md`.
**Unit number**: unassigned — see Open Question OQ-1 (roadmap placement is a human decision; this plan deliberately does not edit `docs/` or the inception unit-of-work artifacts).

**Origin**: the research recorded in `aidlc-docs/construction/spikes/spike-1.4-plan.md` (Whistle vs. Sherpa-ONNX spike plan, including the "Sherpa-ONNX Language Coverage — Findings" section added 2026-10-20 from the indexed sherpa-onnx and cactus-needle docs).
**Stories**: extends S-01 (STT Engine Interface and Registry) and S-02 (Platform-Native STT Implementation) — `aidlc-docs/inception/user-stories/stories.md`. Personas: low-spec always-on captioning machines (S2.5 remote machine), the Québec/French and other non-English speaker personas (`docs/01-user-personas.md`).
**Package**: `zip_core` (engine, catalog, models); `zip_captions` (settings/engine-picker surface only).
**Branch**: `feature/on-device-multilingual-stt` — created in an isolated worktree (`git worktree add ../zip-captions-on-device-multilingual-stt -b feature/on-device-multilingual-stt`) after this plan and the Functional Design plan are approved. One unit per worktree, one worktree per PR (AGENTS.md).

---

## Purpose

Phase 1 shipped on-device STT for the streaming model family (English-centric; the streaming pretrained zoo has no de/es/it/nl/pl models). The v1 UI is 11 languages. This unit adds a **multilingual on-device engine** so a user on any supported platform can caption in de/es/it/nl/pl (and the other 19 European languages the model covers) fully offline, without new infrastructure and without touching the ADR-005 `SttEngine` contract.

The research recommendation (spike-1.4-plan.md, findings section): **Parakeet TDT 0.6B v3 int8** (~640 MB, 25 European languages, auto-detect, word-level timestamps, punctuation, hotword-capable transducer, FLEURS WER de 5.04 / es 3.45 / fr 5.15 / it 3.00 / nl 7.48 / pl 7.31 / en 4.85, CC-BY-4.0) via sherpa-onnx's documented **simulated-streaming** pattern (offline recognizer + Silero VAD + periodic interim re-decodes + final on end-of-speech — the `sherpa-onnx-vad-microphone-simulated-streaming-asr` mode, with an official Parakeet v3 build in the release set) — reachable from the already-declared `sherpa_onnx: ^1.10.31` dependency through the `OfflineRecognizer` + `VoiceActivityDetector` Dart API, no new dependency. No true-streaming pretrained model exists for the gap languages in the streaming zoo, so simulated streaming is what makes the streaming-caption premise hold for the multilingual engine.

## Scope

In scope:

- A new `SttEngine` implementation (chunk-decode / simulated-streaming mode) in `zip_core`: Silero VAD segmentation of the existing audio pipeline → interim re-decodes of the in-progress segment on a cadence (interim `SttResult`, the caption pipeline's trailing-interim line) → final decode at VAD end-of-speech (final `SttResult`, best-effort commit on final-decode failure); `stopListening` flushes the in-flight segment.
- The offline model family in the existing model catalog (`SherpaModelManager` / `SherpaModelCatalogNotifier`): Parakeet TDT 0.6B v3 int8 + `silero_vad.onnx` (~2 MB); the existing 100 MB large-download confirmation gate covers the 640 MB model by construction.
- Catalog entry shape extended to represent a multilingual model (one download, many locales) — the existing `primaryLocaleId`-only shape cannot.
- Engine registration and the engine-picker surface in `zip_captions` (one new row; reuses the shipped catalog/download UI).
- Test seams mirroring Unit 2's `OnlineRecognizerAdapter` precedent (an offline-recognizer adapter seam, hand-written fakes, redaction audit test per SECURITY-03).
- NFR: per-sentence latency, decode RTF and thread count, peak RAM, download-size and confirmation-gate behavior.

Out of scope (each is a deliberate deferral, not an omission):

- **Whistle** (`WhistleSttEngine`, FFI/WASM) — separate unit, gated on Spike 1.4's Q1/Q5/Q6 results.
- **Word timestamps on `SttResult`** — ADR-005 boundary; a follow-up decision, not this unit. The caption pipeline does not consume word timestamps today.
- **Hotwords/keyword biasing** — Parakeet is a transducer (hotword-capable) but the UI surface and domain lists are a separate unit; recorded here so the architecture keeps it possible (config seam, no lockout).
- **Web** — Fallback tier; no offline STT on web in this unit (WASM option remains Spike 1.4's Q6).
- **Other models** (Omnilingual 300M, Whisper ONNX, Moonshine v2) — fallback candidates from the findings; the catalog architecture must make adding them later cheap, but none ships in this unit. Omnilingual is additionally blocked on license verification (project has premium features).
- **The streaming engine** — `SherpaOnnxSttEngine` and its adapter are consumed as shipped and must not change.

## Binding inputs

| Input | Location | Status |
|---|---|---|
| Spike 1.4 plan + Whistle research + sherpa-onnx language-coverage findings | `aidlc-docs/construction/spikes/spike-1.4-plan.md` | DRAFT — pending approval and execution |
| ADR-005 (pluggable STT engines, `SttEngine`/`SttResult` contracts) | `docs/02-architecture-decisions.md` | boundary — no interface change in this unit |
| SECURITY-03 (no transcript text in logs/telemetry) | `docs/04-technical-specification.md` §8 | blocking constraint |
| Phase 1 < 1 s perceived-latency exit criterion | `docs/03-roadmap.md` | NFR-stage target for sentence mode |
| Unit 2 shipped: `SttEngineRegistry`, `SherpaOnnxSttEngine` + `OnlineRecognizerAdapter` seam, `SherpaModelManager`/catalog notifier, 100 MB confirmation threshold | `packages/zip_core/lib/src/{stt,services/catalog,providers}/` | verified by reading the code 2026-10-20 |
| `sherpa_onnx: ^1.10.31` | `packages/zip_core/pubspec.yaml:52` | already approved and declared — no new dependency |

**Unverified-vendor-data flag.** The Parakeet figures above (sizes, FLEURS WER, RK3588 RTF) are vendor-published and not yet measured on a project target device. Spike 1.4's Q7 exists specifically to measure the recommended path (Parakeet v3, VAD-chunked, on the Pi 5 / reference machine). Stages may proceed on the flagged numbers (precedent: Unit 5 proceeded on Spike 2.1's interim values); **Code Generation Part 2 is hard-gated on the Spike 1.4 report** (see Dependencies).

## Stage sequence

Per AI-DLC Construction Phase and the established per-unit pattern (Units 2–8):

| # | Stage | Plan (approval gate) | Artifacts on approval |
|---|---|---|---|
| 1 | Functional Design | `aidlc-docs/construction/plans/on-device-multilingual-stt-functional-design-plan.md` (written; 14/14 answers recorded 2026-10-20) | `construction/on-device-multilingual-stt/functional-design/{business-logic-model,business-rules,domain-entities,frontend-components,handoff-summary}.md` — **written 2026-10-21, committed; the FD approval gate has NOT been passed — first action at pickup** |
| 2 | NFR Requirements | `.../plans/on-device-multilingual-stt-nfr-requirements-plan.md` (written after Stage 1 approval) | `.../nfr-requirements/{nfr-requirements,tech-stack-decisions}.md` |
| 3 | NFR Design | `.../plans/on-device-multilingual-stt-nfr-design-plan.md` (after Stage 2) | `.../nfr-design/{logical-components,nfr-design-patterns}.md` |
| 4 | Infrastructure Design | `.../plans/on-device-multilingual-stt-infrastructure-design-plan.md` (after Stage 3) | `.../infrastructure-design/infrastructure-design.md` — model distribution: where the 640 MB download is served from (HuggingFace release vs. self-hosted mirror), catalog JSON hosting, `silero_vad.onnx` sourcing |
| 5 | Code Generation Part 1 (Planning) | `.../plans/on-device-multilingual-stt-code-generation-plan.md` (after Stage 4; strict transcription of the approved design, zero open questions) | the plan file itself (Unit 6 precedent: the Part 1 plan file is the artifact) |
| 6 | Code Generation Part 2 (Generation) | — (executes the approved plan, TDD-first) | `.../code/unit*-summary.md`, PR against `develop` |

Build and Test is a Phase-level stage (runs when the phase's units complete), not a per-unit one. Documentation Refinement follows the PR (propagates any design changes into `docs/` with per-change approval — this is where the roadmap/unit-numbering edit from OQ-1 lands).

## Dependencies and gates

1. **Spike 1.4 execution + report** — hard gate for Code Generation Part 2 only. Q7 (Parakeet viability on target) and Q3 (same-device A/B) determine whether this unit proceeds as specified, as desced, or in favor of the Whistle unit. Q1/Q2/Q5/Q6 determine the Whistle unit (out of scope here).
2. **The concurrent unattended run must be complete and merged to `develop`** — as of this parking (2026-10-21) the other session's overnight run is **Unit 8.1: Pop-out Live Captions (S-21)**, working in this same checkout on `feature/popout-live-captions` (local only, never pushed; it opens a new PR at the end of its run). It is mid-run (FD/NFR-R/NFR-D approved and committed at head `72c7cd8`; Infrastructure Design and Code Generation not started). Unit 8 (External Display, PR #37) is already merged to `develop` — the earlier "wait for PR #37" gate is satisfied. This unit's worktree is created from `develop` **after the Unit 8.1 pop-out run's PR merges**, and the worktree is rebased onto that merge before any Code Generation Part 2 work. (Planning stages are docs-only and unaffected by the concurrent run.)
3. **Spike 1.4 and this unit run in separate worktrees/branches**; the only shared surface is `develop`, and only via merged PRs (one unit per worktree, one worktree per PR).

## Coordination with the concurrent session

Another session is actively building (as of this parking: the **Unit 8.1 pop-out overnight run** — run config in `.agent/overnight-pipeline.md`, branch `feature/popout-live-captions` in this checkout, local only, opens its own PR at the end of the run). Collision-avoidance rules for all work under this plan:

- **Create new files only** under `aidlc-docs/construction/on-device-multilingual-stt/` and `aidlc-docs/construction/plans/on-device-multilingual-stt-*`. No other file in the repository is edited by this unit's planning work.
- **Do not touch**: `aidlc-docs/aidlc-state.md`, `aidlc-docs/audit.md`, `aidlc-docs/overnight-ledger.md`, `.agent/`, `docs/`, `stories/`, `aidlc-docs/inception/**`, any existing `aidlc-docs/construction/**` file or directory, `packages/**`, or the other session's branch/PR. The Unit 8 run owns `aidlc-state.md` and `audit.md` entries for its stages; this unit's entries are added at the normal approval points in its own session, after the Unit 8 run has written its own (or by a human, if ordering collides — flag, don't force).
- The state-file/roadmap edits this unit eventually needs (unit number, story-map row, `docs/` roadmap line) happen **only** during Documentation Refinement with per-change approval — never as a side effect.

## Open questions — RESOLVED 2026-10-20 (all option A)

- **OQ-1 — Roadmap placement and unit number. RESOLVED: A.** Next free unit number in the Phase 2 cycle (after Unit 8, the pending pop-out unit, and Unit 9's live-verification work; the human assigns the exact number at the unit's approval). Targets v2.0 alongside Phase 8 (translation); does NOT block the v2.0 RC. The phase/story-map/roadmap doc edits happen during this unit's Documentation Refinement with per-change approval.
- **OQ-2 — Stage gating policy. RESOLVED: A.** Stages 1–3 proceed now on vendor-flagged data (the FD's 14 answers are collected; NFR Requirements and NFR Design draft with values explicitly flagged "pending Spike 1.4 verification", per the Unit 5 / Spike 2.1 interim-values precedent; values are revised in place when the spike report lands, through the normal revision + review path). Code Generation Part 1 and Part 2 are hard-gated on the Spike 1.4 report so the step plan is transcribed once, from verified numbers.
- **OQ-3 — First models. RESOLVED: A.** Parakeet TDT 0.6B v3 int8 + `silero_vad.onnx` are the only two catalog rows in v1. The catalog architecture (Q6's `kind` discriminator + `localeIds`) makes adding a second ASR model (e.g. Omnilingual 300M, once its license is verified) a row addition, not a redesign.

**Spike 1.4 scope note (2026-10-20).** Spike 1.4's Q7 is expanded from "per-utterance latency" to also measure **interim update latency at the re-decode cadence** (interim results are now part of the design, not an afterthought) — the spike plan's Q7 row and methodology are updated accordingly.

## Verification gates (standing)

`melos run analyze` (zero warnings/infos, `--fatal-infos`) and `melos run test` across all packages, per `AGENTS.md` and the pre-push hook. Package-level gates in Code Generation: `packages/zip_core` (the changed package) plus `zip_captions`/`zip_broadcast` as regression guards (no changes expected in the latter).

## Parking and Pickup (recorded 2026-10-21, human decision)

**Why parked.** The other session's Unit 8.1 pop-out overnight run owns this checkout
(branch `feature/popout-live-captions`, local only). This unit is parked until that
run completes and its PR merges to `develop`.

**State at parking.**
- All planning docs for this unit are committed on `feature/popout-live-captions`
  (commits `a8fad31`…`218eba7` plus the FD-artifact commit that follows this edit)
  and will land on `develop` via the pop-out run's PR — no separate docs PR needed,
  and the pickup worktree (branched from `develop`) will contain the full corpus.
- Functional Design: 14/14 answers recorded; the four FD artifacts + handoff summary
  are **written but not approved**. The FD approval gate is the first open gate.
- Spike 1.4: plan DRAFT (Q7 expanded for interim-cadence measurement); not approved,
  not executed. Its report hard-gates Code Generation Parts 1+2 and feeds the NFR
  param values (OQ-2: NFR may draft on flagged vendor data first).
- Nothing downstream (NFR Requirements/Design, Infrastructure Design, Code
  Generation) has started. No production code exists for this unit.
- This unit was not registered in `aidlc-state.md` (owned by the running session);
  the pickup session registers it at its first approval point.

**Pickup procedure (next session).**
1. Confirm the pop-out run finished: its PR merged to `develop` (and PR #40
   `fix/zip-broadcast-runner-callbacks` merged too, if not already — it is not on
   `develop` as of this parking). Read `.agent/overnight-pipeline.md` for how the
   run concluded, and `aidlc-docs/audit.md` for its stage entries.
2. `git submodule update --remote ai-dlc` (commit the pointer if it moved), per AGENTS.md.
3. Create the worktree from the updated `develop`:
   `git worktree add ../zip-captions-multilingual-stt -b feature/multilingual-on-device-stt`
   (branch name is a proposal; unit number per OQ-1 = next free number, assigned by the human at approval).
4. In the worktree, read in order: this unit's `README.md` (the pickup note),
   `execution-plan.md`, `functional-design/handoff-summary.md`, then the four FD
   artifacts. The handoff summary is the compressed source of binding decisions.
5. **Gate 1 (human):** approve or revise the four FD artifacts (FD review gate).
6. **Gate 2 (human):** approve the Spike 1.4 plan, then execute the spike
   (device work per its methodology; the report feeds NFR values).
7. Draft NFR Requirements and NFR Design (flagged data allowed per OQ-2; revise in
   place when the spike report lands), then Infrastructure Design (model
   distribution decisions), then Code Generation Part 1 (strict transcription, zero
   open questions) and Part 2 (TDD-first, in the worktree).
8. Open the PR targeting `develop` after Documentation Refinement; clean up the
   worktree after merge.
