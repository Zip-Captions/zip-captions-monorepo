# Business Rules — Unit 5: Zip Captions App

**Unit**: Unit 5: Zip Captions App (S-09)
**Stage**: Functional Design
**Status**: COMPLETE

---

## Navigation (BR-U5-01 .. BR-U5-05)

**BR-U5-01** — When `recordingStateNotifierProvider` transitions to `StoppedState`,
`RecordingScreen` automatically navigates to `/history` via `context.go('/history')`.
This transition is driven by `ref.listen` (not `ref.watch`) to avoid widget rebuilds
triggering navigation.

**BR-U5-02** — `HomeScreen` shows a "Resume" button only when `recordingStateNotifierProvider`
is in `PausedState`. The button routes to `/recording`. When state is `IdleState`,
only the "Start" button is visible. Other states (recording, reconnecting, stopped) are
treated the same as idle for HomeScreen display purposes — the user cannot reach HomeScreen
while actively recording under normal navigation.

**BR-U5-03** — Settings is not a primary navigation destination. It is accessible only
via an `IconButton` in the `AppBar` (both mobile and desktop breakpoints). Pressing the
Settings icon navigates to `/settings` via `context.go('/settings')`.

**BR-U5-04** — `_isTabBarScreen(String location)` returns `true` if and only if
`location == '/'` or `location == '/history'`. All other locations (`/recording`,
`/settings`, `/history/:id`) return `false`. This function is the single source of truth
for shell widget switching.

**BR-U5-05** — The back button within `TranscriptViewerScreen` navigates to `/history`
(the parent route). Because `TranscriptViewerScreen` is a nested `GoRoute` under
`/history`, `context.pop()` naturally restores the history list. The shell rail/drawer
remains visible throughout — the screen is inside the `ShellRoute`.

---

## Shell Layout (BR-U5-06 .. BR-U5-08)

**BR-U5-06** — At widths > 768px, `ZcAppShell` renders a persistent `NavigationRail`
on the left. The rail always shows all 3 primary destinations: Home (`/`),
Caption (`/recording`), History (`/history`). Settings is not in the rail.

**BR-U5-07** — At widths ≤ 768px on a tab-bar screen (`_isTabBarScreen == true`),
`ZcAppShell` renders a `BottomNavigationBar` with 2 items: Home and History.
An `AppBar` with a Settings `IconButton` in `actions` is always present on mobile.

**BR-U5-08** — At widths ≤ 768px on a drawer screen (`_isTabBarScreen == false`),
`ZcAppShell` renders an `AppBar` with a hamburger `leading` button and no
`BottomNavigationBar`. The hamburger button calls `Scaffold.of(context).openDrawer()`.
The `ZcNavDrawer` contains all 4 navigable targets: Home, Caption, History, Settings.

---

## AppearancePanel (BR-U5-09 .. BR-U5-11)

**BR-U5-09** — `AppearancePanel` is a floating positioned widget rendered in a `Stack`
above `CaptionDisplayWidget` inside `RecordingScreen`. It is not a dialog or bottom sheet.
Its visibility is controlled by a `useState<bool>` local hook (or equivalent `StatefulWidget`
field `_showAppearancePanel`). Initial value: `false`.

**BR-U5-10** — Pressing the appearance `FloatingActionButton` (🔡) toggles
`_showAppearancePanel`. Tapping anywhere outside the panel (on the `CaptionDisplayWidget`
area) also sets `_showAppearancePanel = false`. A `GestureDetector` wrapping the
caption area handles the outside-tap dismiss.

**BR-U5-11** — Changes made in `AppearancePanel` (text size, font, scroll direction)
take immediate effect via `displaySettingsNotifierProvider`. There is no "Apply" button.
The panel stays open until explicitly dismissed per BR-U5-10.

---

## Caption Display (BR-U5-12 .. BR-U5-14)

**BR-U5-12** — `CaptionDisplayWidget` renders `CaptionDisplayEntry` items from
`onScreenCaptionTargetProvider` in the order provided by the target:
oldest-first (index 0 at list start). When `DisplaySettings.scrollDirection` is
`ScrollDirection.bottomToTop`, the widget scrolls to the last item automatically
on each update. When `ScrollDirection.topToBottom`, it scrolls to the first item.

