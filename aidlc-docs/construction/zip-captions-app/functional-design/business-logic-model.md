# Business Logic Model — Unit 5: Zip Captions App

**Unit**: Unit 5: Zip Captions App (S-09)
**Stage**: Functional Design
**Status**: COMPLETE

---

## 1. New Dependencies

Add to `packages/zip_captions/pubspec.yaml`:

```yaml
dependencies:
  go_router: ^14.0.0
  share_plus: ^11.0.0
  file_selector: ^1.0.0
```

- `go_router` — routing with ShellRoute and named paths
- `share_plus` — OS share sheet on iOS/Android (export flow)
- `file_selector` — save file dialog on macOS/Windows/Linux (export flow)

---

## 2. ZcRouter

**File**: `packages/zip_captions/lib/src/routing/zc_router.dart`

```
GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ZcAppShell(child: child),
      routes: [
        GoRoute(path: '/',          builder: → HomeScreen),
        GoRoute(path: '/recording', builder: → RecordingScreen),
        GoRoute(path: '/settings',  builder: → SettingsScreen),
        GoRoute(
          path: '/history',
          builder: → HistoryScreen,
          routes: [
            GoRoute(
              path: ':sessionId',
              builder: (context, state) → TranscriptViewerScreen(
                sessionId: state.pathParameters['sessionId']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
)
```

The router is a `final` `GoRouter` constant (or `@riverpod GoRouter`) instantiated in
`zc_router.dart` and wired into `app.dart` as `MaterialApp.router(routerConfig: zcRouter)`.

---

## 3. ZcAppShell

**File**: `packages/zip_captions/lib/src/shell/zc_app_shell.dart`

Platform-adaptive shell widget. Determines layout by comparing current viewport width
against the 768px breakpoint.

```
ZcAppShell(child)
  ├── LayoutBuilder / MediaQuery → width
  ├── GoRouterState → current location string
  │
  ├── if width > 768px (desktop):
  │    Row(
  │      ZcNavRail(
  │        selectedIndex: _railIndex(location),
  │        onDestinationSelected: (i) => context.go(_railDestination(i)),
  │        trailing: SettingsIconButton,
  │      )
  │      VerticalDivider(width: 1)
  │      Expanded(child: child)
  │    )
  │
  └── if width ≤ 768px (mobile):
       Scaffold(
         appBar: AppBar(
           title: Text(_screenTitle(location)),
           leading: _isTabBarScreen(location) ? null : HamburgerButton,
           actions: [SettingsIconButton],
         )
         body: child,
         bottomNavigationBar:
           if _isTabBarScreen(location):
             ZcBottomNavBar(
               currentIndex: _tabIndex(location),
               onTap: (i) => context.go(_tabDestination(i)),
             )
         drawer:
           if !_isTabBarScreen(location):
             ZcNavDrawer(
               currentLocation: location,
               onTap: (route) => { context.go(route); Navigator.of(context).pop(); },
             )
       )
```

### _isTabBarScreen()

```dart
bool _isTabBarScreen(String location) =>
    location == '/' || location == '/history';
```

### Rail index mapping

| Index | Route |
|-------|-------|
| 0 | `/` |
| 1 | `/recording` |
| 2 | `/history` |

Settings is not a rail destination; it appears as a `trailing` icon in the rail and as
an `AppBar` action on mobile.

### Tab (bottom nav) index mapping

| Index | Route |
|-------|-------|
| 0 | `/` |
| 1 | `/history` |

`/recording` is not in the bottom nav. It is accessible via the Start button on HomeScreen
or the Resume button. Once in RecordingScreen, the bottom nav is not visible.

---

## 4. HomeScreen

**File**: `packages/zip_captions/lib/src/screens/home_screen.dart`

```
HomeScreen (ConsumerWidget)
  build(context, ref):
    final state = ref.watch(recordingStateNotifierProvider)

    Scaffold(
      body: Center(
        Column(
          Spacer,
          AppLogoWidget,
          Text('Real-time captions'),
          SizedBox(height: 24),
          ElevatedButton('Start Captioning',
            onPressed: () => context.go('/recording'),
          ),
          if state is PausedState:
            TextButton('Resume',
              onPressed: () => context.go('/recording'),
            ),
          Spacer,
          TextButton('View History',
            onPressed: () => context.go('/history'),
          ),
          SizedBox(height: 16),
        )
      )
    )
```

**Provider dependency**: `recordingStateNotifierProvider` — read-only, drives Resume
button visibility. No write calls from HomeScreen.

---

## 5. RecordingScreen

**File**: `packages/zip_captions/lib/src/screens/recording_screen.dart`

