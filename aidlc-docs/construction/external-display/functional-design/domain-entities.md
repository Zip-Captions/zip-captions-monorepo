# Domain Entities — Unit 8: External Display (S-20)

New and modified types for the external display target. `zip_broadcast` only;
nothing here is added to `zip_core` (D-8 keeps the codec hand-written in
`zip_broadcast`; `zip_core` is consumed as shipped).

**Revised 2026-10-20** per the PR #37 review comment (2026-10-19,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>):
D-1 (pop-out split into its own unit — every pop-out type below is removed),
D-3, D-4, D-5, D-6, D-7, D-8, D-9, D-13, and B-1 .. B-9. The pop-out's UX
contract stays binding for that future unit in `pip-ux-parity.md` §8, which this
unit does not implement, edit or move.

The Application Design fixed the *names* (`DisplayEnumerator`,
`ScreenRetrieverDisplayEnumerator`, `DisplayInfo`, `OverlayWindowEntry`,
`OverlayWindowApp`, the `OutputTargetSettings` display field) and the analyzer
methods (`displays()`, `changes`). It did not fix field lists or
serialization shapes. Those are settled here and must not be re-decided at Code
Generation. Where this revision departs from the Application Design's fixed
shapes, the departure is recorded in the Functional Design plan
("Application Design deviations"), with the PR #37 review as the approval.

---

## DisplayInfo (freezed, new)

One connected display, as reported by the platform.

```dart
@freezed
abstract class DisplayInfo with _$DisplayInfo {
  const factory DisplayInfo({
    required String id,
    required String label,
    required Rect bounds,
    required double scaleFactor,
    required bool isPrimary,
  }) = _DisplayInfo;
}
```

| Field | Type | Constraints | Purpose |
|---|---|---|---|
| `id` | `String` | Non-empty, opaque, stable for the lifetime of the display | Persisted selection key (`OutputTargetSettings.externalDisplayId`); the only thing this feature persists across launches (D-6) |
| `label` | `String` | May be empty | Shown in `ExternalDisplayControls`; falls back to "Display N" copy in the UI |
| `bounds` | `Rect` | Logical pixels, origin at the global desktop origin, **top-left based**, covering the display's **work area** (B-1/B-2, D-3) | The overlay window's target frame; applied through `DesktopWindowService.setFrame` (B-6), which owns the per-platform conversion |
| `scaleFactor` | `double` | `> 0` in practice; `0` or a missing value is treated as `1` | Windows frame conversion multiplies by the *target display's* `scaleFactor` (B-2); description only elsewhere ("2880×1620 (2x)") |
| `isPrimary` | `bool` | Exactly one `true` in a non-empty list | "Primary display" copy and the default selection |

`Rect` is `dart:ui`'s, re-exported by `package:flutter/material.dart`.

**`id` provenance.** `screen_retriever` 0.2.x's `Display.id` is a non-empty
string on Windows and macOS (derived from the platform display handle) but the
Linux backend sends `""` for every monitor
(`screen_retriever_linux/linux/screen_retriever_linux_plugin.cc:76`). The
adapter therefore **normalises**, in this order, in one place:

1. use the plugin's `id` when it is non-empty;
2. otherwise use `name` when it is non-empty (Linux reports the GDK monitor
   model or the X11 output name, which is stable across a session), prefixed
   with the list position only when the same name repeats (`VGA-1#2`);
3. otherwise use `display-<index>`.

Normalisation is stable *within* a process (same list, same ids) and across
relaunches for (1) and (2). A persisted id that no longer matches is handled by
BR-U8-07 (kept, not cleared) and by D-4's waiting state (the window reopens on
the saved display when it reappears), so a relaunch that renames a display
degrades to waiting rather than crashing. This is the only
platform-specific behaviour the adapter owns.

**Label provenance.** `screen_retriever` 0.2.x does not expose a user-assigned
display name on all three platforms (Windows and Linux report the monitor model
or nothing; macOS reports `NSScreen.localizedName`). The adapter passes whatever
`name` the plugin returns; the UI owns the fallback copy. This is the reason
`label` is allowed to be empty and is never used as a key.

