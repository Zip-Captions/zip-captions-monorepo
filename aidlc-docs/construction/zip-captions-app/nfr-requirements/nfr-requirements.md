# NFR Requirements — Unit 5: Zip Captions App

**Unit**: Unit 5: Zip Captions App (S-09)
**Stage**: NFR Requirements
**Status**: COMPLETE

---

## FD Updates Required

Three FD decisions are revised by the NFR assessment below and must be reflected in
implementation:

| Rule / Component | Original FD | Revised |
|---|---|---|
| BR-U5-18 (SearchBar `onChanged`) | Directly updates `transcriptSearchQueryProvider` on every keystroke | **Superseded by PERF-U5.1** — debounced 300ms before updating provider (NFR-DQ1=B) |
| BLM §5 RecordingScreen nav listener | `context.go('/history')` | **Add**: `ref.invalidate(transcriptSessionListProvider)` before navigating (REL-U5.1) |
| BLM §8 `_runExport()` | No file cleanup | **Add**: delete temp file after share/save completes (SEC-U5.2 + REL-U5.2) |

---

## Design Questions

| # | Question | Options | Answer |
|---|----------|---------|--------|
| NFR-DQ1 | SearchBar debounce strategy | A = no debounce; B = 300ms debounce in widget; C = 500ms | **B** |
| NFR-DQ2 | HistoryScreen refresh after session end | A = `ref.invalidate` in RecordingScreen nav listener; B = watch `RepositoryEvent` stream | **A** |
| NFR-DQ3 | Export file location and cleanup | A = temp dir, clean up after share/save; B = documents dir, no cleanup | **A** |

---

## 1. Performance

### PERF-U5.1: SearchBar — 300ms Keystroke Debounce (NFR-DQ1=B)

The HistoryScreen `SearchBar.onChanged` handler must not directly update
`transcriptSearchQueryProvider` on every keystroke. Instead, a 300ms debounce `Timer`
is applied: each keystroke resets the timer; the provider is only updated when 300ms
elapses without further input.

**Rationale**: FTS5 is fast (PERF-U3.2 target ≤500ms), but rapid typing (typical: 5–10
keystrokes per second) would still issue redundant database queries for every intermediate
string. A 300ms window collapses a burst of keystrokes into a single query, matching the
latency users expect from live search UI.

**Implementation**: Debounce `Timer?` is a local `State` field of the `HistoryScreen`
`StatefulWidget` (or `ConsumerStatefulWidget`). `onChanged` calls `_timer?.cancel()` then
starts `Timer(Duration(milliseconds: 300), () => ref.read(...).state = value)`. The
timer is cancelled in `dispose()`.

**Constraint**: The debounce applies only to the `transcriptSessionListProvider` trigger.
The visual search field text updates instantly (it is controlled by a local `TextEditingController`,
not by `transcriptSearchQueryProvider`).

**Verification**: Widget test: type a 3-character query character by character with 50ms
between each; assert `transcriptSessionListProvider` is only called once (after 300ms
silence), not 3 times.

---

### PERF-U5.2: TranscriptViewerScreen — Lazy Segment Rendering

`TranscriptViewerScreen` must use `ListView.builder` (not `ListView` with static children)
for segment rendering. Long sessions may produce thousands of segments; eager build would
cause jank on navigation.

**No test required** — this is a structural constraint on the widget implementation that
is enforced by code review. `ListView.builder` is already specified in the FD BLM.

---

### PERF-U5.3: CaptionDisplayWidget — Auto-Scroll via Post-Frame Callback

Auto-scroll in `CaptionDisplayWidget` must use `WidgetsBinding.instance.addPostFrameCallback`
(not synchronous scroll calls). Calling `scrollController.animateTo()` during a build
can trigger frame scheduling conflicts.

**Verification**: Manual testing — captions arrive at maximum STT rate (post-debounce,
≤1 per 50ms) without visible scroll lag or dropped frames on a mid-range device.

---

## 2. Security

### SEC-U5.1: No Transcript Text in Screen Layer Logs (SECURITY-03 Extension)

Extends BR-U5-26 to an NFR-level enforcement requirement. No Unit 5 widget, screen, or
provider may include the following in log output, debug assertions, or exception messages:

