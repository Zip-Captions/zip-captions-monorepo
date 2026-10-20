# Logical Components — External Display (Unit 8, S-20)

**Prior stage**: NFR Design Patterns (this directory). Resolves Design
Q6–Q9 of `construction/plans/external-display-nfr-design-plan.md`.
Component placement is fixed by the NFR Requirements
`tech-stack-decisions.md` (not re-decided here); this file fixes what
Code Generation must not re-decide: the provider graph, the constructor
seams, the shell wiring, and the test-helper set.

## Component List

All files in `packages/zip_broadcast` (placement per
`tech-stack-decisions.md` "Component Placement"). `zip_core` is consumed as
shipped — nothing here is added to it (D-8).

### `overlay_window_controller.dart` (new) — `OverlayWindowController`

The sole owner of the window (B-9): the single `int?` window id, the open
guard, open/close/reframe through `DesktopWindowService`, the ready
handshake, the display subscription, the `ExternalDisplayStatus` state
machine + `OverlayEvent` stream, the held snapshot, the captionUpdate
coalescer. A plain class — no `Notifier`, no `BuildContext`.

```dart
class OverlayWindowController {
  OverlayWindowController({
    required DesktopWindowService windowService,
    required DisplayEnumerator enumerator,
    required OverlayMethodHandlerInstaller? handlerInstaller,
    required Logger log,
  });

  ExternalDisplayStatus get status;
  Stream<ExternalDisplayStatus> get statusChanges;  // controls watch this
  Stream<OverlayEvent> get events;                   // shell watches this
  bool get isWindowOpen;                             // target.isVisible delegates here
  Future<void> open(OverlayConfig config);           // T5/T11/T16
  Future<void> close({required CloseReason reason}); // T6/T8/T10/T13/T14
  Future<void> reframe();                            // T15
  void push(CaptionOverlaySnapshot snapshot);        // P1 coalescer
  void selectDisplay(String? id);                    // BR-U8-07 user action only
  Future<void> dispose();                            // release + watch + handler + enumerator
}

typedef OverlayMethodHandler = Future<void> Function(String method, int fromWindowId);
typedef OverlayMethodHandlerInstaller = void Function(OverlayMethodHandler? handler);

const Duration overlayReadyTimeout = Duration(seconds: 10);      // BR-U8-23
const Duration captionUpdateInterval = Duration(milliseconds: 16); // P1

/// FP-4's subject (Design Q8) — pure, no state, no I/O, no clock.
({DisplayInfo? target, bool persistedIdPresent}) resolveOpenDisplay(
  List<DisplayInfo> displays,
  String? persistedId,
);
```

`resolveOpenDisplay` rules (BR-U8-07 verbatim): empty list →
`target: null`; `persistedId` non-null/non-empty and present in the list →
that display, `persistedIdPresent: true`; otherwise the first
`isPrimary` display; otherwise the first display in platform order. The
function never returns a cleared or replaced id — "kept" is the absence of
any write path: nothing in the open sequence writes
`externalDisplayId` (BR-U8-07), and FP-4 asserts the choice plus
`persistedIdPresent` directly.

Internals (from the patterns file): `_lifecycleLock` (R2), `_readyTimer`
started on entering `Opening` and cancelled structurally in `_setState`
(R3), `_updateTimer` (P1), `_release` (R1), `_windowCall` (R4),
`_setMethodHandler` via the installer (D7), the controller-lifetime
`changes` subscription (R1).

Dependencies: `desktop_window_service.dart` (interface),
`display_enumerator.dart` (interface), the codec, `logging`,
`flutter_riverpod` (only for being read by a provider — the class itself is
framework-free apart from `dart:async`).

Tests: `test/output/overlay/overlay_window_controller_test.dart` (example
tests: the T1–T17 transition table, the three close paths, the fake
contracts, idempotence), `test/output/overlay/external_display_redaction_test.dart`
(S2), the FP-5 stateful suite.

### `caption_overlay_target.dart` (additive/rewrite) — `CaptionOverlayTarget`