**Coordinate and scale provenance (per backend), corrected per B-1/B-2.**
`bounds` is built from `visiblePosition` (offset) + `visibleSize` (extent). All
three backends of `screen_retriever` 0.2.2 already emit **top-left-origin
logical pixels**, which is the one coordinate space the whole unit uses in
Dart. **No conversion is done in the adapter**:

| Backend | Offset source | Extent source | Conversion in the adapter |
|---|---|---|---|
| macOS | `NSScreen.visibleFrame`, flipped to top-left by the plugin itself | `visibleFrame.size` | none — already top-left logical pixels (`screen_retriever_macos/.../ScreenRetrieverMacosPlugin.swift:18-24,36-45`) |
| Windows | `rcWork.left/top` **divided by the monitor scale by the plugin** | `rcWork` width/height, divided the same way | none — `screen_retriever_windows/windows/screen_retriever_windows_plugin.cpp:116-124` computes `visiblePosition`/`visibleSize` as `rcWork / scale_factor`, i.e. logical pixels. (The earlier draft claimed the plugin reports physical pixels and that the adapter must divide; that was wrong and is corrected here per B-2.) |
| Linux | `gdk_monitor_get_workarea().x/y` | workarea width/height | none — GDK already reports logical pixels |

The per-platform conversion that *does* exist lives in exactly one place — the
io window adapter's frame conversion, below — because `desktop_multi_window`'s
`setFrame` consumes platform-native coordinates, not logical top-left:

- macOS: `FlutterMultiWindowPlugin.swift:61` builds `NSRect(x: left, y: top, …)`
  and passes it to `NSWindow.setFrame` (`MultiWindowManager.swift:81-86`), which
  is **Cocoa bottom-left** — the plugin performs no flip for `setFrame`
  (the flip at `ScreenRetrieverMacosPlugin.swift:36-45` applies only to
  `screen_retriever`'s own output).
- Windows: `base_flutter_window.cc:66` calls `MoveWindow(handle, x, y, …)` with
  the raw values, which under the runner's `PerMonitorV2` manifest are
  **physical** pixels.
- Linux: `gtk_window_move`/`gtk_window_resize` consume the values as
  top-left logical — no conversion.

Where the three disagree (fractional scaling, Wayland), the unit does not
reconcile: `bounds` reports what the platform gives in logical top-left, and
the remaining discrepancy is a Unit 9 manual check. No further heuristic
conversion is written without a real multi-monitor machine to verify it on.

---

## Frame conversion (pure function, io window adapter)

The one non-symmetric step of the whole unit (B-1, B-2). Specified as a **pure
function inside the io implementation of `DesktopWindowService`**
(`desktop_multi_window_service_io.dart`): no I/O, no statics, no platform
calls — the platform inputs (primary full height, target scale factor) are
arguments, which is what makes it unit-testable without a runner.

```
toPlatformFrame(
  Rect frame,            // top-left logical, = DisplayInfo.bounds
  TargetPlatform target, // macos | windows | linux
  double primaryFullHeight,   // macos only: getPrimaryDisplay().size.height
  double displayScaleFactor,  // windows only: the target display's scaleFactor
) -> Rect   // platform-native coordinates for setFrame
```

| Platform | Rule |
|---|---|
| macOS | `x = frame.left`, `y = primaryFullHeight − frame.top − frame.height`, width/height unchanged. `primaryFullHeight` comes from `screen_retriever`'s `getPrimaryDisplay().size` (the primary's **full** size, not its visible size — the menu bar region matters for the flip). Negative `y` for a display positioned below the primary is correct Cocoa. |
| Windows | `x = frame.left × sf`, `y = frame.top × sf`, `width = frame.width × sf`, `height = frame.height × sf`, where `sf = displayScaleFactor` — **that display's own** factor (B-2: multiply; the plugin's values are already logical, and `MoveWindow` under `PerMonitorV2` takes physical). `sf` of `0` or missing is treated as `1`. |
| Linux | identity — `frame` unchanged |

Tested (example cases, per the T6/T7 list in the Code Generation plan, plus
PBT-01 property FP-3 below):

- a macOS-shaped primary + a secondary positioned below it (the flip must
  produce a negative Cocoa `y`);
- a Windows-shaped display at 1.5x (each edge scales by exactly 1.5);
- a mixed-DPI setup: two displays at different scale factors, each converted
  with its *own* factor; and on macOS, a target that is *not* the primary,
  converted against the *primary's* full height.

