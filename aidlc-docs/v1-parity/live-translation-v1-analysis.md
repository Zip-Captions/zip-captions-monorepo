# V1 Live Translation Analysis

**Date**: 2026-10-19
**V1 baseline**: `78637386a79db6ac965ad12952b8c4e4acde3b80` (`release/v0.5.0`, tag `v0.5.0-rc.5`)
**V1 version**: v0.5.0-rc.5
**Purpose**: V1 implementation description to inform V2 feature parity.

---

## Executive Summary

V1 live translation runs entirely inside the browser using Chrome's built-in on-device **Translator API** (`self.Translator`) and **LanguageDetector API**. No cloud translation service is contacted; audio still goes to the cloud for speech recognition, but translation never leaves the device. It is production quality and substantially more elaborate than a wrapper: LRU-cached per-pair translator instances, a 150 ms latest-wins debounce for the interim line, generation-counted session objects that discard stale in-flight results, three-times retry with permanent give-up, strict versus lenient failure handling, and a dual-source model where a viewer prefers the broadcaster's translation over translating locally.

The single most important fact for a V2 planner: **the V1 implementation is browser-API-bound.** `self.Translator` exists only in Chrome/Edge desktop. V2's ADR-013 already specifies a `TranslationEngine` abstraction with Apple Translation, ML Kit, NLLB, and cloud backends, and Phase 8 (v2.1) is the scheduled home for it. V1 supplies the pipeline design, the UX model, and the wire protocol for broadcaster-provided translations; it supplies none of the cross-platform engine implementations.

---

## User-Facing Behaviour

- Translation is off, split, translated-only, or original-only (`TranslationDisplayMode`).
- Target language picker lists 17 languages (`AvailableTranslationLanguages`), French first and the default target, then English, Spanish, German, Italian, Portuguese, Ukrainian, Arabic, Chinese, Japanese, Korean, Hindi, Vietnamese, Russian, Dutch, Polish, Turkish.
- Split mode shows two panes; orientation is stacked or side by side, pane order is original-first or translated-first. Pending translations show a pulsing ellipsis placeholder in the correct slot, never the source text.
- A model that is not yet downloaded shows a download button and progress percentage; the download must run inside a user gesture, so it cannot start automatically.
- Spoken and translation languages can be swapped from settings, the caption view, and the sidebar. Swapping restores the last dialect used per language.
- The interim (live) line is translated separately from finalized segments and updates latest-wins.
- PiP shows original, translated, or split, independently of the in-window mode.
- OBS feed carries original or translated captions.
- Broadcasters send both original and translated segments so viewers get a translation without needing translation support locally.
- Viewers with their own capable device can pick a language the broadcaster does not offer, and their device translates it.
- **No translation-accuracy disclaimer is shown anywhere.** `grep` for `disclaimer|inaccurate` across `packages/client/src/app` returns nothing. This diverges from the V2 requirement (ADR-013, non-dismissible "Source language: [detected]. Translation may be inaccurate.").

---

## Implementation

### Location

| Package | File | Role |
|---|---|---|
| `packages/client` | `src/app/services/translator/translator-api.adapter.ts` | 54 lines. Thin wrapper over `self.Translator` so the global can be mocked. |
| `packages/client` | `src/app/services/translator/chrome-translator.service.ts` | 565 lines. The engine: availability, download, LRU cache, retry, live channel, segment cache. |
| `packages/client` | `src/app/services/translator/caption-translation.service.ts` | 164 lines. Pipeline tying recognition output to translation and to the display signals. |
| `packages/client` | `src/app/services/translator/segment-translation-session.ts` | 117 lines. Generation-counted session that owns translations for one target. |
| `packages/client` | `src/app/services/translator/segment-translations.ts` | 65 lines. Pure planning/merging helpers. |
| `packages/client` | `src/app/services/translator/language-detector.adapter.ts` | 53 lines. Wrapper over `self.LanguageDetector`. |
| `packages/client` | `src/app/services/translator/viewer-translation.ts` | 47 lines. Broadcaster-vs-local resolution and viewer language picker. |
| `packages/client` | `src/app/services/translator/caption-lines.ts`, `caption-view.ts`, `text-direction.ts` | Rendering helpers: line slots, which view to show, RTL detection. |
| `packages/client` | `src/app/modules/peer/models/broadcast-payload.ts` | Wire format carrying `translations[]` (offered languages) and `translated[]` segments. |
| `packages/client` | `src/app/components/translation-reset-notice/` | UI notice when translation state resets. |
| `packages/client` | `src/app/modules/settings/components/translation-settings/` | Settings form. |

Total translator service surface: roughly 2,660 lines including specs.

### Mechanism

**Backend.** Chrome/Edge desktop only.