The thin delegator + caption-bus adapter (B-9). Public surface unchanged:
`show(OverlayConfig)`, `hide()`, `events`, `onCaptionEvent(SttResultEvent)`,
`isVisible`, `dispose()`.

Constructor (Design Q6):

```dart
CaptionOverlayTarget({
  required OverlayWindowController controller,
  required CaptionOutputTargetRegistry registry,
  required DisplaySettings Function() displaySettings,
})
```

- `show`/`hide`/`events` delegate to the controller (the shell drives them
  from `_syncOverlay`, as today).
- `isVisible` returns `_controller.isWindowOpen` — the shipped `_isVisible`
  field is deleted (R1, Design Q1).
- `onCaptionEvent`: builds the snapshot from the main window's target —
  `registry.activeTargets.whereType<OnScreenCaptionTarget>().firstOrNull` —
  reading `visibleCaptions` (final portion + trailing interim,
  `on_screen_caption_target.dart:59-62`), the current `activity` (a pure
  `RecordingState` → `OverlayActivity` mapping held on the target, updated by
  the session-state event — `SessionStateEvent` never pushes a snapshot on
  its own, per the FD), and `displaySettings()` (BR-U8-12: source is the
  provider's value at each update, never a cached copy), then
  `controller.push(snapshot)`.
- The Phase 1 `{'text', 'isFinal'}` `captionUpdate` payload is replaced by
  the codec-encoded snapshot; its 10 existing tests are re-pointed (FD T8).
- `dispose()` calls the idempotent `controller.close()` (fire-and-forget,
  non-blocking) without awaiting — the registry's synchronous `dispose()`
  call cannot block on a window close.

Remains the single `CaptionOutputTarget` for this surface on
`CaptionOutputTargetRegistry`; every new type is a collaborator of it or of
the shell, never a parallel target.

### `caption_overlay_codec.dart` (new) — snapshot + launch codecs

Hand-written, versioned, total-on-error (D-8, B-7, BR-U8-24), following the
`CaptionWireCodec` precedent. `encodeSnapshot`/`decodeSnapshot`,
`encodeLaunch`/`decodeLaunch`; enums by name; `v: 1`; `key` ==
`CaptionDisplayEntry.entryId`; placeholder `sessionId`/`sourceId`/
`timestamp` on decode (BR-U8-24); exactly one `mode` source
(`config.mode`); `static const int maxEncodedBytes = 16 * 1024` (P3)
enforced on the UTF-8 byte length of the full encoded payload.

Tests: FP-1, FP-2, plus the named example cases (PBT-10).

### `desktop_window_service.dart` / `_io.dart` / `_stub.dart` (additive)

B-6: the interface gains `Future<void> setFrame(int windowId, Rect frame)`
(frame in logical top-left; the io implementation converts) and
`Future<void> show(int windowId)`; the four shipped methods untouched.
`desktop_multi_window_service_io.dart` gains both methods and hosts
`toPlatformFrame` (P5, pure) plus the production installer const
`overlayMethodHandlerInstaller` (wrapping
`DesktopMultiWindow.setMethodHandler`, adapting `MethodCall` →
`(call.method, fromWindowId)`; installing `null` uninstalls — the only place
in the package that touches the plugin's static). The stub gains both
methods (unsupported → capability gate, BR-U8-11) and a no-op const under
the same name. The conditional-export file and the plugin import surface
are unchanged in shape (the io file already imports
`desktop_multi_window`).

Tests: `toPlatformFrame` — FP-3 + the named examples (PBT-10).

### `display_info.dart`, `display_enumerator.dart`, `screen_retriever_display_enumerator.dart` (conditional export) + `_io.dart`/`_stub.dart` (new)

The io/stub triplet follows the existing `desktop_multi_window_service`
pattern exactly: both variants define the same concrete class
`ScreenRetrieverDisplayEnumerator`, and
`screen_retriever_display_enumerator.dart` is the conditional export
(`export '..._stub.dart' if (dart.library.io) '..._io.dart'`).
Per the FD domain-entities: `DisplayInfo` (freezed), the abstract
`DisplayEnumerator` in `display_enumerator.dart` (`displays()`, `changes`,
`dispose()`), the io implementation (the **only** file importing
`screen_retriever` — import fence), with the id-normalisation order
(plugin id → name → `display-<index>`), the `isPrimary` derivation
(open-questions note in the patterns file), the re-query-and-diff event
contract (BR-U8-05), and the fixed `warning` log on platform failure with
the stream staying open; the stub returns an empty list with a
never-emitting `changes` (the capability gate, BR-U8-11, screens it off
before use).

Tests: BR-U8-05 contract example tests against `FakeDisplayEnumerator`'s
specification (the io implementation is a thin plugin wrapper — no property,
per the FD).

### Model files (new, plain Dart): `overlay_window_mode.dart`, `external_display_status.dart`, `overlay_activity.dart`, `caption_position.dart`, `overlay_event.dart`, `caption_overlay_snapshot.dart`

Shapes fixed by the FD `domain-entities.md` (not re-decided here).
`OverlayWindowMode` is sealed with the single `ExternalDisplayMode`
variant (D-1 keeps the hierarchy extensible for the pop-out unit);
`ExternalDisplayStatus` is the seven-variant sealed state type of the
T1–T17 machine; `OverlayEvent` is `DisplayLost`/`WindowClosed`/
`OpenFailed`.

### `overlay_window_controller_provider.dart` (new, `lib/src/providers/`) — `overlayWindowControllerProvider`

A **hand-written** `Provider<OverlayWindowController>` (the controller is a
plain class, not a `Notifier`; the project's service objects
(`onScreenCaptionTargetProvider`, `transcriptWriterTargetProvider`,
`displaySettingsProvider`) are hand-written `Provider`s):

```dart
final overlayWindowControllerProvider = Provider<OverlayWindowController>((ref) {
  final controller = OverlayWindowController(
    windowService: DesktopMultiWindowService(),        // shipped conditional export
    enumerator: ScreenRetrieverDisplayEnumerator(),    // new conditional export (io/stub triplet)
    handlerInstaller: overlayMethodHandlerInstaller,   // top-level const, same export pair
    log: Logger('zip_broadcast.OverlayWindowController'),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
```

The `overlayMethodHandlerInstaller` const is a top-level in
`desktop_multi_window_service_io.dart` (which already imports
`desktop_multi_window` — no new import surface), wrapping
`DesktopMultiWindow.setMethodHandler` with a `MethodCall` →
`(call.method, fromWindowId)` adapter; the stub file's version is a no-op
const. Both surface through the **existing** conditional export file
(`desktop_multi_window_service.dart`) — no new export file for it.

Lazily created on first read (the controls at panel mount), alive for the
app container. `externalDisplayStatusProvider` — a `StreamProvider` over
`controller.statusChanges` — is where `ExternalDisplayControls` reads its
render state; the display list itself comes from a `StreamProvider` over
`controller.enumerator.changes` seeded by the first `displays()` call
(capability probe: a throwing `displays()` or `isSupported == false` →
`Unsupported`, the section renders nothing, BR-U8-11/T1).

### `external_display_controls.dart` (new, `lib/src/widgets/`) — `ExternalDisplayControls`

Embedded in the shipped `OutputTargetsPanel`. Renders per the seven
`ExternalDisplayStatus` variants (frontend-components.md); row tap writes
`externalDisplayId` **only** via `controller.selectDisplay` (no settings
write from rendering — BR-U8-07); the Cancel button in
`WaitingForDisplay` drives `close(reason: cancel)` (T12, saved id kept);
the toggle drives the settings notifier's `overlayEnabled` (the shell's
existing `ref.listen` → `_syncOverlay` does the rest); the caption-position
selector writes `externalDisplayCaptionPosition`. All strings ARB-backed
(`app_en.arb`), none hard-coded.

### `OverlayWindowEntry` / `OverlayWindowApp` (new, sub-engine)

`OverlayWindowEntry` decodes `args[2]` with the launch codec (the
three-argument `["multi_window", id, payload]` contract is carried by the
Infrastructure Design's runner callback — B-4); on failure renders the fixed
"Window unavailable" frame, logs `invalid_window_arguments`, and never sends
`overlayReady` (R5). On success it installs the sub-engine's caption
handler, then sends `overlayReady` through the main engine (the handshake's
second half — the main side's handler is the D7 installer). `OverlayWindowApp`
renders standby/live/paused from the decoded snapshot via the shipped
`CaptionDisplayWidget` (D-7/BR-U8-25), takes its surface/text colours from
`AppTheme`'s `surface`/`onSurface` (BR-U8-20 — no literal), applies the
launch config's position, and renders an **opaque** surface
(`OverlayConfig.opacity` not applied, BR-U8-26). The sub-engine entry
registration lands in `main.dart` per the Infrastructure Design.

### `OutputTargetSettings` (modified) + settings loader

`externalDisplayId` (`String?`, key `output.externalDisplayId`) and
`externalDisplayCaptionPosition` (`CaptionPosition`, key
`output.externalDisplayCaptionPosition`) added per the FD; the loader
forces `overlayEnabled = false` at launch (BR-U8-21, D-6) and honours only
the two new keys from stored values.

### Test helpers (Design Q9)

- `test/helpers/mock_desktop_window_service.dart` — **no class change**:
  mocktail's `noSuchMethod` covers the additive `setFrame`/`show` interface
  methods; the extension is the B-6 interface edit plus `when`/`verify`
  coverage in the test files (one step with B-6).
- `test/helpers/fake_display_enumerator.dart` (new) — scripted
  `displays()` result or error; broadcast `changes` with a
  `pushDisplays` helper that replays the latest list to late subscribers
  (FD first-emission clause); idempotent, recorded `dispose()`.
- `test/helpers/fake_overlay_method_handler_installer.dart` (new, small) —
  records the installed `OverlayMethodHandler` and the uninstall; exposes
  the handler for a trial to invoke.
- `test/helpers/generators.dart` (extended) — `arbitraryDisplayInfo` /
  `arbitraryDisplayList` (0..n; at most one `isPrimary` at any position;
  empty labels; ids including Linux-normalised `display-<n>` and `""`;
  work-area bounds; scale factors 0/1/1.5/2), `arbitraryCaptionOverlaySnapshot`
  (any `activity`, 0..max entries, multibyte text, any `DisplaySettings`
  combination), `arbitraryOverlayWindowLaunch` (mode, position),
  `arbitraryMalformedWindowJson` (truncated, wrong field type, unknown
  `v`, unknown enum for `activity`/`settings`/`position`/`mode`, over-size
  beyond `maxEncodedBytes`), `arbitraryLogicalFrame` (arbitrary top-left
  `Rect` + platform inputs — primary full height, target scale — including
  macOS negative-result and Windows mixed-DPI cases), and
  `arbitraryExternalDisplayCommandSequence` (the FP-5 command set, varying
  length including empty).

### FP-5 harness (Design Q9)

A `_World`-shaped class per Glados trial, wrapped in one `fakeAsync` per
trial (the `viewer_session_state_machine_properties_test.dart` shape,
adopted because the command set contains timer expiry). The world
constructs the real controller directly on the fakes (no
`ProviderContainer` — the controller is a plain class), a real
`CaptionBus` + real `CaptionOutputTargetRegistry` (in-memory, no I/O), and
a harness `overlayEnabled` flag that models the shell's documented
reaction to emitted events (`WindowClosed`/`OpenFailed` → the flag goes
false, as the shell's `_syncOverlay` path does — without it BR-U8-15's
"at every point where `overlayEnabled` is false" could not be checked at
the controller level). Commands: `toggleOn`/`toggleOff` (drive the
target's `show`/`hide` delegations, exactly what `_syncOverlay` does),
`displaysChanged(list)`, `overlayReady` (invoke the recorded handler),
`advanceReadyTimeout` (elapse `overlayReadyTimeout` + 1 ms), `windowGone`
(script the next window call to throw `PlatformException(code: '-1')`),
`otherPlatformError`, `createWindowFails`, `captionEvent` (push a
snapshot through the target), `elapse(ms)`. Invariants after **every**
command: only declared `ExternalDisplayStatus` variants reached (sealed
switch); exactly one state at a time; the closed invariant
(`!controller.isWindowOpen` ∧ target not in `registry.activeTargets` ∧
`target.isVisible` false) at every step where the harness flag is false
(BR-U8-15); a second concurrent open is refused — a `toggleOn` while
`Opening` leaves `createWindow`'s call count unchanged (BR-U8-01); the
saved id is never written by the open path (the fake settings recorder sees
no `externalDisplayId` write except from an explicit `selectDisplay`
command). PBT-04's idempotence is asserted inside these sequences and once
directly.

## Dependency Diagram

```
                    main.dart (sub-engine entry registration, B-4)
                         |
                         v
              OverlayWindowEntry --> caption_overlay_codec.dart
                         |                    (encode/decode, maxEncodedBytes)
                         v
                   OverlayWindowApp --> zip_core CaptionDisplayWidget, AppTheme
                                          (both consumed as shipped)

 ZbAppShell (zb_app_shell.dart)
   |  owns: CaptionOverlayTarget (field, as today)
   |  reads: overlayWindowControllerProvider (statusChanges, events)
   |  ref.listen(outputTargetSettingsNotifierProvider) --> _syncOverlay(bool)
   |        _syncOverlay(true):  registry.add(target); target.show(config)
   |        _syncOverlay(false): registry.remove(target)   (shipped: hide() first)
   |  events subscription:
   |    WindowClosed/OpenFailed --> write overlayEnabled=false (notifier)
   |                                (the existing ref.listen runs _syncOverlay(false))
   |    DisplayLost               --> _overlayRegistered bookkeeping only
   |                                   (overlayEnabled stays true, D-4)
   |
   v
CaptionOverlayTarget (thin delegator + caption-bus adapter)
   |  controller, registry, DisplaySettings Function()
   |  onCaptionEvent: registry.activeTargets.whereType<OnScreenCaptionTarget>()
   |                  .visibleCaptions + activity + displaySettings()
   |                        --> controller.push(snapshot)
   v
OverlayWindowController (plain class; the sole owner, B-9)
   |  _lifecycleLock, _readyTimer, _updateTimer, _release, _windowCall
   |  resolveOpenDisplay (pure, FP-4)
   +--> DesktopWindowService (interface)
   |        io: desktop_multi_window (setFrame/show/createWindow/closeWindow,
   |            toPlatformFrame, setMethodHandler adapter)
   |        stub: capability gate (isSupported false, BR-U8-11)
   +--> DisplayEnumerator (interface)
   |        io: screen_retriever (the ONLY import site — fence)
   |        stub: empty list, no events
   +--> CaptionOutputTargetRegistry (zip_core, shipped)
   +--> CaptionBus (zip_core, shipped) -- via CaptionOverlayTarget
   +--> displaySettingsProvider value (via the target's reader closure)

 ExternalDisplayControls (widgets/)
   |  reads: externalDisplayStatusProvider (StreamProvider over statusChanges)
   |         the display-list StreamProvider over enumerator.changes
   |  writes: overlayEnabled / externalDisplayId / externalDisplayCaptionPosition
   |          through the settings notifier + controller.selectDisplay
   v
 (rendering only — BR-U8-20 wiring, no colour literal)
```

Provider graph note: `overlayWindowControllerProvider` is a leaf (it
depends on no other provider); `externalDisplayStatusProvider` and the
display-list `StreamProvider` depend on it; `CaptionOverlayTarget` is
constructed by the shell (not a provider) with the controller injected —
the target is a registry member, not a provider, exactly as in Phase 1.

## Resource Lifecycle / Cancellation Ownership

| Resource | Created | Cancelled/Released | Owner |
|---|---|---|---|
| window id (`int?`) | `createWindow` (open sequence) | `_release` step 3 (`closeWindow`, captured id) + nulled synchronously in `close()` before the first await | controller |
| ready `Timer` | entering `Opening` (before `createWindow`) | structurally in `_setState(next)` when `next is! Opening` (R3); defensively in `_release` step 1 | controller |
| captionUpdate `Timer` | `push` while `Open` (P1) | on fire; in `_release` step 2; in `dispose()` | controller |
| `changes` subscription | controller bootstrap | `dispose()` only — **not** in `_release` (R1: T11/T4/T16 need it without a window) | controller |
| method handler | installer call on first open, before `createWindow` (D7) | installer call with `null` in `dispose()`; **not** on close (the next open reuses it) | controller (installer is the seam) |
| `DisplayEnumerator` (native observer) | bootstrap (first `displays()`) | `dispose()` → `enumerator.dispose()` (idempotent) | controller |
| `CaptionOverlayTarget` registration | shell `_syncOverlay(true)` → `registry.add` | shell `_syncOverlay(false)` → `registry.remove` (disposes the target); `_release` step 4 is a no-op-safe backstop (R1) | shell (registry disposes the target) |
| `overlayEnabled` setting | user toggle on | shell `_syncOverlay(false)` via the settings notifier; written `false` on `WindowClosed`/`OpenFailed` by the shell's event subscription; forced `false` at launch (BR-U8-21) | settings notifier (shell writes) |
| controller itself | `overlayWindowControllerProvider` first read | `ref.onDispose(controller.dispose)` (app shutdown) | provider |

The closed invariant (BR-U8-15) is exactly the conjunction of the
controller-side rows (window id null, `isVisible` false via the derived
getter, no per-window timers) plus the registry row (target removed) —
checked in the shell's `dispose`, after any close in the controller, in
FP-5 after every command, and in the widget tests that drive every close
path (BR-U8-15's own test list).

## State → Pattern Mapping (T1–T17)

| Transition | Pattern(s) applied |
|---|---|
| T1 capability check → `Unsupported` | R6 (fail-closed: no section, no logic) |
| T2 `Unsupported` stays | R6 |
| T3 first `displays()` = [] → `NoDisplays` | R1 (watch alive in a window-less state) |
| T4 `changes` adds display → `Off` | R1 (watch-driven, no window) |
| T5 toggle on → `Opening` | R2 (guard), R3 (timer started), D7 (handler installed before `createWindow`), R6 (fail-closed if installer absent) |
| T6 `createWindow` throws → `Failed(create_failed)` | R4 (open-sequence catch, not the wrapper), R1 (idempotent close), R6 (`overlayEnabled` false) |
| T7 `overlayReady` → `Open` | R3 (late-ready guard), P1 (held snapshot sent immediately) |
| T8 timeout → `Failed(ready_timeout)` | R3 (timer fires), R1 (half-open window closed idempotently), R6 |
| T9 recognition event → `Open` (new `activity`) | P1 (activity-only snapshot update, BR-U8-17: no open/close) |
| T10 display gone → `WaitingForDisplay` | R1 (release first, watch survives), R6 (`overlayEnabled` stays true — D-4) |
| T11 saved display back → `Opening` → `Open` | R1 (watch-driven reopen), R2/R3/D7 (full open sequence again) |
| T12 Cancel → `Off` | R2 (close from a window-less state is the no-op half), BR-U8-07 (saved id kept) |
| T13 toggle off → `Off` | R1 (shared release), R2 |
| T14 `'-1'` → `Off` via `WindowClosed` | R4 (seam converts; never into the shell's `unawaited`), R1, R6 (shell writes `overlayEnabled` false) |
| T15 same id, new bounds → `Open` | P5 (one `setFrame` through the R4 seam), no re-handshake (BR-U8-09) |
| T16 retry from `Failed` → `Opening` | R1 (watch alive in `Failed`), R2/R3/D7 |
| T17 coalesced no-op → stays | P2 (zero emissions on no change, BR-U8-05) |