- `TranscriptSegment.text`
- `TranscriptSession.title`
- `CaptionDisplayEntry.text`
- Any search query string typed by the user

**Permitted in logs**: `sessionId`, `segmentId`, item counts, navigation events, state
names (e.g., `StoppedState`), error types, stack traces.

**Verification**: Code review of all `debugPrint`, `log()`, and `Logger` call sites in
Unit 5 files. Mandatory review item in Code Generation — cannot be automated.

---

### SEC-U5.2: Export Temp File Cleanup (NFR-DQ3=A)

`exportSession()` writes the formatted transcript to `getTemporaryDirectory()`. After
the share/save operation completes (success or failure), the temp file must be deleted.

**Why temp dir**: Temp files are OS-managed and do not appear in the user's documents.
They are appropriate for ephemeral export artefacts.

**Cleanup rule**: `_runExport()` calls `File(path).delete(recursive: false)` in a
`finally` block after the share/save call. This ensures cleanup even if the share flow
throws.

**Verification**: Unit test — mock `TranscriptRepository.exportSession()` to return a
known temp path; assert the file is deleted after `_runExport()` completes, both on the
success path and after a simulated share failure.

---

## 3. Reliability

### REL-U5.1: HistoryScreen Refresh After Session End (NFR-DQ2=A)

When `RecordingStateNotifier` transitions to `StoppedState`, the `RecordingScreen`
`ref.listen` handler must call `ref.invalidate(transcriptSessionListProvider)` before
calling `context.go('/history')`. This ensures the HistoryScreen's
`transcriptSessionListProvider` rebuilds and includes the just-completed session.

**Why A over B**: Option B (watching a `RepositoryEvent` stream) adds reactive coupling
between the repository layer and the provider layer that is not needed elsewhere. A
targeted invalidate at the known transition point is simpler and eliminates the need for
a new stream subscription.

**Ordering**: Invalidation before navigation; the HistoryScreen first frame triggers a
fresh `transcriptSessionListProvider` async load.

**Verification**: Widget test — stub `RecordingStateNotifier` to emit `StoppedState`;
assert `transcriptSessionListProvider` is invalidated (inspect rebuild count or mock
repository call count) and navigation occurs to `/history`.

---

### REL-U5.2: Export Error Resilience

`_runExport()` wraps the entire export pipeline (file write + share/save) in a
`try/on Object` block per BR-U5-25. The SnackBar message must be shown on the
`ScaffoldMessenger` of the `TranscriptViewerScreen`'s context. The temp file cleanup
from SEC-U5.2 runs in a `finally` block, ensuring no orphaned temp files even when the
catch path executes.

**Verification**: Widget test — mock `exportSession()` to throw; assert the SnackBar
appears and no temp file is left on disk.

---

### REL-U5.3: Session-Not-Found Guard

`TranscriptViewerScreen` must handle `transcriptSessionProvider(id)` resolving to `null`
with a recoverable error UI (per BR-U5-19). This path is reachable when:

- The user navigates to a deep link for a deleted session.
- A concurrent delete (via HistoryScreen) occurs while the viewer is open.

**Implementation**: The `data` branch of the `sessionAsync.when()` call checks
`session == null` and renders `_SessionNotFoundWidget` with a back button calling
`context.pop()`.

**Verification**: Widget test — provide a `transcriptSessionProvider` override that
returns `null`; assert the not-found UI is shown, not an unhandled error.

---

## 4. Testing

### TEST-U5.1: Screen Widget Tests with ProviderScope Overrides

Each of the 5 screens is covered by at least one widget test. Tests use
`ProviderScope(overrides: [...])` to replace:

- `recordingStateNotifierProvider` with a stub notifier
- `transcriptSessionListProvider(query)` with a stub async value
- `transcriptSessionProvider(id)` and `transcriptSegmentsProvider(id)` with stub values
- `transcriptRepositoryProvider` with a mock (for delete + export paths)
- `displaySettingsNotifierProvider` with a stub notifier

