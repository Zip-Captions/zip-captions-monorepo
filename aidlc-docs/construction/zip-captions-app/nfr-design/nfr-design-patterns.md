# NFR Design Patterns — Unit 5: Zip Captions App

**Unit**: Unit 5: Zip Captions App (S-09)
**Stage**: NFR Design
**Status**: COMPLETE

---

## Design Question Answers

| Question | Answer | Summary |
|----------|--------|---------|
| NFR-DQ1 | B | 300ms debounce Timer in HistoryScreen State; TextEditingController drives the visual field |
| NFR-DQ2 | A | `ref.invalidate(transcriptSessionListProvider)` called in RecordingScreen nav listener before `context.go('/history')` |
| NFR-DQ3 | A | Write to `getTemporaryDirectory()`; delete in `finally` block after share/save |

---

## Pattern 1: SearchBar Debounce (PERF-U5.1, NFR-DQ1=B)

### Problem

`SearchBar.onChanged` fires on every keystroke. Updating `transcriptSearchQueryProvider`
directly on each call would trigger an FTS5 query per character, wasting database I/O
and causing the provider to rebuild mid-word.

### Pattern

`HistoryScreen` becomes a `ConsumerStatefulWidget`. State holds a `TextEditingController`
(drives the visible text field instantly) and a `Timer?` (debounce handle). The
`transcriptSearchQueryProvider` is only updated after 300ms of silence.

### Implementation

```dart
class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(transcriptSearchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query    = ref.watch(transcriptSearchQueryProvider);
    final sessions = ref.watch(transcriptSessionListProvider(query));
    ...
    SearchBar(
      controller: _searchController,
      onChanged: _onSearchChanged,
    )
    ...
  }
}
```

### Key Points

- `_searchController` and `transcriptSearchQueryProvider` can diverge transiently
  (during the 300ms window). This is intentional and harmless — the provider drives
  the list; the controller drives the text field UI only.
- On screen dispose, `_debounceTimer?.cancel()` prevents a post-dispose state update.
- Clearing the search field (`_searchController.clear()`) must also reset the provider:
  `ref.read(transcriptSearchQueryProvider.notifier).state = ''`.

---

## Pattern 2: History Refresh After Session End (REL-U5.1, NFR-DQ2=A)

### Problem

When a recording session ends, `TranscriptWriterTarget` has already persisted the
session and its segments to `TranscriptRepository`. But `transcriptSessionListProvider`
is cached by Riverpod and will not re-fetch until invalidated.

### Pattern

The `ref.listen` in `RecordingScreen` that triggers navigation invalidates the provider
before navigating:

```dart
ref.listen(recordingStateNotifierProvider, (previous, next) {
  if (next is StoppedState && context.mounted) {
    ref.invalidate(transcriptSessionListProvider);  // REL-U5.1
    context.go('/history');
  }
});
```

### Key Points

- `ref.invalidate(transcriptSessionListProvider)` invalidates all family instances
  (Riverpod invalidates the entire family when given the root provider). This is correct
  — we want the full list refreshed regardless of the current search query.
- Invalidation before navigation means the HistoryScreen's first `build` will trigger
  a fresh async load, showing a loading indicator briefly before the list appears.
  This is acceptable — the session list may have changed.
- No race condition risk: the nav listener fires after `StoppedState` is emitted, which
  happens after `TranscriptWriterTarget` has received `SessionStateEvent(stopped)` and
  called `finalizeSession()`.

---

## Pattern 3: Export Temp File (SEC-U5.2 + REL-U5.2, NFR-DQ3=A)

### Problem

`TranscriptRepository.exportSession()` must write the formatted transcript somewhere
before sharing or saving it. The location must not pollute the user's documents, and the
file must be cleaned up after the transfer.

### Pattern

`exportSession()` writes to `getTemporaryDirectory()`. The caller (`_runExport()`)
deletes the file in a `finally` block.

### Implementation

```dart
Future<void> _runExport(
  BuildContext context,
  WidgetRef ref,
  ExportFormat format,
) async {
  String? path;
  try {
    final repo = await ref.read(transcriptRepositoryProvider.future);
    path = await repo.exportSession(sessionId, format);

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      await SharePlus.instance.share(XFile(path));
    } else {
      final location = await getSaveLocation(
        suggestedName: _exportFileName(sessionId, format),
        acceptedTypeGroups: [_typeGroupFor(format)],
      );
      if (location != null) {
        await File(path).copy(location.path);
      }
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed. Please try again.')),
      );
    }
  } finally {
    if (path != null) {
      try {
        await File(path).delete();
      } on Object {
        // Best-effort cleanup; OS will eventually purge temp files.
      }
    }
  }
}
```

### Key Points

