# Frontend Components — On-Device Multilingual STT

**Scope reality (verified in this checkout, 2026-10-20):** neither app has a
shipped engine-picker or model-catalog UI surface yet —
`packages/zip_captions/lib/main.dart:57` registers only `FakeSttEngine`, and no
`lib/` file in either app references the model catalog. This unit is therefore
`zip_core`-centric and contributes **no new screens and no new widgets**. It
contributes the row *contracts*, the catalog *data rows*, the ARB strings, and
the registration wiring point, so the picker/catalog surfaces (when the app
wiring unit lands) render this engine with zero extra design work.

## 1. Engine picker row (contract for the picker surface)

One row, appearing when the engine is registered (Rule 1 — both catalog
entries downloaded; no other gate):

| Aspect | Contract |
|---|---|
| Label | `engine.displayName` = "Multilingual — on-device" (ARB) |
| Availability | The engine's `isAvailable()` (Rule 1 + init success). Unregistered → row absent or shown in the picker's shipped unavailable state (whatever the picker surface ships — this unit does not invent a third state). |
| Locale line | "Language: auto-detected" (ARB). Not a selector: there is no per-language choice in v1 (Rule 5). If a forced-language setting lands in a follow-up unit, this row's locale line becomes the setting. |
| Selection behavior | Identical to the shipped engine row: selecting it sets the persisted engine preference, `sttEngineProvider` resolves it at next start, and the recording flow is untouched (Rule 10). |
| Download prompt | If the picker's shipped pattern surfaces "download required" for unavailable engines, the prompt points at the catalog rows below (one row for the ASR model — the ~640 MB download with its confirmation — and one for the VAD model). |

## 2. Model catalog rows (data, rendered by the catalog surface)

Two entries added to the catalog data (Infrastructure Design stage finalizes
hosting/URLs/checksums); both ride the **shipped** catalog + download machinery
unchanged (Rule 9, Q13):

| Row | `displayName` | `localeIds` | `kind` | `engineId` | `downloadSizeBytes` | Confirmation gate |
|---|---|---|---|---|---|---|
| ASR model | "Multilingual (Parakeet TDT 0.6B v3)" (ARB) | all 25 (Rule 11) | `offlineTransducer` | the new engineId | ≈ 640 MB (measured at ID stage) | **Yes** — trips the shipped 100 MB threshold; the existing size-confirmation dialog is the only UX |
| VAD model | "Voice activity model (Silero VAD)" (ARB) | `[]` | `vad` | the new engineId | ≈ 2 MB | No |

Deletion of **either** row unregisters the engine (Rule 1) and, if it is
active, the persisted engine preference falls back per the picker surface's
shipped fallback behavior. The catalog row renders one row per download with
its locale list (no per-locale rows — Rule 11).

## 3. Registration wiring (Code Generation scope)

`main.dart` (both apps where this engine is offered) registers the engine
alongside the other engines, resolving its two catalog entries through
`SherpaModelManager`. The current checkout registers only `FakeSttEngine`;
Code Generation mirrors **whatever engine-registration pattern is in place at
CG time** (the streaming engine's own registration is the reference — if it
is not yet wired either, the registration wiring for both is a shared concern
noted in the CG plan, not silently expanded into this unit).

## 4. New ARB strings (English source only; v1 translations imported later)

| Key (proposal) | English | Used by |
|---|---|---|
| `engineMultilingualOnDevice` | Multilingual — on-device | engine.displayName |
| `languageAutoDetected` | Language: auto-detected | picker locale line |
| `modelParakeetMultilingual` | Multilingual (Parakeet TDT 0.6B v3) | catalog row |
| `modelSileroVad` | Voice activity model (Silero VAD) | catalog row |

No other user-facing copy is added: the download, progress, cancellation,
confirmation, and deletion copy is the shipped catalog machinery's.

## 5. What is explicitly not UI work in this unit

- No new screens, dialogs, or widgets in `zip_captions`/`zip_broadcast`.
- No engine-picker or catalog surface implementation (app wiring units).
- No per-language model selector (Rule 5, Q5 — auto-detect only in v1).
- Web is unaffected: the engine's `requiresDownload`/platform behavior keeps
  it out of web's engine set per the shipped selection rules (Fallback tier —
  no offline STT on web in this unit).