**Coverage targets**:
| Screen | Tests |
|--------|-------|
| HomeScreen | Idle state (Start only), Paused state (Start + Resume), Settings nav tap |
| RecordingScreen | Recording controls per state, AppearancePanel toggle, auto-nav on StoppedState |
| SettingsScreen | Settings tiles render; toggle `captureEnabled` calls notifier |
| HistoryScreen | Session list renders, empty state, delete action, search debounce behaviour |
| TranscriptViewerScreen | Session found + segments, session not found, export sheet opens |

---

### TEST-U5.2: CaptionDisplayWidget — Unit Widget Tests

`CaptionDisplayWidget` lives in `zip_core` and is tested independently of any screen.

| Test | Assertion |
|------|-----------|
| Renders entries in index order (oldest first) | Item at position 0 contains text from `entries[0]` |
| Interim entry rendered at `opacity: 0.8` | `Opacity` widget wraps interim text |
| Final entry rendered at `opacity: 1.0` | No `Opacity` reduction on final entries |
| Empty entries list renders without error | No exception; empty `ListView` |

---

### TEST-U5.3: `transcriptSessionListProvider` Unit Tests

Tests target the provider in isolation using `ProviderContainer` with a mocked
`transcriptRepositoryProvider`.

| Test | Assertion |
|------|-----------|
| Empty query → calls `getSessions()` | Mock `getSessions` invoked; `search` not invoked |
| Whitespace query → calls `getSessions()` | `'  '` treated as empty |
| Non-empty query → calls `search(trimmed)` | Mock `search` invoked with trimmed string |
| Search results mapped to sessions | Returns `[result.session]`, not full `TranscriptSearchResult` |
| `ref.invalidate(transcriptSessionListProvider)` triggers rebuild | Second `getSessions` call observed |

---

### TEST-U5.4: Navigation Tests

Navigation is tested via `GoRouter`'s `GoRouterHelper` test utilities or a wrapped
`MaterialApp.router` with a real `GoRouter` instance.

| Test | Assertion |
|------|-----------|
| HomeScreen Start button → `/recording` | Route changes to `/recording` |
| RecordingScreen StoppedState → `/history` | Route changes to `/history` |
| HistoryScreen tile tap → `/history/:id` | Route changes to `/history/{sessionId}` |
| TranscriptViewerScreen back → `/history` | Route pops to `/history` |

---

## 5. Maintainability

### MAINT-U5.1: Platform Guard for Export — Use `defaultTargetPlatform`

Export platform branching must use `defaultTargetPlatform` (not `Platform.isIOS` /
`Platform.isAndroid`, which throw on web). The guard:

```dart
if (defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android) {
  // share_plus
} else {
  // file_selector
}
```

Zip Captions targets iOS, Android, macOS, and Windows. The `else` branch covers macOS
and Windows. Web is not a current target but this guard is web-safe.

---

### MAINT-U5.2: go_router ShellRoute API Stability

`go_router ^14.0.0` is already pinned in the FD. No additional constraint. The
`ShellRoute` API has been stable since go_router v9; the `^14.0.0` constraint allows
compatible patch/minor updates.

---

### MAINT-U5.3: `transcriptSearchQueryProvider` Scope Isolation

`transcriptSearchQueryProvider` is declared in `zip_captions` and must not be imported
by `zip_core`. It is a UI-local state concern; no core business logic should depend on
the search query string.

---

## Tech Stack Decisions

| Package | Version | Location | Purpose |
|---------|---------|----------|---------|
| `go_router` | `^14.0.0` | `zip_captions` | ShellRoute routing (confirmed from FD) |
| `share_plus` | `^11.0.0` | `zip_captions` | OS share sheet on iOS/Android |
| `file_selector` | `^1.0.0` | `zip_captions` | Save-file dialog on macOS/Windows |

No new `zip_core` packages required.

---

## Extension Compliance Summary

| Rule | Status | Notes |
|------|--------|-------|
| SECURITY-03 (no transcript text in logs) | **Compliant** | SEC-U5.1 enforces for all Unit 5 components |
| PERF-U3.1 (50ms caption debounce) | **Inherited** | OnScreenCaptionTarget handles this; CaptionDisplayWidget is a passive consumer |
| REL-U2.1 (auto-restart) | **Inherited** | RecordingStateNotifier handles this; screens observe state only |
| MAINT-U3.2 (logger naming) | **N/A for screens** | Screen layer uses `debugPrint` for development only; no structured logging in widget code |