```
RecordingScreen (ConsumerStatefulWidget)

  State fields:
    bool _showAppearancePanel = false

  initState:
    // No setup needed; auto-nav is handled by ref.listen in build

  build(context, ref):
    final state    = ref.watch(recordingStateNotifierProvider)
    final entries  = ref.watch(onScreenCaptionTargetProvider)
    final settings = ref.watch(displaySettingsNotifierProvider)
    final notifier = ref.read(recordingStateNotifierProvider.notifier)

    ref.listen(recordingStateNotifierProvider, (prev, next) {
      if (next is StoppedState && context.mounted) {
        context.go('/history');           // BR-U5-01
      }
    })

    Scaffold(
      body: Stack(
        children: [
          GestureDetector(                // BR-U5-10: dismiss panel on caption tap
            onTap: () => setState(() => _showAppearancePanel = false),
            child: Column(
              children: [
                Expanded(
                  CaptionDisplayWidget(
                    entries: entries,
                    settings: settings,
                  )
                ),
                RecordingControlsBar(
                  state: state,
                  onPause:  () => notifier.pause(),
                  onResume: () => notifier.resume(),
                  onStop:   () => notifier.stop(),
                ),
              ],
            ),
          ),
          if _showAppearancePanel:
            Positioned(
              bottom: 80,   // above RecordingControlsBar
              right: 16,
              child: AppearancePanel(
                settings: settings,
                onChanged: ref.read(displaySettingsNotifierProvider.notifier),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        child: Icon(Icons.text_fields),
        onPressed: () => setState(() => _showAppearancePanel = !_showAppearancePanel),
      ),
    )
```

### RecordingControlsBar render logic

```
RecordingControlsBar(state, onPause, onResume, onStop)
  ├── state is RecordingActiveState:
  │     Row(PauseButton, StopButton)
  ├── state is PausedState:
  │     Row(ResumeButton, StopButton)
  └── state is ReconnectingState:
        Row(CircularProgressIndicator, StopButton)
```

`IdleState` and `StoppedState` are not rendered; navigation away occurs before they
can appear here (BR-U5-01).

---

## 6. SettingsScreen

**File**: `packages/zip_captions/lib/src/screens/settings_screen.dart`

Settings is a read-write form. All settings are written immediately on change (no
pending state or save button).

```
SettingsScreen (ConsumerWidget)
  build(context, ref):
    final displaySettings   = ref.watch(displaySettingsNotifierProvider)
    final transcriptSettings = ref.watch(transcriptSettingsNotifierProvider)
    final engineId          = ref.watch(activeEngineIdProvider)
    final localeInfo        = ref.watch(localeInfoProvider)
    final wakeLockSettings  = ref.watch(wakeLockSettingsProvider)
    final audioDevices      = ref.watch(audioDeviceServiceProvider)

    Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        SectionHeader('Speech-to-Text'),
        EnginePickerTile(currentId: engineId),
        LanguagePickerTile(locales: localeInfo),
        MicrophoneSourceTile(devices: audioDevices),

        SectionHeader('Display'),
        TextSizeTile(size: displaySettings.captionTextSize,
          onChanged: ref.read(displaySettingsNotifierProvider.notifier).setTextSize),
        FontPickerTile(font: displaySettings.captionFont,
          onChanged: ref.read(displaySettingsNotifierProvider.notifier).setFont),
        ScrollDirectionTile(dir: displaySettings.scrollDirection,
          onChanged: ref.read(displaySettingsNotifierProvider.notifier).setScrollDirection),
        ThemeModeTile(mode: displaySettings.themeModeSetting,
          onChanged: ref.read(displaySettingsNotifierProvider.notifier).setThemeMode),

        SectionHeader('Transcripts'),
        SwitchListTile('Save transcripts',
          value: transcriptSettings.captureEnabled,
          onChanged: (v) => ref.read(transcriptSettingsNotifierProvider.notifier)
              .setCaptureEnabled(value: v)),
        StorageUsageTile(readOnly: true),

        SectionHeader('Accessibility'),
        WakeLockTile(settings: wakeLockSettings),
      )
    )
```

`displaySettingsNotifierProvider` is the Zip Captions app instance
(`DisplaySettingsNotifier` with `keyPrefix: 'zip_captions'`) declared in
`packages/zip_captions/lib/src/providers/settings_notifier.dart`.

---

## 7. HistoryScreen

**File**: `packages/zip_captions/lib/src/screens/history_screen.dart`

