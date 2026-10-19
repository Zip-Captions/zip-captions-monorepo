# Domain Entities — Unit 8: External Display (S-20)

New and modified types for the external display target and the pop-out window it
becomes. `zip_broadcast` only; nothing here is added to `zip_core`, because no
other app constructs display or overlay windows.

The Application Design fixed the *names* (`DisplayEnumerator`,
`ScreenRetrieverDisplayEnumerator`, `DisplayInfo`, `OverlayWindowEntry`,
`OverlayWindowApp`, the `OutputTargetSettings` display field) and the analyzer
methods (`displays()`, `changes`, `events`). It did not fix field lists or
serialization shapes. Those are settled here and must not be re-decided at Code
Generation.

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
| `id` | `String` | Non-empty, opaque, stable for the lifetime of the display | Persisted selection key (`OutputTargetSettings.externalDisplayId`) |
| `label` | `String` | May be empty | Shown in `ExternalDisplayControls`; falls back to "Display N" copy in the UI |
| `bounds` | `Rect` | Logical pixels, origin at the global desktop origin, top-left based | Used verbatim as the overlay window's `setFrame` rectangle |
| `scaleFactor` | `double` | `> 0` | Description only (shown as "2880×1620 (2x)"); never used to compute a frame |
| `isPrimary` | `bool` | Exactly one `true` in a non-empty list | "Primary display" copy and the default selection |

`Rect` is `dart:ui`'s, re-exported by `package:flutter/material.dart`. `dart:ui`
`Rect` is top-left-origin, which is the coordinate space Windows and Linux use
natively and the space the macOS bridge converts into. No bottom-left flip is
performed in Dart.

**`id` provenance.** `screen_retriever` 0.2.x's `Display.id` is a non-empty
string on every desktop platform (Windows and macOS derive it from the platform
display handle; Linux from the X11 output number) and is what
`DesktopMultiWindow`-style placement needs. The adapter must not invent ids;
it passes the plugin's `id` through unchanged, so ids stay stable across app
restarts and the persisted selection survives a relaunch.

**Label provenance.** `screen_retriever` 0.2.x does not expose a user-assigned
display name on all three platforms (macOS and Linux report `name == id`). The
adapter passes whatever `name` the plugin returns; the UI owns the fallback
copy. This is the reason `label` is allowed to be empty and is never used as a
key.

---

## DisplayEnumerator (abstract interface, new)

Fixed by Application Design §7; restated here for the contract this unit
implements against.

```dart
abstract interface class DisplayEnumerator {
  Future<List<DisplayInfo>> displays();
  Stream<List<DisplayInfo>> get changes;
  Future<void> dispose();
}
```

`dispose()` is the only addition. A long-lived `Stream` that a plugin backs with
a native observer needs an explicit release point, and the shipped
`CaptionOutputTarget.dispose()` contract already gives callers one to call. It
is idempotent.

### Display-change event contract (BR-U8-02 .. BR-U8-05)

`changes` is a **broadcast** stream.

| Property | Contract |
|---|---|
| First emission | The current display list, delivered to a listener that subscribes at any time — not only to listeners present before the first platform event. Implemented with a platform-listener subscription started on the first Dart listener and a replayed latest value. |
| Emission on connect | A list containing the new display, in platform order. |
| Emission on disconnect | A list without the removed display. |
| Emission on rearrangement | A list with the same ids but different `bounds`/`isPrimary`. Consumers must not treat a same-id list as "no change" — see the rule below. |
| No change | No emission. The platform observer already supplies that; the adapter does not synthesise a periodic poll. |
| Error | A platform failure is **logged at `warning` with a fixed string** and the stream does **not** emit an error and does **not** close. A transient platform hiccup must not kill the fallback listener (S-20 "falls back gracefully"). |
| Close | Only on `dispose()`. |
| Threading | Events are delivered on the Dart event loop; no reentrancy guarantees are made. |
| Duplicate suppression | Adjacent equal lists (`==` over id, label, bounds, scaleFactor, isPrimary) are coalesced. A same-id list with changed geometry is **not** equal and is emitted. |

`ScreenRetrieverDisplayEnumerator` maps `screen_retriever`'s
`getAllDisplays()`/`displayChangedNotifier` onto this contract. The plugin's
own API shape (including any version-specific detail) is confined to that one
file; `DisplayEnumerator` is the only type the rest of the package sees.

---

## OverlayWindowMode (sealed class, new)

The two intents one window component serves. `pip-ux-parity.md` §8.7 leaves the
"one component or two" question to this design; this is the answer — one
component, two modes.