- `path` is captured before the `try` so the `finally` block can reference it even
  if `exportSession()` itself throws (in which case `path` remains null and no delete
  is attempted).
- File delete is wrapped in its own `try/on Object` — a failed delete should not
  swallow or replace the original error.
- The OS temp directory is periodically purged by the platform, so orphaned files (from
  abnormal termination) are eventually reclaimed even without explicit cleanup.

### exportSession() File Location Contract

`TranscriptRepository.exportSession(sessionId, format)` must:

1. Resolve the temp path: `'${(await getTemporaryDirectory()).path}/export_$sessionId.${format.name}'`
2. Write the formatted content.
3. Return the absolute path string.

The file name includes `sessionId` to prevent collisions if multiple exports run
concurrently (unlikely but safe).

---

## Pattern 4: CaptionDisplayWidget Auto-Scroll (PERF-U5.3)

### Problem

Calling `ScrollController.animateTo()` synchronously during `build()` is illegal in
Flutter. The scroll must happen after the frame is laid out.

### Pattern

Use `WidgetsBinding.instance.addPostFrameCallback` triggered by detecting a change in
entry count. In a `ConsumerStatefulWidget`:

```dart
class _CaptionDisplayWidgetState extends ConsumerState<CaptionDisplayWidget> {
  final _scrollController = ScrollController();
  int _lastEntryCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    final target = widget.settings.scrollDirection == ScrollDirection.bottomToTop
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries  = widget.entries;
    final settings = widget.settings;

    if (entries.length != _lastEntryCount) {
      _lastEntryCount = entries.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }

    final textStyle = settings.captionTextSize
        .resolve(Theme.of(context).textTheme)
        ?.copyWith(fontFamily: settings.captionFont.fontFamily);

    return ListView.builder(
      controller: _scrollController,
      reverse: settings.scrollDirection == ScrollDirection.bottomToTop,
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        return Opacity(
          opacity: entry.isFinal ? 1.0 : 0.8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(entry.text, style: textStyle),
          ),
        );
      },
    );
  }
}
```

### Key Points

- Entry count is the scroll trigger proxy. Interim-to-interim updates (same count, text
  changes) do not re-trigger scroll; only new entries (buffer growth) do. This avoids
  scroll fighting when the user has manually scrolled up to review earlier captions.
- `ListView.reverse: true` combined with `animateTo(maxScrollExtent)` keeps the newest
  caption at the bottom without reversing the logical `entries` list order. The scroll
  position starts at `maxScrollExtent` (bottom) by default with `reverse: true`.
- `_scrollController.dispose()` is called in `dispose()` to prevent a `ScrollController`
  attached to a dead widget.

---

## Logical Components — Unit 5

### New Files (zip_captions)

| File | What it contains |
|------|-----------------|
| `routing/zc_router.dart` | `GoRouter` + `ShellRoute` definition |
| `shell/zc_app_shell.dart` | Platform-adaptive shell; `_isTabBarScreen()` |
| `shell/zc_bottom_nav_bar.dart` | `BottomNavigationBar` (Home, History) |
| `shell/zc_nav_drawer.dart` | `Drawer` (Home, Caption, History, Settings) |
| `shell/zc_nav_rail.dart` | `NavigationRail` (Home, Caption, History + Settings icon) |
| `screens/home_screen.dart` | HomeScreen |
| `screens/recording_screen.dart` | RecordingScreen (StatefulWidget + AppearancePanel) |
| `screens/settings_screen.dart` | SettingsScreen |
| `screens/history_screen.dart` | HistoryScreen (StatefulWidget + search debounce) |
| `screens/transcript_viewer_screen.dart` | TranscriptViewerScreen + export flow |
| `widgets/recording_controls_bar.dart` | Pause/Resume/Stop bar |
| `widgets/appearance_panel.dart` | Floating display settings overlay |
| `widgets/transcript_session_tile.dart` | History list item |
| `widgets/transcript_segment_tile.dart` | Viewer segment row |
| `widgets/export_format_sheet.dart` | Modal bottom sheet for TXT/SRT/VTT |
| `providers/transcript_search_query_provider.dart` | `StateProvider<String>` |

### New Files (zip_core)

| File | What it contains |
|------|-----------------|
| `widgets/caption_display_widget.dart` | Shared caption renderer; `ConsumerStatefulWidget` |
| `providers/transcript_providers.dart` | Extended: 3 new `@riverpod` family providers |

### app.dart Changes (zip_captions)

`app.dart` changes from `MaterialApp(home: HomeScreen())` to
`MaterialApp.router(routerConfig: zcRouter)`. Theme wiring (`AppTheme.light()` /
`AppTheme.dark()` driven by `displaySettingsNotifierProvider`) is unchanged.