The function and its platform inputs are the only place in the unit where a
coordinate space other than logical top-left is named.

---

## DisplayEnumerator (abstract interface, new)

Fixed by Application Design §7 (`displays()`, `changes`); `dispose()` is the
one recorded addition.

```dart
abstract interface class DisplayEnumerator {
  Future<List<DisplayInfo>> displays();
  Stream<List<DisplayInfo>> get changes;
  Future<void> dispose();
}
```

`dispose()` is the only addition. A long-lived `Stream` that a plugin backs
with a native observer needs an explicit release point, and the shipped
`CaptionOutputTarget.dispose()` contract already gives callers one to call. It
is idempotent.

### Display-change event contract (BR-U8-05)

`changes` is a **broadcast** stream.

| Property | Contract |
|---|---|
| First emission | The current display list, delivered to a listener that subscribes at any time — not only to listeners present before the first platform event. Implemented with a platform-listener subscription started on the first Dart listener and a replayed latest value. |
| Emission on connect | A list containing the new display, in platform order. |
| Emission on disconnect | A list without the removed display. |
| Emission on rearrangement | A list with the same ids but different `bounds`/`isPrimary`. Consumers must not treat a same-id list as "no change" — a geometry change re-frames the open window (BR-U8-09). |
| No change | No emission. The platform observer already supplies that; the adapter does not synthesise a periodic poll. |
| Error | A platform failure is **logged at `warning` with a fixed string** and the stream does **not** emit an error and does **not** close. A transient platform hiccup must not kill the fallback listener (S-20 "falls back gracefully"). |
| Close | Only on `dispose()`. |
| Threading | Events are delivered on the Dart event loop; no reentrancy guarantees are made. |
| Duplicate suppression | Adjacent equal lists (`==` over id, label, bounds, scaleFactor, isPrimary) are coalesced. A same-id list with changed geometry is **not** equal and is emitted. |

`ScreenRetrieverDisplayEnumerator` maps `screen_retriever` 0.2.2's
`getAllDisplays()` and its `ScreenListener` (`addListener`/`removeListener`,
`onScreenEvent(String)`) onto this contract. The platform event carries only
`display-added` / `display-removed`, so every event re-reads the display list
and diffs it against the last emitted list; that is what produces first
emission, connect, disconnect, rearrangement and duplicate suppression from one
code path. Verified against the 0.2.2 sources: `ScreenRetriever.instance`
(`screen_retriever/lib/src/screen_retriever.dart:9`) is **not deprecated** in
0.2.2, and the event names are identical on all three backends
(`screen_retriever_macos/.../ScreenRetrieverMacosPlugin.swift:88,91`,
`screen_retriever_windows/windows/screen_retriever_windows_plugin.cpp:90,92`,
`screen_retriever_linux/linux/screen_retriever_linux_plugin.cc:166,170`). The
0.2.x model has no `displayChangedNotifier` (that is a 0.3-only API) and no
event payload, so the re-read-and-diff path is the only way re-arrangement is
observed. The plugin's own API shape is confined to
`screen_retriever_display_enumerator_io.dart`; `DisplayEnumerator` is the only
type the rest of the package sees.

---

## OverlayWindowMode (sealed class, new)

Which intent the one window component is serving. D-1 splits the pop-out into
its own unit, so **this unit ships exactly one variant**; the sealed hierarchy
is kept because D-1 requires the window machinery to stay extensible so a
pop-out mode can be added later without a second window implementation
(`pip-ux-parity.md` §8.7 "not twice" becomes a constraint on that future
unit).

```dart
sealed class OverlayWindowMode {
  const OverlayWindowMode();
}

final class ExternalDisplayMode extends OverlayWindowMode {
  const ExternalDisplayMode({this.displayId});
  final String? displayId;          // null = primary display
}
```

`displayId` is informational (the resolved target at open time); the persisted
selection is `OutputTargetSettings.externalDisplayId` and is the source of
truth (BR-U8-07, D-4).

---

## OverlayConfig (freezed, modified)

Shipped in Phase 1 with `targetDisplayId`, `position`, `opacity`. The window
component needs to know which mode it is in; the pop-out's size fields never
ship (D-1).