```dart
sealed class OverlayWindowMode {
  const OverlayWindowMode();
}

final class ExternalDisplayMode extends OverlayWindowMode {
  const ExternalDisplayMode({this.displayId});
  final String? displayId;          // null = primary display
}

final class PopOutMode extends OverlayWindowMode {
  const PopOutMode();
}
```

| Variant | Surface | Placement | Always on top | Close semantics |
|---|---|---|---|---|
| `ExternalDisplayMode` | The selected display, full display bounds | `bounds` of the selected `DisplayInfo`, else primary | Yes (BR-U8-09) | Closing it switches `externalDisplayEnabled` off, which is the "the broadcaster disables the output" path with a window-manager gesture instead of the toggle |
| `PopOutMode` | A 640x320 window (UX-PIP-10) | Centred on the display containing the main window at open time; the user moves it | Yes (UX-PIP-11) | Closing it clears "popped out" in the main window (BR-U8-10 / BR-PIP-03) |

The two modes are mutually exclusive at any instant. They are not separate
window classes, entry points, or caption transports: see
`business-logic-model.md` F-8.1.

---

## OverlayConfig (freezed, modified)

Shipped in Phase 1 with `targetDisplayId`, `position`, `opacity`. The window
component needs to know which mode it is in and, in pop-out mode, its size.

```dart
@freezed
abstract class OverlayConfig with _$OverlayConfig {
  const factory OverlayConfig({
    @Default(ExternalDisplayMode()) OverlayWindowMode mode,
    @Default(OverlayPositionBottom()) OverlayPosition position,
    @Default(0.9) double opacity,
    @Default(Size(640, 320)) Size popOutSize,
    @Default(Size(320, 180)) Size popOutMinimumSize,
  }) = _OverlayConfig;
}
```

| Change | Compatibility |
|---|---|
| `targetDisplayId` is replaced by `mode` | `const OverlayConfig()` still compiles and still means "primary display, bottom, 0.9". The one shipped call site is the default construction in `CaptionOverlayTarget.show()`; there is no other producer. |
| `popOutSize` / `popOutMinimumSize` are new | Defaults match UX-PIP-10 ("640x320, resizable, with a sensible minimum size", §8.8 item 13). |

`position` keeps its Phase 1 meaning unchanged: where the caption text sits
inside the surface, not where the window is on the desktop. That is a Phase 1
contract (`BR-U3-33` .. `BR-U3-35`) and this unit does not reinterpret it.

---

## OverlayEvent (sealed class, new)

Fixed by Application Design as `Stream<OverlayEvent> get events;` with
`DisplayLost` named. The full set, because the UI must distinguish "the window
went away" from "the display went away":

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
| `DisplayLost` | The selected display disappeared from `changes` while visible | Notify the broadcaster (S-20); the target has already moved to the fallback described in BR-U8-06 |
| `WindowClosed` | The sub-window was closed by any means that disables the output — the OS close button in either mode, or a cascade-caused close | Clear the mode's "open" state in `OutputTargetSettings`; the shell's existing `_syncOverlay` path then deregisters the target |
| `OpenFailed` | `createWindow` threw, or the entry point reported a parse failure for the config argument | Notify the broadcaster with a fixed copy; settings are not switched on (BR-U8-08) |

`OpenFailed.reason` is a short fixed code (`create_failed`,
`invalid_window_arguments`). No configuration JSON, display label, or caption
text is ever placed in it (BR-U8-18).

---

## OutputTargetSettings (freezed, modified)

Adds three persisted fields; the existing five are unchanged.

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
    @Default(false) bool popOutEnabled,
    String? popOutDisplayId,                      // optional preference
  }) = _OutputTargetSettings;
}
```

| Field | Default | Persistence key | Purpose |
|---|---|---|---|
| `overlayEnabled` | `false` | `output.overlayEnabled` (unchanged) | External display output on/off. Kept under its shipped name and key so a user who had turned the Phase 1 overlay on before this unit shipped keeps that preference and gets the completed feature, not a reset. The model field keeps the name; every new UI label says "external display" per S-20. |
| `externalDisplayId` | `null` | `output.externalDisplayId` | Selected `DisplayInfo.id`; `null` means primary. A value no longer present at load time is kept as-is and resolved at open time (BR-U8-07). |
| `popOutEnabled` | `false` | `output.popOutEnabled` | The pop-out is open. Persisted because the shell restarts the target from settings (as it already does for every other target), but never auto-opened at launch (BR-PIP-10). |
| `popOutDisplayId` | `null` | `output.popOutDisplayId` | Optional preference for where the pop-out centres. Permitted, not required (`pip-ux-parity.md` §8.9). |

---

## CaptionOverlaySnapshot (freezed, new)

The payload `OverlayWindowApp` renders. It travels in the window's creation
argument and in every `invokeMethod('captionUpdate', ...)` call, replacing the
Phase 1 `{'text', 'isFinal'}` map.

```dart
@freezed
abstract class CaptionOverlaySnapshot with _$CaptionOverlaySnapshot {
  const factory CaptionOverlaySnapshot({
    @Default(<CaptionDisplayEntry>[]) List<CaptionDisplayEntry> entries,
    CaptionDisplayEntry? interim,
    @Default(<String, AudioInputVisualStyle>{})
    Map<String, AudioInputVisualStyle> styles,
    required DisplaySettings settings,
  }) = _CaptionOverlaySnapshot;