```ts
interface TranslatorStatic {
  availability(options: { sourceLanguage: string; targetLanguage: string }): Promise<TranslatorAvailability>;
  create(options: TranslatorCreateOptions): Promise<BrowserTranslator>;
}
interface BrowserTranslator {
  translate(text: string): Promise<string>;
  destroy?(): void;
}
```

Support is explicitly gated off mobile:

```ts
public unsupportedReason(): TranslationUnsupportedReason | undefined {
  if (this.platform.ANDROID || this.platform.IOS) return 'mobile';
  if (!this.translatorApi.isAvailable()) return 'browser';
  return undefined;
}
```

The adapter comments record Chrome 138+ and Edge 148+.

**Availability and model download.** `availability()` returns `available` / `downloadable` / `downloading` / `unavailable`, mapped to `ready` / `downloadable` / `downloading` / `unavailable` / `error`. A download only starts when `userInitiated` is true, because the browser requires a user gesture; a background request for a downloadable model returns `null` and sets status `downloadable` rather than throwing `NotAllowedError`. Progress is read from a `downloadprogress` event on the monitor `EventTarget`, normalized to a 0-100 integer (the code tolerates both 0..1 fractions and byte counts).

**Translator instance cache.** `Map<string, BrowserTranslator>` keyed `"$source->$target"`, LRU by re-insertion, capped at `MAX_TRANSLATORS = 4`, oldest destroyed on overflow. Pending creations are deduplicated per pair through `pendingInits`, with the deliberate rule that a user-initiated request must not join a background one (which would skip the needed download). The pending entry is registered before the first `await` so concurrent callers share one creation.

**Segment cache.** `Map<string, string>` keyed `"$s->$t:$text"`, capped at `MAX_CACHED_SEGMENTS = 500`, cleared per recognition session by `clearSessionCache()`. Whole-session clear is deliberate: Chrome's translator was observed to enter a permanently broken state (`UnknownError`) and stopping/restarting the session fixed it, so instances are destroyed at session end even though the downloaded models persist in the browser.

**Failure semantics.** Two paths, and the distinction matters:
- `translate()` is lenient: on failure it returns the source text, for callers that are fine with fallback.
- `translateSegmentsStrict()` returns `null` per segment on any failure (unsupported pair, no translator, model still downloading, error). Callers use this to distinguish "translated" from "failed" before sending anything to viewers or OBS.
- `onTranslateFailure` drops the broken instance so the next attempt rebuilds, sets `translationFailing` for UI, and logs exactly one `console.warn` per run of failures rather than one per segment.

**Live line channel.** Each consumer creates its own channel; sharing one would translate every line once per subscriber and mix results.

```ts
switchMap((request) => request ? timer(150).pipe(map(() => request)) : of(null)),
distinctUntilChanged((prev, curr) => !!prev && !!curr && !curr.retry
  && prev.text === curr.text && prev.sourceLang === curr.sourceLang && prev.targetLang === curr.targetLang),
```

So: 150 ms latest-wins debounce, `null` is a cancel that passes through immediately to invalidate in-flight work, and the output is strict (empty string rather than source text on failure).

**Session object.** `SegmentTranslationSession` owns `Map<segmentId, {lang, text}>` plus a `previous` map from the prior target so a language change does not blank the pane while new translations land. A `generation` counter incremented on every reset makes in-flight results for an older state get discarded. Per-segment attempts are capped at `MAX_ATTEMPTS = 3`, after which the segment is skipped entirely so recognition updates do not retry forever. Visible segments (the newest `renderHistory + 5`) are translated first.

**Per-segment language.** The source language of a translation is the segment's own `lang`, not the global setting. Segments are grouped by source language (`planTranslations`), and a segment already in the target language is marked `passThrough` and resolved immediately. This is what makes bilingual locales (`fr-CA`, `es-US`, `ar-*`) work: Azure tags each segment, panes show the pair's two languages rather than "spoken" and "translated".

**Language detection.** `LanguageDetectorAdapter` wraps Chrome's `LanguageDetector` (Chrome 138+), restricted to the bilingual pair's two languages. It is used to tag segments in bilingual locales. Per FR-AZ-3 this was parked to Release 2 and is not active in v0.5.0 for the single-locale path.

**Broadcaster-to-viewer translation.** The broadcaster sends `translations: string[]` (languages it translates into) and `translated: WireSegment[]` with matching segment IDs, plus `translatedLive`. `resolveViewerTranslation(target, offered, canTranslateLocally)` returns `'broadcaster' | 'local' | 'none'`, preferring the broadcaster's translation so the same text is never translated twice. A translation without its source line is never sent alone.

### Platform Coverage

