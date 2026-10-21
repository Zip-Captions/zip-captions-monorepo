# Execution Plan: On-Device Multilingual STT

**Date**: 2026-10-20
**Status**: DRAFT — pending human approval. Stage plans execute sequentially; each stage requires explicit approval before its artifacts are generated (AI-DLC Construction Phase, `aidlc-project-rules/` + `.aidlc-rule-details/construction/`).
**Unit number**: unassigned — see Open Question OQ-1 (roadmap placement is a human decision; this plan deliberately does not edit `docs/` or the inception unit-of-work artifacts).

**Origin**: the research recorded in `aidlc-docs/construction/spikes/spike-1.4-plan.md` (Whistle vs. Sherpa-ONNX spike plan, including the "Sherpa-ONNX Language Coverage — Findings" section added 2026-10-20 from the indexed sherpa-onnx and cactus-needle docs).
**Stories**: extends S-01 (STT Engine Interface and Registry) and S-02 (Platform-Native STT Implementation) — `aidlc-docs/inception/user-stories/stories.md`. Personas: low-spec always-on captioning machines (S2.5 remote machine), the Québec/French and other non-English speaker personas (`docs/01-user-personas.md`).
**Package**: `zip_core` (engine, catalog, models); `zip_captions` (settings/engine-picker surface only).
**Branch**: `feature/on-device-multilingual-stt` — created in an isolated worktree (`git worktree add ../zip-captions-on-device-multilingual-stt -b feature/on-device-multilingual-stt`) after this plan and the Functional Design plan are approved. One unit per worktree, one worktree per PR (AGENTS.md).

---

## Purpose

Phase 1 shipped on-device STT for the streaming model family (English-centric; the streaming pretrained zoo has no de/es/it/nl/pl models). The v1 UI is 11 languages. This unit adds a **multilingual on-device engine** so a user on any supported platform can caption in de/es/it/nl/pl (and the other 19 European languages the model covers) fully offline, without new infrastructure and without touching the ADR-005 `SttEngine` contract.

The research recommendation (spike-1.4-plan.md, findings section): **Parakeet TDT 0.6B v3 int8** (~640 MB, 25 European languages, auto-detect, word-level timestamps, punctuation, hotword-capable transducer, FLEURS WER de 5.04 / es 3.45 / fr 5.15 / it 3.00 / nl 7.48 / pl 7.31 / en 4.85, CC-BY-4.0) via sherpa-onnx's **offline recognizer + Silero VAD sentence-chunking** pattern — reachable from the already-declared `sherpa_onnx: ^1.10.31` dependency through the `OfflineRecognizer` + `VoiceActivityDetector` Dart API, no new dependency.

## Scope

In scope:

- A new `SttEngine` implementation (sentence mode) in `zip_core`: Silero VAD segmentation of the existing audio pipeline → offline decode of the completed segment → `SttResult(isFinal: true)` per sentence; `stopListening` flushes the in-flight segment.
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
| 1 | Functional Design | `aidlc-docs/construction/plans/on-device-multilingual-stt-functional-design-plan.md` (written, pending approval) | `construction/on-device-multilingual-stt/functional-design/{business-logic-model,business-rules,domain-entities,frontend-components}.md` |
| 2 | NFR Requirements | `.../plans/on-device-multilingual-stt-nfr-requirements-plan.md` (written after Stage 1 approval) | `.../nfr-requirements/{nfr-requirements,tech-stack-decisions}.md` |
| 3 | NFR Design | `.../plans/on-device-multilingual-stt-nfr-design-plan.md` (after Stage 2) | `.../nfr-design/{logical-components,nfr-design-patterns}.md` |
| 4 | Infrastructure Design | `.../plans/on-device-multilingual-stt-infrastructure-design-plan.md` (after Stage 3) | `.../infrastructure-design/infrastructure-design.md` — model distribution: where the 640 MB download is served from (HuggingFace release vs. self-hosted mirror), catalog JSON hosting, `silero_vad.onnx` sourcing |
| 5 | Code Generation Part 1 (Planning) | `.../plans/on-device-multilingual-stt-code-generation-plan.md` (after Stage 4; strict transcription of the approved design, zero open questions) | the plan file itself (Unit 6 precedent: the Part 1 plan file is the artifact) |
| 6 | Code Generation Part 2 (Generation) | — (executes the approved plan, TDD-first) | `.../code/unit*-summary.md`, PR against `develop` |