```
HistoryScreen (ConsumerWidget)
  build(context, ref):
    final query    = ref.watch(transcriptSearchQueryProvider)
    final sessions = ref.watch(transcriptSessionListProvider(query))
    final repo     = ref.watch(transcriptRepositoryProvider)

    Scaffold(
      appBar: AppBar(
        title: Text('History'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: SearchBar(
            hintText: 'Search transcripts…',
            onChanged: (v) =>
                ref.read(transcriptSearchQueryProvider.notifier).state = v,
          ),
        ),
      ),
      body: sessions.when(
        loading: () => LinearProgressIndicator(),
        error:   (e, _) => Center(child: Text('Error loading sessions')),
        data: (list) => list.isEmpty
            ? EmptyHistoryPlaceholder(
                hasQuery: query.trim().isNotEmpty,
              )
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => TranscriptSessionTile(
                  session: list[i],
                  onTap: () => context.go('/history/${list[i].sessionId}'),
                  onDelete: () async {
                    final r = await repo;
                    await r.deleteSession(list[i].sessionId);
                    ref.invalidate(transcriptSessionListProvider);
                  },
                ),
              ),
      ),
    )
```

**`EmptyHistoryPlaceholder`**: Shows different copy depending on `hasQuery`:
- `hasQuery == false`: "No transcripts yet. Start captioning to save your first session."
- `hasQuery == true`: "No results for this search."

---

## 8. TranscriptViewerScreen

**File**: `packages/zip_captions/lib/src/screens/transcript_viewer_screen.dart`

```
TranscriptViewerScreen(String sessionId) (ConsumerWidget)
  build(context, ref):
    final sessionAsync  = ref.watch(transcriptSessionProvider(sessionId))
    final segmentsAsync = ref.watch(transcriptSegmentsProvider(sessionId))

    Scaffold(
      appBar: AppBar(
        title: sessionAsync.maybeWhen(
          data: (s) => Text(s?.title ?? s?.formattedDate ?? sessionId),
          orElse: () => Text('Transcript'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share),
            onPressed: sessionAsync.valueOrNull != null
                ? () => _showExportSheet(context, ref)
                : null,
          ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => LinearProgressIndicator(),
        error:   (e, _) => Center(child: Text('Could not load session')),
        data: (session) {
          if (session == null) return _SessionNotFound(onBack: context.pop);   // BR-U5-19
          return segmentsAsync.when(
            loading: () => LinearProgressIndicator(),
            error:   (e, _) => Center(child: Text('Could not load transcript')),
            data: (segments) => ListView.builder(
              itemCount: segments.length,
              itemBuilder: (_, i) => TranscriptSegmentTile(segment: segments[i]),
            ),
          );
        },
      ),
    )
```

### _showExportSheet()

```dart
void _showExportSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    builder: (_) => ExportFormatSheet(
      onFormatSelected: (format) async {
        Navigator.of(context).pop();   // dismiss sheet
        await _runExport(context, ref, format);
      },
    ),
  );
}
```

### _runExport()

```dart
Future<void> _runExport(BuildContext context, WidgetRef ref, ExportFormat format) async {
  try {
    final repo = await ref.read(transcriptRepositoryProvider.future);
    final path = await repo.exportSession(sessionId, format);

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      await SharePlus.instance.share(XFile(path));          // BR-U5-23
    } else {
      final location = await getSaveLocation(               // BR-U5-24
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
        SnackBar(content: Text('Export failed. Please try again.')),
      );
    }
  }
}
```

**`_exportFileName(sessionId, format)`**: Returns `'transcript_${date}_${sessionId.substring(0, 8)}.${format.name}'`
where `date` is `yyyy-MM-dd` from `TranscriptSession.date`.

---

## 9. CaptionDisplayWidget (zip_core)

**File**: `packages/zip_core/lib/src/widgets/caption_display_widget.dart`

Shared by `zip_captions` RecordingScreen and `zip_broadcast` RecordingScreen.

```
CaptionDisplayWidget (ConsumerWidget)
  required: List<CaptionDisplayEntry> entries
  required: DisplaySettings settings

  build(context, ref):
    final textStyle = settings.captionTextSize.resolve(Theme.of(context).textTheme)
        ?.copyWith(fontFamily: settings.captionFont.fontFamily)

    final controller = useScrollController()   // or keep in StatefulWidget

    // Auto-scroll on new entry (BR-U5-12)
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.hasClients) {
          final target = settings.scrollDirection == ScrollDirection.bottomToTop
              ? controller.position.maxScrollExtent
              : 0.0;
          controller.animateTo(target,
            duration: Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
      return null;
    }, [entries.length]);

    ListView.builder(
      controller: controller,
      reverse: settings.scrollDirection == ScrollDirection.bottomToTop,
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        return Opacity(
          opacity: entry.isFinal ? 1.0 : 0.8,       // BR-U5-13
          child: Text(entry.text, style: textStyle),
        );
      },
    )
```