```dart
@freezed
abstract class OverlayConfig with _$OverlayConfig {
  const factory OverlayConfig({
    @Default(ExternalDisplayMode()) OverlayWindowMode mode,
    @Default(OverlayPositionBottom()) OverlayPosition position,
    @Default(0.9) double opacity,
  }) = _OverlayConfig;
}
```

| Change | Compatibility |
|---|---|
| `targetDisplayId` is replaced by `mode` | `const OverlayConfig()` still compiles and means "external display on the primary, bottom". The one shipped producer is the default construction in `CaptionOverlayTarget.show()`; no other package reads the type. Recorded Application Design deviation (plan). |
| `popOutSize` / `popOutMinimumSize` | **Removed** — they existed only in the superseded in-unit pop-out design (D-1). The shipped model never had them. |
| `opacity` | Kept (shipped field, Phase 1 contract) but **never applied** in external display mode: the external display renders an **opaque** surface (B-8, BR-U8-26). |

`position` keeps its Phase 1 meaning unchanged: where the caption text sits
**inside the surface**, not where the window is on the desktop. For the
external display it is set from the persisted caption-position setting
(B-8, `OutputTargetSettings.externalDisplayCaptionPosition`): `top` →
`OverlayPositionTop`, `bottom` → `OverlayPositionBottom`. `custom` is not
offerable for the external display and is not encoded in the launch config.

---

## DesktopWindowService (abstract, modified)

The shipped interface gains two methods (B-6). The B-1/B-2 frame conversion
lives **inside the io implementation**, not in the interface:

```dart
abstract class DesktopWindowService {
  Future<int> createWindow(String arguments);   // shipped
  Future<void> closeWindow(int windowId);        // shipped
  Future<void> invokeMethod(int windowId, String method, dynamic arguments); // shipped
  bool get isSupported;                          // shipped

  Future<void> setFrame(int windowId, Rect frame); // NEW — frame in logical
                                                   // top-left; the io
                                                   // implementation converts
  Future<void> show(int windowId);               // NEW
}
```

The open sequence is fixed (B-6): `createWindow` → `setFrame` → `show`. The
plugin's `createWindow` never orders the window on screen (its Windows path
explicitly `ShowWindow(window_handle, SW_HIDE)`s after creation;
`MultiWindowManager.create` on macOS returns the id without `show()`), so the
explicit `show` is load-bearing on every platform. The window shows the
standby surface from the moment it is visible until the first snapshot is
rendered.

`isSupported` is the single capability gate (BR-U8-11): web and any
unsupported platform get the stub implementation, and no code path checks
`kIsWeb`.

---

## OverlayEvent (sealed class, new)

Fixed by Application Design as `Stream<OverlayEvent> get events;` with
`DisplayLost` named. The full set, with D-4/D-9 semantics:

```dart
sealed class OverlayEvent {
  const OverlayEvent();
}

final class DisplayLost extends OverlayEvent {
  const DisplayLost({required this.displayId});
  final String displayId;
}

final class WindowClosed extends OverlayEvent {
  const WindowClosed();
}

final class OpenFailed extends OverlayEvent {
  const OpenFailed(this.reason);
  final String reason;   // fixed code, never a caption or display label
}
```

| Event | Emitted when | UI response |
|---|---|---|
| `DisplayLost` | The selected display disappeared from `changes` while the window was open | The controller has already closed the window and entered `WaitingForDisplay`; the shell shows the Proto-13 disconnected notice (F-8.5, D-4) |
| `WindowClosed` | After the ready handshake, a `PlatformException` with code `'-1'` was received from any `invokeMethod`/`setFrame`/`closeWindow` on the window (D-9) | Clear `overlayEnabled` through the settings notifier; the shell's existing `_syncOverlay` path then deregisters the target (BR-U8-15) |
| `OpenFailed` | `createWindow` threw (`reason = create_failed`), or no `overlayReady` arrived within `overlayReadyTimeout` (`reason = ready_timeout` — covers a sub-engine that dies before its handler runs, including a launch argument it could not decode) | Notify the broadcaster with a fixed copy; `overlayEnabled` returns to `false` (BR-U8-03) |

`OpenFailed.reason` is a short fixed code. No configuration JSON, display
label, or caption text is ever placed in it (BR-U8-18).