Build and Test is a Phase-level stage (runs when the phase's units complete), not a per-unit one. Documentation Refinement follows the PR (propagates any design changes into `docs/` with per-change approval — this is where the roadmap/unit-numbering edit from OQ-1 lands).

## Dependencies and gates

1. **Spike 1.4 execution + report** — hard gate for Code Generation Part 2 only. Q7 (Parakeet viability on target) and Q3 (same-device A/B) determine whether this unit proceeds as specified, as desced, or in favor of the Whistle unit. Q1/Q2/Q5/Q6 determine the Whistle unit (out of scope here).
2. **Unit 8 (External Display) PR #37 merged** — the other session's unattended run (`.agent/overnight-pipeline.md`) is in flight on `feature/external-display` and its scope fence forbids `zip_core`/`zip_captions` changes; conversely this unit touches exactly those packages. This unit's worktree is created from `develop` **after PR #37 merges**, and the worktree is rebased onto the merge before any Code Generation Part 2 work. (Planning stages are docs-only and unaffected.)
3. **Spike 1.4 and this unit run in separate worktrees/branches**; the only shared surface is `develop`, and only via merged PRs (one unit per worktree, one worktree per PR).

## Coordination with the concurrent session

Another session is actively building (Unit 8 overnight run; branch `feature/external-display`, PR #37). Collision-avoidance rules for all work under this plan:

- **Create new files only** under `aidlc-docs/construction/on-device-multilingual-stt/` and `aidlc-docs/construction/plans/on-device-multilingual-stt-*`. No other file in the repository is edited by this unit's planning work.
- **Do not touch**: `aidlc-docs/aidlc-state.md`, `aidlc-docs/audit.md`, `aidlc-docs/overnight-ledger.md`, `.agent/`, `docs/`, `stories/`, `aidlc-docs/inception/**`, any existing `aidlc-docs/construction/**` file or directory, `packages/**`, or the other session's branch/PR. The Unit 8 run owns `aidlc-state.md` and `audit.md` entries for its stages; this unit's entries are added at the normal approval points in its own session, after the Unit 8 run has written its own (or by a human, if ordering collides — flag, don't force).
- The state-file/roadmap edits this unit eventually needs (unit number, story-map row, `docs/` roadmap line) happen **only** during Documentation Refinement with per-change approval — never as a side effect.

## Open questions (human decisions, before Stage 1 approval is final)

- **OQ-1 — Roadmap placement and unit number.** Where does this unit sit: a late Phase 2 unit, a new phase, or pre-v2.0-RC (alongside the pop-out unit and Unit 9's live-verification work)? Determines the inception artifact edits (deferred to Documentation Refinement) and the PR sequencing relative to the pop-out unit.
- **OQ-2 — Stage gating policy.** Proceed with Stages 1–5 on vendor-flagged data now (recommended; Unit 5/Spike 2.1 precedent), with Code Generation Part 2 gated on the Spike 1.4 report — or hold all stages until the spike report exists?
- **OQ-3 — First model.** Parakeet TDT 0.6B v3 int8 as the sole initial catalog entry (recommended; best WER, permissive license, hotword-capable) vs. also shipping a smaller fallback model. The catalog architecture is model-agnostic either way.

## Verification gates (standing)

`melos run analyze` (zero warnings/infos, `--fatal-infos`) and `melos run test` across all packages, per `AGENTS.md` and the pre-push hook. Package-level gates in Code Generation: `packages/zip_core` (the changed package) plus `zip_captions`/`zip_broadcast` as regression guards (no changes expected in the latter).
