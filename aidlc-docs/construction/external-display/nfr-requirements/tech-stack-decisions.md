# Tech Stack Decisions — External Display (Unit 8, S-20)

## Dependencies

**Exactly one new dependency** (Q7): `screen_retriever: ^0.2.2` in
`zip_broadcast`, with its SECURITY-10 record standing in the FD
(`functional-design/screen-retriever-security-10.md`): 16 releases counted
against pub.dev; 0.3.0 excluded by the SDK floor (Dart `^3.13.0` /
Flutter `>=3.47.0` against the monorepo's `>=3.10.0` / `>=3.38.0`);
`ScreenRetriever.instance` verified not deprecated in 0.2.2, so the ID-3
deprecation hazard does not apply under the pin; the plugin import is fenced to
the single io file (below). Its four federated packages
(`screen_retriever_platform_interface`, `screen_retriever_macos`,
`screen_retriever_windows`, `screen_retriever_linux`) arrive in the lockfile;
anything else that moves is reported in the PR body, not silently committed
(run-configuration scope fence). `window_manager` is **removed** (D-13); any
other dependency need is BLOCKED, not a fix.

| New artifact | Built from |
|---|---|
| `DisplayInfo` (freezed) | `freezed_annotation` (already declared) |
| `DisplayEnumerator` (abstract) + `ScreenRetrieverDisplayEnumerator` (io) | `screen_retriever: ^0.2.2` (io file only); `dart:async` (broadcast stream) |
| `toPlatformFrame` (pure function) | none — plain Dart |
| `OverlayWindowMode` / `ExternalDisplayStatus` / `OverlayActivity` / `CaptionPosition` / `OverlayEvent` (sealed/enum) | none — plain Dart, `@immutable` where conventional |
| `CaptionOverlaySnapshot`, the snapshot/launch codecs | none — hand-written (D-8), following the `SignalingCodec`/`CaptionWireCodec` precedent; no `json_serializable` on these types |
| `OverlayWindowController` (plain class) | `flutter_riverpod` (constructed on the shell's `ProviderContainer`), `logging` |
| `DesktopWindowService` additions (`setFrame`/`show`) + io conversion | `desktop_multi_window: ^0.2.0` (already declared, Phase 1), `screen_retriever` for the primary full height (macOS conversion input) |
| `ExternalDisplayControls` | `flutter`/`material`, existing `OutputTargetsPanel` host, `flutter_riverpod`, the ARB-backed strings |
| `OverlayWindowApp`, `OverlayWindowEntry` | `flutter`, the shipped `CaptionDisplayWidget` (D-7, `zip_core`), `AppTheme` (`zip_core`), the codecs |
| `OutputTargetSettings` additions (`externalDisplayId`, `externalDisplayCaptionPosition`) | `freezed_annotation`; `shared_preferences` (already declared) via the existing settings loader |

If any future item needs more than the above (e.g. a window-management
package, a display-hotplug polling package, an accessibility plugin), that is a
new finding requiring the run configuration's dependency gate (BLOCKED), not an
assumption.

## Test Tooling

No new test dependency.

- `zip_broadcast` dev dependencies already include `mocktail ^1.0.4` and
  `fake_async ^1.3.2` — both are used by this unit (the extended
  `MockDesktopWindowService`; the ready-timeout and FP-5 stateful suites).
- The in-tree shim `test/helpers/pbt.dart` (100 fixed seeds, no shrinking,
  async bodies) hosts FP-1..FP-5; domain generators are centralized in the
  existing `test/helpers/generators.dart`.
- `MockDesktopWindowService` is extended in place with `setFrame`/`show` (B-6,
  A7); `FakeDisplayEnumerator` is a new hand-written fake in the existing
  `test/helpers/` file naming.

## PBT Framework

**Decision (PBT-09):** the in-tree shim at
`packages/zip_broadcast/test/helpers/pbt.dart` is this unit's PBT framework —
re-affirming the project's Dart PBT decision recorded at Unit 7 NFR
Requirements. No `glados` dependency exists and none is added.
`Glados<T>(generator).test(...)` runs 100 deterministic seeds (`0..99`) and
supports async bodies; it does not shrink, so counterexamples are reduced by
hand and pinned as example tests (PBT-10). All five of the FD's PBT-01
properties (FP-1..FP-5) were checked expressible against this shim (plan Q8);
FP-5 runs in the `fakeAsync`-wrapped stateful shape of the existing
`zip_core` state-machine property suites.

## Native / Runner

Hand-written native runner code on macOS, Windows, and Linux is in scope (D-2,
run-configuration unit exception 2): the `desktop_multi_window` window-created
callback in each runner applies the borderless style (macOS `styleMask`,
Windows `GWL_STYLE` + `SetWindowPos(SWP_FRAMECHANGED)`, Linux
`gtk_window_set_decorated(FALSE)`) and registers the sub-engine plugins the
overlay code path touches (B-4: `google_fonts` via `path_provider` is expected;
confirmed by running the overlay on macOS — a **Unit 9 manual check**, not a
this-stage claim). No new dependency and no plugin patch (D-2). Windows/Linux
runner code is compile-verified by CI's `build-verify.yml`; behaviour is a
Unit 9 manual check.

## Migration

None. No `zip_supabase` migration, no RLS change, no SQL, no Supabase surface
of any kind — this unit has no backend (run configuration).

## Component Placement

All new Dart code is `zip_broadcast`, in the existing overlay directory and
adjacent feature directories; `zip_core` is consumed as shipped (D-8):

- `lib/src/output/overlay/` (the shipped overlay directory):
  - `desktop_window_service.dart` — **additive edit**: `setFrame(int, Rect)`
    and `show(int)` (B-6); the four shipped methods untouched.
  - `desktop_multi_window_service_io.dart` — the io implementation gains the
    two methods, with the B-1/B-2 `toPlatformFrame` conversion (pure function,
    unit-tested) inside it; the single `screen_retriever` import for the
    primary full height (macOS) lives in the io file, per the import fence.
  - `desktop_multi_window_service_stub.dart` — the stub gains the two methods
    (unsupported → the capability gate, BR-U8-11).
  - `display_info.dart` (new, freezed), `display_enumerator.dart` (new,
    abstract interface), `screen_retriever_display_enumerator_io.dart` (new —
    the **only** file in the package that imports `screen_retriever`), plus a
    conditional-export file + stub following the existing
    `desktop_multi_window_service` pattern.
  - `overlay_window_controller.dart` (new — the sole owner, B-9),
    `caption_overlay_codec.dart` (new — snapshot + launch codecs, hand-written,
    versioned, total-on-error, with the named `maxEncodedBytes` constant),
    `overlay_window_mode.dart`, `external_display_status.dart`,
    `overlay_activity.dart`, `caption_position.dart`,
    `overlay_event.dart`, `caption_overlay_snapshot.dart` (new models).
  - `caption_overlay_target.dart` — **additive/rewrite of `onCaptionEvent`**:
    the thin delegator + caption-bus adapter (B-9); the shipped Phase 1
    `{'text', 'isFinal'}` payload is replaced by the codec-encoded snapshot.
- `lib/src/widgets/external_display_controls.dart` (new) — embedded in the
  shipped `OutputTargetsPanel`.
- The sub-engine entry + window root (new, placed by NFR Design — the
  three-argument `["multi_window", id, payload]` contract from the
  Infrastructure Design carries it): `OverlayWindowEntry` (decodes `args[2]`,
  installs the caption handler, sends `overlayReady` after the handler is
  installed) and `OverlayWindowApp`.
- `l10n/arb/app_en.arb` — every new string (English source), then
  `flutter gen-l10n`; never the generated files.
- `main.dart` — the sub-engine entry registration (the runner passes
  `["multi_window", id, payload]`), per the Infrastructure Design's
  three-argument sub-window entry contract.

**Explicitly out of scope:** `packages/zip_core/` (consumed as shipped — any
change is BLOCKED), `packages/zip_captions/`, `packages/zip_supabase/`,
`docs/`, the pop-out unit's definition (D-1), `window_manager` (D-13).

## Platform Neutrality

- `screen_retriever` is imported by **exactly one** file:
  `screen_retriever_display_enumerator_io.dart` (the FD's import fence,
  verified against the 0.2.2 sources in Stage 1). The conditional-export file
  and the stub do not import the plugin.
- No `kIsWeb` anywhere in this unit: web is excluded by
  `DesktopWindowService.isSupported` (BR-U8-11) — one capability rule, the web
  stub and any future unsupported platform behave identically.
- `toPlatformFrame` is the only place in the unit where a coordinate space
  other than logical top-left is named (B-1/B-2); it is a pure function with
  the platform inputs as arguments, unit-tested without a runner (FP-3).
- `sessionId`/`sourceId` never cross the window boundary: the overlay side
  rebuilds `CaptionDisplayEntry` with the decoded `key` as `entryId` and fixed
  placeholder `sessionId`/`sourceId`/`timestamp` (BR-U8-24).
- The codec's `key` is `CaptionDisplayEntry.entryId` (the Phase 8 segment id),
  and `v` is the version field Phase 8 will bump for bilingual mode — both are
  forward notes, not Unit 8 fields to invent (A7 coordination with PR #38).