| Platform | Supported | Mechanism | Notes |
|---|---|---|---|
| Chrome desktop (138+) | Yes | `self.Translator` | Full support; model downloaded per language pair. |
| Edge desktop (148+) | Yes | `self.Translator` | Same API. |
| Chrome Android/iOS | No | — | Explicitly returns `'mobile'`; the API is desktop-only. |
| Safari / Firefox | No | — | Returns `'browser'`. |
| Native macOS/Windows/Linux | Not applicable | — | V1 is a web app. |

---

## Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| `@angular/core` | Angular 16 | Signals, DI, `toObservable`/`toSignal`. |
| `@ngrx/store` | Angular 16 line | Settings state, translation actions and effects. |
| `rxjs` | Angular 16 line | `switchMap`, `timer`, `distinctUntilChanged`, `Subject`. |
| Browser Translator API | Chrome 138+, Edge 148+ | The engine. |
| Browser LanguageDetector API | Chrome 138+ | Per-segment language in bilingual locales. |

No translation package, no cloud SDK.

---

## Data Flow

1. `RecognitionService` emits finalized `CaptionSegment[]` and a live interim string.
2. `CaptionTranslationService` computes `segments` and `liveText` from recognition, gated on an active recognition ID.
3. On segment change: `session.update(segments, target, retranslateAll, visibleCount)`.
4. `planTranslations` groups untranslated or language-changed segments by source language, marks pass-through groups.
5. `SegmentTranslationSession` calls `translateSegmentsStrict` per group, translating visible segments first.
6. `ChromeTranslatorService` resolves an LRU-cached or newly created `BrowserTranslator`, checks the segment cache first.
7. Results merge back by segment ID into the session's map; the generation counter discards results from a reset state.
8. Rendering reads `translations` (a signal) and builds one line slot per segment, pending slots showing a placeholder.
9. On live line change: `liveChannel.queue(text, source, target)`; 150 ms later the latest text is translated; `output$` writes `translatedLive`.
10. Broadcast: `CaptionTranslationService` output feeds `buildSegmentPayload`, which includes `translations` (offered) and `translated` (only segments that really translated).

---

## Constraints and Limitations

- **Browser-only and desktop-only.** No mobile, no non-Chromium. This is a hard platform constraint, not a configuration.
- **No disclaimer UI.** Requirement ADR-013 in V2 demands a persistent non-dismissible accuracy notice; V1 has none.
- **Whole-utterance, not streaming tokens.** Translation is per finalized segment or per debounced live line. There is no sub-segment streaming.
- **Model download needs a user gesture.** A first-time pair cannot translate until the user clicks download.
- **Instances can go permanently bad** and must be destroyed; a documented Chrome `UnknownError` behaviour, mitigated by session-end clearing.
- **Hard caps.** 4 cached translator instances, 500 cached segments, 3 retry attempts per segment.
- **Translation settings do not sync to the server.** The server's `UiSettings` schema has no `translation` field at all, so mode, target, and layout never sync between devices. `pipContent` and `obsFeed` are intentionally device-local (`DeviceSpecificTranslationKeys`).
- **Per-language windows (FR-W2) are backlog**, not implemented.
- **Bilingual per-segment detection (FR-AZ-3) is parked** to Release 2 with conversation mode; the default French-first target ordering (`DefaultTranslationTarget = 'fr'`) is a recent change.
- **OBS output is CEA-608**, which cannot represent Arabic, CJK, Hindi, Russian, or Ukrainian.
- **No cloud translation tier** exists in V1 at all.

---

## Test Coverage

Extensive. `chrome-translator.service.spec.ts` is 553 lines; `caption-translation.service.spec.ts` 233; `segment-translation-session.spec.ts` 212; plus specs for segment translation, language service, viewer translation, caption lines, caption view, and the translation settings component. A dedicated `translation-test-ids.spec.ts` guards test-id stability across the module.

Covered: availability mapping, download gating on user gesture, LRU eviction, pending-init deduplication, strict versus lenient failure, retry cap, generation discarding, live-channel debounce, pass-through, per-segment language grouping, and viewer broadcaster-vs-local resolution.

Not covered by unit tests: full end-to-end translation against a real Chrome model, and the accuracy disclaimer (which does not exist).

---

## Observability and Privacy

- Translation **never leaves the device**: `self.Translator` is on-device. `requirements.md` states this explicitly and the code has no network path.
- Logging is `console.warn`/`console.error` with fixed strings plus the error object. One aggregated warning per failure run, deliberately not one per segment.
- **`onTranslateFailure` logs the error object**, which for a browser API failure is a DOMException/Error. No caption text is passed to the logger.
- No analytics, no telemetry, no crash reporting integration in this code path.
- The requirement that the UI must not claim a session is fully on-device while Azure recognition is active (NFR-1) is a server-recognition concern, not translation.

---

## Implications for V2 Parity