**BR-U5-13** — Interim caption entries (`CaptionDisplayEntry.isFinal == false`) are
rendered with `Opacity(opacity: 0.8)` to visually distinguish them from committed text.
Final entries render at full opacity.

**BR-U5-14** — `CaptionDisplayWidget` resides in `zip_core` at
`packages/zip_core/lib/src/widgets/caption_display_widget.dart` and is exported from
`package:zip_core/zip_core.dart`. It is used identically by `RecordingScreen` in both
the `zip_captions` and `zip_broadcast` apps.

---

## History Screen — Search (BR-U5-15 .. BR-U5-18)

**BR-U5-15** — When `transcriptSearchQueryProvider` holds an empty string (or whitespace
only), `transcriptSessionListProvider('')` calls `TranscriptRepository.getSessions()`
and returns sessions ordered by date descending.

**BR-U5-16** — When `transcriptSearchQueryProvider` holds a non-empty trimmed string,
`transcriptSessionListProvider(query)` calls `TranscriptRepository.search(query)` and
maps `List<TranscriptSearchResult>` to `List<TranscriptSession>` (via `result.session`)
preserving BM25 relevance order (most relevant first).

**BR-U5-17** — Deleting a session from `HistoryScreen` calls
`TranscriptRepository.deleteSession(sessionId)` directly (via the repository accessed
from `transcriptRepositoryProvider`) and then calls
`ref.invalidate(transcriptSessionListProvider)` to refresh the list. No optimistic
removal is performed — the list rebuilds after the async delete completes.

**BR-U5-18** — The search bar is always visible in the `AppBar.bottom` slot of
`HistoryScreen`. It is not hidden behind a search icon. The `SearchBar` widget calls
`ref.read(transcriptSearchQueryProvider.notifier).state = value` on each `onChanged`
event.

---

## Transcript Viewer (BR-U5-19 .. BR-U5-21)

**BR-U5-19** — `TranscriptViewerScreen` displays an error state if
`transcriptSessionProvider(sessionId)` resolves to `null`. The error state shows a
message ("Session not found") and a back button navigating to `/history`. This handles
edge cases such as concurrent deletion.

**BR-U5-20** — Segments are displayed in ascending `startTimeMs` order (earliest first).
This matches the natural reading order of a transcript.

**BR-U5-21** — The export button in the `AppBar` of `TranscriptViewerScreen` is always
visible regardless of recording state. Historical sessions are independent of active
recording.

---

## Export (BR-U5-22 .. BR-U5-25)

**BR-U5-22** — `ExportFormatSheet` is shown via `showModalBottomSheet` when the user
taps the export button. It presents three choices: TXT, SRT, VTT. Tapping a choice
calls `TranscriptRepository.exportSession(sessionId, format)`, then dismisses the sheet
and triggers the platform share/save flow.

**BR-U5-23** — On iOS and Android, the export file path is passed to `SharePlus.instance.share(XFile(path))` from the `share_plus` package. This invokes the OS share sheet.

**BR-U5-24** — On macOS, Windows, and Linux, a save-file dialog is shown using
`getSaveLocation()` from the `file_selector` package. The initial suggested file name is
`{session_title}_{date}.{ext}` where `{session_title}` is the first 20 characters of
`TranscriptSession.title` (sanitised for filesystem), `{date}` is
`yyyy-MM-dd`, and `{ext}` is the format extension (`txt`, `srt`, `vtt`). If the user
cancels, no action is taken.

**BR-U5-25** — The export flow is fire-and-forget from the UI perspective. Errors
(e.g., write failure, share failure) are surfaced as a `ScaffoldMessenger` SnackBar
with a generic error message. No retry mechanism is provided.

---

## Security (BR-U5-26)

**BR-U5-26** — `TranscriptSegment.text` and `TranscriptSession.title` must never
appear in debug logs, analytics, or crash reports emitted by any Unit 5 component.
This extends SECURITY-03 (Units 1–3) to the screen layer. Widget rebuilds triggered
by caption or transcript data must not log the data values.