**Note on `reverse`**: Setting `ListView.reverse: true` achieves bottom-to-top scroll
(newest entry visible at bottom) without reversing the item order in the `entries` list.
The auto-scroll target is `maxScrollExtent` for `bottomToTop` and `0.0` for `topToBottom`.

---

## 10. New Providers

### `transcriptSessionListProvider(String query)` — zip_core

**File**: `packages/zip_core/lib/src/providers/transcript_providers.dart` (add to existing file)

```dart
@riverpod
Future<List<TranscriptSession>> transcriptSessionList(
  Ref ref,
  String query,
) async {
  final repo = await ref.watch(transcriptRepositoryProvider.future);
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return repo.getSessions();
  }
  final results = await repo.search(trimmed);
  return results.map((r) => r.session).toList();
}
```

**Behaviour**:
- Empty / whitespace query → `getSessions()` (date-desc order, all sessions)
- Non-empty query → `search(query)` → mapped to sessions in BM25 order

**Cache behaviour**: Riverpod caches per `query` argument. Queries are invalidated
when `ref.invalidate(transcriptSessionListProvider)` is called (e.g., after delete),
which invalidates all family instances.

---

### `transcriptSessionProvider(String sessionId)` — zip_core

**File**: `packages/zip_core/lib/src/providers/transcript_providers.dart`

```dart
@riverpod
Future<TranscriptSession?> transcriptSession(
  Ref ref,
  String sessionId,
) async {
  final repo = await ref.watch(transcriptRepositoryProvider.future);
  return repo.getSession(sessionId);
}
```

Returns `null` if the session does not exist (triggers BR-U5-19 error state in viewer).

---

### `transcriptSegmentsProvider(String sessionId)` — zip_core

**File**: `packages/zip_core/lib/src/providers/transcript_providers.dart`

```dart
@riverpod
Future<List<TranscriptSegment>> transcriptSegments(
  Ref ref,
  String sessionId,
) async {
  final repo = await ref.watch(transcriptRepositoryProvider.future);
  return repo.getSegments(sessionId);
}
```

`getSegments()` returns segments ordered by `startTimeMs` ASC (BR-U5-20).

---

### `transcriptSearchQueryProvider` — zip_captions

**File**: `packages/zip_captions/lib/src/providers/transcript_search_query_provider.dart`

```dart
final transcriptSearchQueryProvider = StateProvider<String>((ref) => '');
```

No Riverpod codegen; a plain `StateProvider` is sufficient for this single-string state.

---

## 11. Provider Dependency Map — Unit 5 Additions

```
transcriptSearchQueryProvider (zip_captions, StateProvider<String>)
    |
    └──(passed as arg)──> transcriptSessionListProvider(query) (zip_core)
                              |
                              └──(watches)──> transcriptRepositoryProvider (zip_core)
                                                 |
                                                 └──> TranscriptRepository
                                                      └──> TranscriptDatabase (drift)

transcriptSessionProvider(sessionId) (zip_core)
    └──> transcriptRepositoryProvider

transcriptSegmentsProvider(sessionId) (zip_core)
    └──> transcriptRepositoryProvider

recordingStateNotifierProvider (zip_core, existing)
    └──(listened by RecordingScreen)──> context.go('/history') on StoppedState

displaySettingsNotifierProvider (zip_captions instance, existing)
    └──(watched by)──> RecordingScreen, SettingsScreen, CaptionDisplayWidget
```

---

## 12. File Layout Summary

```
packages/zip_captions/lib/src/
  app.dart                                   # Updated: MaterialApp.router
  routing/
    zc_router.dart                           # New: GoRouter definition
  shell/
    zc_app_shell.dart                        # New: platform-adaptive shell
    zc_bottom_nav_bar.dart                   # New: BottomNavigationBar (mobile)
    zc_nav_drawer.dart                       # New: Drawer (mobile drawer screens)
    zc_nav_rail.dart                         # New: NavigationRail (desktop)
  screens/
    home_screen.dart                         # New
    recording_screen.dart                    # New
    settings_screen.dart                     # New
    history_screen.dart                      # New
    transcript_viewer_screen.dart            # New
  widgets/
    recording_controls_bar.dart              # New
    appearance_panel.dart                    # New
    transcript_session_tile.dart             # New
    transcript_segment_tile.dart             # New
    export_format_sheet.dart                 # New
  providers/
    settings_notifier.dart                   # Existing
    transcript_search_query_provider.dart    # New

packages/zip_core/lib/src/
  providers/
    transcript_providers.dart                # Extended: 3 new family providers
  widgets/
    caption_display_widget.dart              # New (shared with zip_broadcast)
```