- **The engine layer must be replaced, not ported.** ADR-013 already defines `TranslationEngine` with `isAvailable`, `getSupportedPairs`, `isLanguagePairAvailable`, `downloadLanguagePack`, `translate`, `detectLanguage`, and `dispose`. V1's `ChromeTranslatorService` maps to a `ChromeTranslatorEngine` web implementation and is the reference for the interface's real-world ergonomics: the `downloadable` / `downloading` / `ready` / `error` state machine and the user-gesture download requirement should shape the interface rather than be rediscovered per backend.
- **The pipeline is the valuable asset.** `SegmentTranslationSession` (generation counting, previous-map retention across target changes, per-segment attempt cap, visible-first ordering) and the 150 ms latest-wins live channel are backend-agnostic and directly reusable in Dart. This is the part that took the most iteration in V1.
- **Strict versus lenient is a design decision worth keeping.** A failed translation must be distinguishable from a pass-through so nothing is displayed or broadcast as a translation when it is not one.
- **The broadcaster-provides-translation model should be preserved.** `resolveViewerTranslation` avoiding double translation is a real correctness property, and the wire shape (`translations[]` offered plus `translated[]` by segment ID) is a tested contract. It maps cleanly onto the V2 broadcast payload.
- **Parity gaps to close, not carry:**
  - The non-dismissible accuracy disclaimer (V2 constraint, absent in V1).
  - Cloud premium tier (V1 has none).
  - Mobile (V1 has none; V2 targets Android and iOS first, so ML Kit / Apple Translation are required for parity-with-intent, not just parity).
- **Platform matrix is the main new work.** V1 is one backend. V2 needs at least Apple Translation (iOS/macOS), ML Kit (Android), and an NLLB or cloud fallback for Windows/Linux, per ADR-013. Spikes 6.1 (desktop NLLB via ONNX FFI), 6.2 (ML Kit Flutter), and 6.3 (combined STT+translation latency) are exactly the right unknowns.
- **Cross-references:** ADR-013 defines the interface and the disclaimer; ADR-008 defines the caption bus that the translation middleware attaches to; Phase 8 in `docs/03-roadmap.md` schedules it as v2.1. The roadmap's "feature parity before new features" principle is in tension with translation being scheduled after v2.0, even though V1 ships it: this is a deliberate V2 scoping decision, not an oversight, but it should be stated explicitly because a user migrating from v0.5.0 will lose translation on day one of v2.0.
- **Note on the `feature/on-device-translation` branch**: fully merged into `release/v0.5.0` (verified with `git merge-base --is-ancestor`; the branch is 0 commits ahead of `develop` and is an ancestor of the release branch). It is not an unmerged work-in-progress. The v0.5.0 translation implementation is this branch's work.

---

## Evidence

- `git log -1` — `78637386a79db6ac965ad12952b8c4e4acde3b80`, tag `v0.5.0-rc.5`.
- `git merge-base --is-ancestor feature/on-device-translation release/v0.5.0` — exit 0, merged.
- `git rev-list --left-right --count origin/develop...feature/on-device-translation` — `101  0`.
- `wc -l packages/client/src/app/services/translator/*.ts` — 2,659 lines across 19 files.
- `cat packages/client/src/app/services/translator/chrome-translator.service.ts` — full 565-line source.
- `cat packages/client/src/app/services/translator/caption-translation.service.ts` — full 164-line source.
- `packages/client/src/app/services/translator/translator-api.adapter.ts` — API surface and Chrome 138+/Edge 148+ comment.
- `packages/client/src/app/services/translator/language-detector.adapter.ts` — LanguageDetector wrapper.
- `packages/client/src/app/services/translator/viewer-translation.ts` — broadcaster-vs-local resolution.
- `packages/client/src/app/services/translator/segment-translations.ts` — group planning and merging.
- `packages/client/src/app/services/translator/segment-translation-session.ts:1-60` — generation, attempt cap, previous map.
- `packages/client/src/app/modules/settings/models/settings.model.ts:148-175,279-314,345-377` — bilingual dialects, display modes, settings, 17 languages, defaults.
- `packages/client/src/app/modules/peer/models/broadcast-payload.ts:25-84` — wire format.
- `grep -rn "disclaimer|inaccurate" packages/client/src/app` — no matches (disclaimer absent).
- `aidlc-docs/aidlc-state.md` — unit status, U3/U4/U5/U6/U8/U10/U11 tracking, release blockers.
- `aidlc-docs/inception/requirements/requirements.md:99-143` — FR-9, FR-L2, FR-AZ-3, FR-P3, FR-D3, FR-B1, FR-B4, FR-B5, FR-W1, FR-W2.
- `aidlc-docs/construction/u3-split-orientation-pip/functional-design.md` — layout, placeholder, PiP content design.
- `aidlc-docs/construction/u4-broadcast-both-feeds/functional-design.md` — present, not read in depth.