---

## OutputTargetSettings (freezed, modified)

Adds two persisted fields; `overlayEnabled` keeps its shipped name and key;
the pop-out fields of the superseded design never ship (D-1).

```dart
@freezed
abstract class OutputTargetSettings with _$OutputTargetSettings {
  const factory OutputTargetSettings({
    @Default(true) bool onScreenEnabled,
    @Default(false) bool obsEnabled,
    @Default(false) bool browserSourceEnabled,
    @Default(false) bool overlayEnabled,          // external display, see below
    @Default(8080) int browserSourcePort,
    String? externalDisplayId,                    // default null = primary
    @Default(CaptionPosition.bottom) CaptionPosition externalDisplayCaptionPosition,
  }) = _OutputTargetSettings;
}
```

| Field | Default | Persistence key | Purpose |
|---|---|---|---|
| `overlayEnabled` | `false` | `output.overlayEnabled` (unchanged) | External display output on/off. **Not restored at launch**: the switch always starts off (D-6) — the settings loader forces `false` for this key regardless of the stored value. The write still persists for the session, but a relaunch never auto-opens the window. |
| `externalDisplayId` | `null` | `output.externalDisplayId` | Selected `DisplayInfo.id`; `null` means primary. The only display-related value that persists across launches (D-6). A value no longer present in the list is kept as-is (BR-U8-07) and is the id `WaitingForDisplay` waits for (D-4). |
| `externalDisplayCaptionPosition` | `CaptionPosition.bottom` | `output.externalDisplayCaptionPosition` | Proto-13's Caption Position (Top/Bottom) selector (B-8). Carried in the launch config (see `OverlayConfig.position`). |

`popOutEnabled`, `popOutDisplayId` and the `PipContent` content setting are
**not** added (D-1). They belong to the pop-out unit.

---

## CaptionPosition (enum, new)

```dart
enum CaptionPosition { top, bottom }
```

Where the caption block sits inside the external display surface (B-8).
Persisted as its name (`'top'`/`'bottom'`). The launch config encodes it in
`OverlayConfig.position`; the codec accepts exactly `top`/`bottom` there
(unknown values decode to `null`).

---

## OverlayActivity (enum, new)

What the window shows, selected by the recognition state (D-5):

```dart
enum OverlayActivity { standby, live, paused }
```

| Activity | Meaning | Window renders |
|---|---|---|
| `standby` | Recognition idle or stopped | Theme background, no text. Stopping clears captions: the existing stop path (`recording_screen.dart:81-108` calls `clearSession()`, and `OnScreenCaptionTarget` clears its buffer on the resulting idle state, `on_screen_caption_target.dart:163-170`) empties the source buffer the window mirrors |
| `live` | Recognition active (including while the *broadcast* transport reconnects — recognition itself is not paused) | Final entries + interim, exactly as the main window |
| `paused` | Recognition paused | Last captions stay visible; the `__pause__` marker row renders as in the main window |

Mapped from `BroadcastSessionState` in the main engine:
`BroadcastIdleState` → `standby`; `BroadcastActiveState` → `live`;
`BroadcastPausedState` → `paused`; `BroadcastReconnectingState` → `live`;
`BroadcastStoppedState` → `standby` (transient — the existing listener moves it
to idle in the same callback). **Recognition events change only this value in
the snapshot; they never open or close the window** (D-5). `BroadcastRecordingNotifier`
is not modified by this unit, and there is no "start paused".

---

## CaptionOverlaySnapshot (new, `zip_broadcast`)

The payload the window renders. Travels in the window's creation argument
(within `OverlayWindowLaunch`) and in every `captionUpdate` message.

```dart
class CaptionOverlaySnapshot {
  const CaptionOverlaySnapshot({
    required this.activity,
    required this.entries,   // final captions, oldest first
    this.interim,            // the trailing non-final entry, if any
    required this.settings,  // the broadcaster's DisplaySettings
  });
}
```

| Field | Purpose |
|---|---|
| `activity` | `OverlayActivity` — see above (D-5) |
| `entries` | Final captions, oldest first, capped at the source buffer's `maxBufferSegments` (the target receives `OnScreenCaptionTarget.visibleCaptions`' final portion, `on_screen_caption_target.dart:59-62`) |
| `interim` | The current interim entry, if any — rendered at 0.8 opacity by the shipped `CaptionDisplayWidget` |
| `settings` | The broadcaster's `DisplaySettings` at the moment of the update, so font, size, scroll direction, theme mode and `maxVisibleLines` track the main window live (BR-U8-12) |