  factory CaptionOverlaySnapshot.fromJson(Map<String, dynamic> json) =>
      _$CaptionOverlaySnapshotFromJson(json);
}
```

| Field | Purpose |
|---|---|
| `entries` | Final captions, oldest first, capped at `maxBufferSegments` of the source buffer (the target receives `OnScreenCaptionTarget.visibleCaptions`' final portion) |
| `interim` | The current interim entry, if any — rendered at 0.8 opacity by the shipped `CaptionDisplayWidget` |
| `styles` | `entry.sourceId` → the Phase 1 per-input style the broadcaster configured; the pop-out has no access to `AudioInputSettingsProvider` |
| `settings` | The broadcaster's `DisplaySettings` at the moment of the update, so font, size, scroll direction and theme mode track the main window live (BR-U8-12) |

`CaptionDisplayEntry` and `DisplaySettings` are shipped `zip_core` models. The
snapshot is the only permitted carrier of caption text across the window
boundary; it is never stringified into a log, a telemetry call, or an error
message (BR-U8-18).

---

## OverlayWindowLaunch (freezed + JSON, new)

The creation argument. Parsed by `OverlayWindowEntry` in the secondary engine.

```dart
@freezed
abstract class OverlayWindowLaunch with _$OverlayWindowLaunch {
  const factory OverlayWindowLaunch({
    required OverlayWindowMode mode,
    required OverlayConfig config,
    required CaptionOverlaySnapshot snapshot,
  }) = _OverlayWindowLaunch;

  factory OverlayWindowLaunch.fromJson(Map<String, dynamic> json) => ...
}
```

`OverlayWindowMode` (sealed) has no JSON representation, so the codec is
hand-written in the adapter (a `logger`-free, `dart:convert`-based codec beside
`OverlayWindowLaunch`), returning `null` on any malformed input — the same
"codec returns null, caller drops" rule the project applies to
`SignalingCodec` and `CaptionWireCodec`. A malformed launch argument must not
crash the secondary engine; the entry point renders a fixed failure frame and
logs `invalid_window_arguments` (BR-U8-08).

---

## ExternalDisplayStatus (sealed class, new)

The state `ExternalDisplayControls` renders. Sealed so the widget's switch is
exhaustive.

```dart
sealed class ExternalDisplayStatus {
  const ExternalDisplayStatus();
}

final class ExternalDisplayUnsupported extends ExternalDisplayStatus {
  const ExternalDisplayUnsupported();
}

final class ExternalDisplayIdle extends ExternalDisplayStatus {
  const ExternalDisplayIdle();
}

final class ExternalDisplayActive extends ExternalDisplayStatus {
  const ExternalDisplayActive({required this.displayId, required this.isFallback});
  final String? displayId;
  final bool isFallback;
}

final class ExternalDisplayLost extends ExternalDisplayStatus {
  const ExternalDisplayLost({required this.displayId});
  final String displayId;
}

final class ExternalDisplayFailed extends ExternalDisplayStatus {
  const ExternalDisplayFailed({required this.reason});
  final String reason;
}

final class ExternalDisplayNoDisplays extends ExternalDisplayStatus {
  const ExternalDisplayNoDisplays();
}
```

| Variant | Meaning | Control render |
|---|---|---|
| `Unsupported` | Web, or any platform whose `DesktopWindowService.isSupported` is false | The external display section is not shown (S-20 "Zip Broadcast web is not offered") |
| `Idle` | Capable, not enabled | Display list, selection, toggle off |
| `Active` | Enabled and open on `displayId` | List with active row, toggle on, `isFallback` shows the "moved to the primary display" note |
| `Lost` | The selected display disappeared and no fallback could keep a sane position | Proto-13's disconnected banner; the toggle stays on |
| `Failed` | `OpenFailed` | Proto-13 banner variant with fixed copy; toggle returns to off |
| `NoDisplays` | `displays()` returned an empty list | "No displays detected" copy; toggle disabled |

The mapping from `OverlayEvent` + `changes` + settings to this state is
F-8.4.