The per-input colour map (`sourceColorValues`) of the superseded design is
**removed** (D-7): the window mirrors the main window without per-input
colour, and per-input colour goes to the Backlog. There is no freezed
`fromJson` on this type — `zip_core` models are not serialized by generated
json (D-8); the codec below is hand-written.

`CaptionDisplayEntry` and `DisplaySettings` are shipped `zip_core` models,
consumed as-is. The snapshot is the only permitted carrier of caption text
across the window boundary; it is never stringified into a log, a telemetry
call, or an error message (BR-U8-18).

---

## Snapshot and launch codecs (hand-written, versioned, new)

D-8: a **hand-written, versioned codec in `zip_broadcast`**, following the
`SignalingCodec`/`CaptionWireCodec` precedent (`caption_wire_codec.dart`:
decode returns `null` on malformed input, unknown version, wrong field type or
oversized payload, and **never throws**). No `zip_core` change.

### Wire shape (enums encoded by name)

```
CaptionOverlaySnapshot:
{
  "v": 1,
  "activity": "standby" | "live" | "paused",
  "entries": [ { "key": <string>, "text": <string>, "isFinal": <bool> }, ... ],
  "interim": { "key": <string>, "text": <string>, "isFinal": <bool> } | null,
  "settings": {
    "scrollDirection": <name>,
    "captionTextSize": <name>,
    "captionFont": <name>,
    "themeModeSetting": <name>,
    "maxVisibleLines": <int>
  }
}

OverlayWindowLaunch:
{
  "v": 1,
  "config": { "mode": "externalDisplay", "position": "top" | "bottom" },
  "snapshot": <CaptionOverlaySnapshot shape>
}
```

Rules (B-7):

- **`key` is `CaptionDisplayEntry.entryId`** — the segment ID Phase 8 keys
  translations by (forward note, plan). The overlay side rebuilds
  `CaptionDisplayEntry` with the decoded `key` as `entryId` and **placeholder
  values** for `sessionId`, `sourceId` and `timestamp` (fixed constants);
  `sessionId`/`sourceId` **never cross the boundary** — the window never needs
  them and the placeholder keeps `CaptionDisplayWidget` (which special-cases
  `sourceId == '__pause__'`) working unmodified. The pause marker row travels
  as an entry with its existing key convention, since it is part of the
  mirrored buffer.
- **Decode returns `null`** on malformed input, an unknown `v` (anything but
  `1`), or an unknown enum value — including `position` values other than
  `top`/`bottom` and any `mode` other than `externalDisplay` (the future
  pop-out unit will bump `v` and add its variants).
- **Size guard**: the codec rejects payloads whose UTF-8 byte length exceeds a
  named constant (`maxEncodedBytes`, applied to the full encoded payload
  including nested fields and multibyte characters — the nested-field lesson
  from `CaptionWireCodec`'s `maxEncodedBytes`/`_encodedByteLength`).
- **`v` is the version field Phase 8 will bump** when bilingual mode arrives
  (forward note, plan). Unit 8 adds **no** translation fields (YAGNI).
- `OverlayWindowLaunch` has **exactly one `mode` source**: `config.mode`. The
  superseded shape carried `mode` both directly on the launch and inside
  `config`; that is gone.
- PBT-01: a round-trip property and a malformed-input property (FP-1, FP-2 in
  `business-rules.md`).

`OverlayWindowEntry` (the sub-engine entry point) decodes `args[2]` with the
launch codec. A decode failure renders the fixed "Window unavailable" frame,
logs the fixed string `invalid_window_arguments`, and — because it does not
send `overlayReady` — the main engine's ready timeout converts it to
`OpenFailed` on the main side (BR-U8-03, D-9).

---

## ExternalDisplayStatus (sealed class, new)

The state the controls render. Sealed so the widget's switch is exhaustive.
The seven variants are the state machine of `business-logic-model.md`
(D-4/D-5/D-6):

```dart
sealed class ExternalDisplayStatus {
  const ExternalDisplayStatus();
}

final class Unsupported extends ExternalDisplayStatus { const Unsupported(); }
final class NoDisplays extends ExternalDisplayStatus { const NoDisplays(); }
final class Off extends ExternalDisplayStatus { const Off(); }
final class Opening extends ExternalDisplayStatus { const Opening(); }

final class Open extends ExternalDisplayStatus {
  const Open({required this.activity, required this.displayId});
  final OverlayActivity activity;
  final String? displayId;    // null = primary
}

final class WaitingForDisplay extends ExternalDisplayStatus {
  const WaitingForDisplay({required this.displayId});
  final String displayId;     // the saved id being waited for (D-4)
}

final class Failed extends ExternalDisplayStatus {
  const Failed({required this.reason});
  final String reason;        // fixed code (OpenFailed.reason)
}
```

| Variant | Meaning | Control render (see `frontend-components.md`) |
|---|---|---|
| `Unsupported` | Web, or any platform whose `DesktopWindowService.isSupported` is false | The external display section is not shown (S-20 "Zip Broadcast web is not offered") |
| `NoDisplays` | `displays()` returned an empty list | "No displays detected" copy; toggle disabled |
| `Off` | Capable, output off (always the launch state, D-6) | Display list, selection, caption-position selector, toggle off |
| `Opening` | Window being created; ready handshake pending | List with toggle on, "opening" state; the window shows standby |
| `Open` | Window open on `displayId`, showing `activity` | List with active row, toggle on |
| `WaitingForDisplay` | Selected display disconnected; window closed; output still on (D-4) | Proto-13 disconnected notice plus "waiting for display" status and a **Cancel** action |
| `Failed` | `OpenFailed` (create failed or ready timeout) | Failure banner with fixed copy; toggle returns to off |

The mapping from `OverlayEvent` + `changes` + settings to this state is the
state machine in `business-logic-model.md`.

---

## OverlayWindowController (plain class, new)

The one owner of everything the window does (B-9). A plain class on the
shell's `ProviderContainer` (the app-lifetime service pattern), not a target:

Owns:
- the single secondary **window id** (`int?`);
- the **open guard** that serialises open/close/reframe and refuses a second
  open while one is in progress (BR-U8-01);
- **open/close/reframe** through `DesktopWindowService`
  (`createWindow` → `setFrame` → `show`; close releases per BR-U8-02);
- the **ready handshake** (B-5): installs the main engine's single
  `DesktopMultiWindow.setMethodHandler` *before* the first `createWindow`,
  waits for `overlayReady`, enforces `overlayReadyTimeout`;
- the **display subscription** to `DisplayEnumerator.changes` (D-4's
  close/notify/wait/reopen and BR-U8-09's reframe both key off it);
- the **state machine** (`ExternalDisplayStatus`) and its event stream;
- the latest held snapshot (sent immediately after ready, and on each
  `captionUpdate` trigger from the target).

`OverlayEvent`s and `ExternalDisplayStatus` are emitted here. Nothing else in
the package holds a window id or calls `DesktopWindowService` for the overlay.

---

## CaptionOverlayTarget (modified)

Keeps its Application Design public surface — `show`, `hide`, `events` — as
**thin delegators** to `OverlayWindowController` (B-9), and acts as the
**caption-bus adapter** only:

- `onCaptionEvent(SttResultEvent)` builds the current
  `CaptionOverlaySnapshot` (F-8.4) and asks the controller to push it
  (`captionUpdate`), debounced per animation frame. `SessionStateEvent` never
  produces a snapshot directly — it only affects `activity` through the
  session-state mapping above.
- `show(OverlayConfig)` / `hide()` delegate open/close to the controller (the
  shell drives these from `_syncOverlay`, as today).
- `events` is the controller's `OverlayEvent` stream, re-exposed.
- The Phase 1 `{'text', 'isFinal'}` `captionUpdate` payload is replaced by the
  codec-encoded snapshot (compatibility note: the shipped target's
  `onCaptionEvent` is rewritten; its 10 existing tests are re-pointed, T8).

The target remains the single `CaptionOutputTarget` for this surface on
`CaptionOutputTargetRegistry` — every new type is a collaborator of it or of
the shell, never a parallel target.
