# Implementation Design — Unit 4: UI Prototypes

**Unit**: Unit 4: UI Prototypes  
**Branch**: `feature/output-targets`  
**Stage**: Implementation Design  
**Status**: COMPLETE  
**Feeds into**: Unit 5 (Zip Captions App, S-09), Unit 6 (Zip Broadcast App, S-10)

---

## Purpose

Translates the 9 approved HTML/CSS prototypes into Flutter component structure, routing
architecture, provider wiring, and file layout for both apps. Units 5 and 6 implement
directly from this document — no further design decisions should be needed for the
screen layer.

---

## 1. New Dependency: go_router

Both apps add `go_router` for named, declarative routing with `ShellRoute` support.

**Add to `packages/zip_captions/pubspec.yaml` and `packages/zip_broadcast/pubspec.yaml`:**
```yaml
dependencies:
  go_router: ^14.0.0
```

**Rationale:** `ShellRoute` provides a clean separation between the persistent shell
(sidebar, tabs, drawer) and the routed screen body. Plain `Navigator.push` would
require duplicating the shell on every screen or passing callbacks down the widget tree.

---

## 2. File Layout

### zip_captions

```
packages/zip_captions/lib/src/
  app.dart                          # MaterialApp.router wired to ZcRouter
  routing/
    zc_router.dart                  # GoRouter definition (routes + ShellRoute)
  shell/
    zc_app_shell.dart               # Platform-adaptive shell widget
    zc_bottom_nav_bar.dart          # BottomNavigationBar (mobile Home/History)
    zc_nav_drawer.dart              # Drawer (mobile Recording/Settings/Viewer)
    zc_nav_rail.dart                # NavigationRail (desktop ≥768px)
  screens/
    home_screen.dart                # Proto-01
    recording_screen.dart           # Proto-02
    settings_screen.dart            # Proto-03
    history_screen.dart             # Proto-04
    transcript_viewer_screen.dart   # Proto-05
  widgets/
    caption_display_widget.dart     # Live caption renderer (shared logic)
    recording_controls.dart         # Start/Pause/Resume/Stop button group
    audio_level_indicator.dart      # Microphone level bar
    appearance_panel.dart           # Floating appearance panel (Proto-02)
```

### zip_broadcast

```
packages/zip_broadcast/lib/src/
  app.dart                          # MaterialApp.router wired to ZbRouter
  routing/
    zb_router.dart                  # GoRouter definition
  shell/
    zb_app_shell.dart               # Platform-adaptive shell widget
    zb_nav_drawer.dart              # Drawer (mobile ≤640px, all screens)
    zb_nav_rail.dart                # NavigationRail (desktop >640px)
  screens/
    home_screen.dart                # Proto-06
    recording_screen.dart           # Proto-07
    settings_screen.dart            # Proto-08
    audio_config_screen.dart        # Proto-09
  widgets/
    output_target_status_row.dart   # OBS / browser source status chips
    paused_overlay_chip.dart        # Centred paused chip (Proto-07)
    settings_category_list.dart     # Android-style drill-down list (Proto-08)
    settings_category_detail.dart   # Detail view per category
    audio_input_row.dart            # Single audio input row (Proto-09)
```

---

## 3. Routing Architecture

### 3.1 Zip Captions — ZcRouter

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
        GoRoute(path: '/history',   builder: → HistoryScreen,
          routes: [
            GoRoute(
              path: ':sessionId',
              builder: (context, state) →
                TranscriptViewerScreen(
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

TranscriptViewerScreen is a child of `/history` so the back button returns to the
history list. It is inside the shell (sidebar remains visible on desktop).

### 3.2 Zip Broadcast — ZbRouter

```
GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ZbAppShell(child: child),
      routes: [
        GoRoute(path: '/',             builder: → HomeScreen),
        GoRoute(path: '/recording',    builder: → RecordingScreen),
        GoRoute(path: '/settings',     builder: → SettingsScreen),
        GoRoute(path: '/audio-config', builder: → AudioConfigScreen),
      ],
    ),
  ],
)
```

---

## 4. Shell Widget Architecture

### 4.1 ZcAppShell

Breakpoint: **768px** (matches prototype sidebar collapse point).

```
ZcAppShell(child)
  ├── if width > 768px:
  │    Row(
  │      ZcNavRail(currentIndex, onDestinationSelected)   // always visible
  │      VerticalDivider
  │      Expanded(child: child)
  │    )
  └── if width ≤ 768px:
       Scaffold(
         body: child,
         bottomNavigationBar:
           if _isTabBarScreen(location): ZcBottomNavBar(currentIndex, onTap)
           else: null,
         drawer:
           if !_isTabBarScreen(location): ZcNavDrawer(currentLocation, onTap)
           else: null,
         appBar:
           if !_isTabBarScreen(location):
             AppBar(leading: HamburgerButton)
       )
```

**Tab-bar screens** (bottom nav visible, no drawer): `/` and `/history`.  
**Drawer screens** (hamburger, no bottom nav): `/recording`, `/settings`, `/history/:id`.

`_isTabBarScreen(String location)` → `location == '/' || location == '/history'`

Destinations (both rail and bottom nav):
1. Home (`/`)
2. Caption (`/recording`)
3. History (`/history`)

Settings is accessible via an icon button in the AppBar (both breakpoints), not a primary nav destination. This matches Proto-01 and Proto-03 (Settings is not in the bottom tab bar).

### 4.2 ZbAppShell

Breakpoint: **640px** (matches prototype hamburger trigger).

```
ZbAppShell(child)
  ├── if width > 640px:
  │    Row(
  │      ZbNavRail(currentIndex, onDestinationSelected)
  │      VerticalDivider
  │      Expanded(child: child)
  │    )
  └── if width ≤ 640px:
       Scaffold(
         body: child,
         drawer: ZbNavDrawer(currentLocation, onTap),
         appBar: AppBar(leading: HamburgerButton)
       )
```

Destinations (all 4 screens):
1. Home (`/`)
2. Recording (`/recording`)
3. Settings (`/settings`)
4. Audio Config (`/audio-config`)

Dark-mode toggle appears in both the drawer footer (mobile) and the rail footer (desktop), matching the prototype.

---

## 5. Screen Specifications — Zip Captions

### 5.1 HomeScreen (Proto-01)

**File**: `screens/home_screen.dart`

**Providers watched:**
- `recordingStateNotifierProvider` — to show/hide the "Resume" button when a session is paused

**Widget structure:**
```
Scaffold
  AppBar(title: 'Zip Captions', actions: [SettingsIconButton])
  Column(
    Spacer
    AppLogoWidget
    Text('Real-time captions')
    StartCaptioningButton        // → context.go('/recording')
    if state is PausedState:
      ResumeCaptioningButton     // → context.go('/recording')
    Spacer
    HistoryEntryPoint            // → context.go('/history')
  )
```

### 5.2 RecordingScreen (Proto-02)

**File**: `screens/recording_screen.dart`

**Providers watched:**
- `recordingStateNotifierProvider` — drives control bar state (Pause / Resume / Stop)
- `onScreenCaptionTargetProvider` — drives `CaptionDisplayWidget`
- `displaySettingsNotifierProvider` — text size, font, scroll direction

**Widget structure:**
```
Column(
  Expanded(
    CaptionDisplayWidget(
      entries: ref.watch(onScreenCaptionTargetProvider),
      settings: ref.watch(displaySettingsNotifierProvider),
    )
  )
  AppearanceFloatingButton       // opens AppearancePanel overlay
  RecordingControlsBar(          // sticky at bottom
    state: recordingState,
    onPause: notifier.pause,
    onResume: notifier.resume,
    onStop: notifier.stop,
  )
)
```

**AppearancePanel** (`widgets/appearance_panel.dart`): positioned overlay (not a modal),
shows text size slider, font picker, scroll direction toggle. Triggered by `🔡` button.
Dismissed by tapping outside or pressing the button again.

**RecordingControlsBar** renders:
- `recording` state: Pause button + Stop button
- `paused` state: Resume button + Stop button
- `reconnecting` state: spinner + Stop button

When state transitions to `StoppedState`: `context.go('/history')` automatically (the
session has ended and the user can review it).

### 5.3 SettingsScreen (Proto-03)

**File**: `screens/settings_screen.dart`

**Providers watched:**
- `displaySettingsNotifierProvider`
- `transcriptSettingsNotifierProvider`
- `activeEngineIdProvider`
- `localeInfoProvider`
- `wakeLockSettingsProvider`
- `audioDeviceServiceProvider` (for mic source selection)

**Widget structure:**
```
Scaffold
  AppBar(title: 'Settings')
  ListView(
    SectionHeader('Speech-to-Text')
    EnginePickerTile
    LanguagePicker
    MicrophoneSourceTile

    SectionHeader('Display')
    TextSizeTile
    FontPickerTile
    ScrollDirectionTile
    ThemeModeTile

    SectionHeader('Transcripts')
    TranscriptCaptureSwitchTile
    StorageUsageTile (read-only)

    SectionHeader('Accessibility')
    WakeLockTile
  )
```

### 5.4 HistoryScreen (Proto-04)

**File**: `screens/history_screen.dart`

**Providers watched:**
- `transcriptSessionListProvider` — **new provider** (see §7)
- `transcriptSearchQueryProvider` — local `StateProvider<String>` for the search field

**Widget structure:**
```
Scaffold
  AppBar(
    title: 'History',
    bottom: SearchBar(onChanged: ref.read(transcriptSearchQueryProvider.notifier).update)
  )
  if sessions.isEmpty: EmptyHistoryPlaceholder
  else: ListView.builder(
    itemBuilder: TranscriptSessionTile(
      session: sessions[i],
      onTap: () => context.go('/history/${session.id}'),
      onDelete: () => notifier.deleteSession(session.id),
    )
  )
```

### 5.5 TranscriptViewerScreen (Proto-05)

**File**: `screens/transcript_viewer_screen.dart`

**Constructor parameter**: `String sessionId`

**Providers watched:**
- `transcriptSessionProvider(sessionId)` — **new provider** (see §7)
- `transcriptSegmentsProvider(sessionId)` — **new provider** (see §7)
- `displaySettingsNotifierProvider` (for text rendering)

**Widget structure:**
```
Scaffold
  AppBar(
    title: session.title ?? session.formattedDate,
    actions: [ExportButton]       // opens ExportFormatSheet
  )
  ListView.builder(
    itemBuilder: TranscriptSegmentTile(segment)
  )
```

**ExportFormatSheet**: `showModalBottomSheet` with TXT / SRT / VTT options. Calls
`transcriptRepository.exportSession(sessionId, format)` then `Share.share(path)` or
`FileSaver.save(path)` (packages TBD at Unit 5 FD).

---

## 6. Screen Specifications — Zip Broadcast

### 6.1 HomeScreen (Proto-06)

**File**: `screens/home_screen.dart`

**Providers watched:**
- `recordingStateNotifierProvider`
- `outputTargetSettingsNotifierProvider`

**Widget structure:**
```
Column(
  Spacer
  AppLogoWidget
  Text('Zip Broadcast')
  StartBroadcastButton         // → context.go('/recording')
  if state is PausedState:
    ResumeBroadcastButton
  Spacer
  OutputTargetStatusRow(       // shows enabled output chips (OBS, browser source, overlay)
    settings: outputTargetSettings,
  )
)
```

### 6.2 RecordingScreen (Proto-07)

**File**: `screens/recording_screen.dart`

**Providers watched:**
- `recordingStateNotifierProvider`
- `onScreenCaptionTargetProvider`
- `displaySettingsNotifierProvider`
- `outputTargetSettingsNotifierProvider`
- `obsConnectionStateProvider` — **new provider** (see §7)
- `browserSourceUrlProvider` — **new provider** (see §7)

**Widget structure:**
```
Stack(
  Column(
    Expanded(CaptionDisplayWidget)
    AppearanceFloatingButton
    RecordingControlsBar
    OutputTargetStatusRow(compact: true)
  )
  if state is PausedState:
    PausedOverlayChip(          // absolute, z-order above caption area
      onResume: notifier.resume,
    )
)
```

**PausedOverlayChip** (`widgets/paused_overlay_chip.dart`): centred horizontally, placed
in the upper-middle of the caption area (not bottom banner). Contains pause icon +
"Paused" label + "Resume" CTA button.

**OutputTargetStatusRow** (compact variant, sticky above controls):
- OBS chip: green/amber/red based on `obsConnectionState`
- Browser source chip: shows localhost URL when active; tap copies to clipboard

### 6.3 SettingsScreen (Proto-08)

**File**: `screens/settings_screen.dart`

**Design pattern**: Android-style category list → in-place drill-down. A single
`SettingsScreen` widget manages a `currentCategory` local state variable (`null` = list
view, non-null = detail view). No `Navigator.push` — the detail widget replaces the list
within the same screen body. This matches the prototype's JavaScript view-switching.

**Providers watched (category list):**
- `displaySettingsNotifierProvider`
- `obsSettingsNotifierProvider`
- `outputTargetSettingsNotifierProvider`
- `transcriptSettingsNotifierProvider`
- `audioInputSettingsNotifierProvider`
- `activeEngineIdProvider`

**Widget structure:**
```
Scaffold
  AppBar(
    title: currentCategory == null ? 'Settings' : currentCategory.label,
    leading: currentCategory != null ? BackButton(onPressed: clearCategory) : null,
  )
  AnimatedSwitcher(
    if currentCategory == null:
      SettingsCategoryList(
        categories: [STT, Display, Output Targets, OBS, Audio, Transcripts],
        onTap: (cat) => setState(() => currentCategory = cat),
      )
    else:
      SettingsCategoryDetail(category: currentCategory)
  )
```

**Categories and their detail content:**

| Category | Contents |
|---|---|
| Speech-to-Text | Engine picker, language/locale |
| Display | Text size, font, scroll direction, theme |
| Output Targets | Enable/disable toggles (OBS, browser source, overlay) |
| OBS Connection | Host, port, password, test connection |
| Audio Inputs | Summary (count + labels); tap → `/audio-config` |
| Transcripts | Capture toggle, storage usage |

### 6.4 AudioConfigScreen (Proto-09)

**File**: `screens/audio_config_screen.dart`

**Providers watched:**
- `audioInputSettingsNotifierProvider` — list of `AudioInputConfig`
- `audioDeviceServiceProvider` — available `AudioDevice` instances

**Widget structure:**
```
Scaffold
  AppBar(title: 'Audio Inputs')
  Column(
    ListView.builder(
      itemBuilder: AudioInputRow(
        config: inputs[i],
        availableDevices: devicesNotClaimedByOtherInputs(inputs, i),
        onSourceChanged: notifier.updateSource,
        onLabelChanged: notifier.updateLabel,
        onRemove: inputs.length > 1 ? notifier.removeInput : null,
      )
    )
    if inputs.length < maxInputs:
      AddAudioInputButton(      // dashed border; hidden when all sources claimed
        onTap: notifier.addInput,
      )
  )
```

**Mutual exclusion logic** lives in `AudioInputSettingsNotifier`, not in the widget.
`notifier.updateSource(inputId, newDevice)` checks that no other input uses the same
device and rejects the update if so. The widget reflects notifier state only —
`availableDevices` list passed to each row is filtered by the notifier before rendering.

**`AddAudioInputButton` visibility rule**: hidden when `inputs.length >= availableDevices.length`
(all sources already claimed). This matches the prototype's "disappears when sources are
exhausted" behaviour.

---

## 7. New Providers Required

These providers do not yet exist. They are created in Unit 5 (zip_captions) or Unit 6
(zip_broadcast) as appropriate — they are listed here so the CG plans can include them.

### zip_core (created in Unit 5)

#### `transcriptSessionListProvider`
```dart
@riverpod
Future<List<TranscriptSession>> transcriptSessionList(Ref ref) async {
  final repo = await ref.watch(transcriptRepositoryProvider.future);
  return repo.getSessions();
}
```

#### `transcriptSessionProvider(String sessionId)`
```dart
@riverpod
Future<TranscriptSession?> transcriptSession(Ref ref, String sessionId) async {
  final repo = await ref.watch(transcriptRepositoryProvider.future);
  return repo.getSession(sessionId);
}
```

#### `transcriptSegmentsProvider(String sessionId)`
```dart
@riverpod
Future<List<TranscriptSegment>> transcriptSegments(Ref ref, String sessionId) async {
  final repo = await ref.watch(transcriptRepositoryProvider.future);
  return repo.getSegments(sessionId);
}
```

#### `transcriptSearchQueryProvider`
```dart
// Local StateProvider — lives in zip_captions, not zip_core.
final transcriptSearchQueryProvider = StateProvider<String>((ref) => '');
```

### zip_broadcast (created in Unit 6)

#### `obsConnectionStateProvider`
```dart
@Riverpod(keepAlive: true)
Stream<ObsConnectionState> obsConnectionState(Ref ref) {
  // Reads from ObsWebSocketTarget's connection state stream.
  // ObsWebSocketTarget exposes a Stream<ObsConnectionState> via a getter.
  final target = ref.watch(obsWebSocketTargetProvider);
  return target.connectionStateStream;
}
```

`ObsConnectionState` (already exists at `models/obs_connection_state.dart`).

#### `browserSourceUrlProvider`
```dart
@riverpod
String? browserSourceUrl(Ref ref) {
  final settings = ref.watch(outputTargetSettingsNotifierProvider);
  if (!settings.browserSourceEnabled) return null;
  return 'http://localhost:${settings.browserSourcePort}/';
}
```

---

## 8. CaptionDisplayWidget — Placement Decision

The application design deferred the decision of whether `CaptionDisplayWidget` lives in
`zip_core` or in each app. **Decision: place in `zip_core`.**

Both `zip_captions/RecordingScreen` and `zip_broadcast/RecordingScreen` use identical
caption rendering logic (text size, font, scroll direction, speaker change breaks,
pause markers). Duplicating it would create a maintenance liability.

**File**: `packages/zip_core/lib/src/widgets/caption_display_widget.dart`  
**Exported** from `package:zip_core/zip_core.dart`.

---

## 9. Dark Mode Toggle Placement

Both apps expose a dark mode toggle. Provider: `displaySettingsNotifierProvider`
(field: `themeModeSetting`).

- **Zip Captions**: in the SettingsScreen under the Display category.
- **Zip Broadcast**: additionally surfaced in `ZbNavRail` footer and `ZbNavDrawer` footer,
  matching the prototype. The same `displaySettingsNotifierProvider` is watched in the
  shell widget to render the toggle icon.

---

## 10. Decisions Locked

| Decision | Choice | Rationale |
|---|---|---|
| Router package | `go_router ^14.0.0` | ShellRoute, named routes, deep linking |
| Shell breakpoints | ZC: 768px, ZB: 640px | Match prototype collapse points |
| ZC Settings nav | AppBar icon (not primary tab) | Prototypes: Settings not in bottom tab bar |
| ZC tab-bar screens | Home + History only | Recording/Settings/Viewer use drawer at mobile widths |
| ZB nav pattern | Drawer-only at mobile | No bottom tabs in Broadcast app |
| Paused indicator (ZB) | Overlay chip (centred, z-order above captions) | User feedback: bottom banner not visible |
| ZB Settings pattern | In-place AnimatedSwitcher | Matches prototype JS view-switch; avoids push navigation cost |
| CaptionDisplayWidget | In zip_core | Both apps identical; avoids duplication |
| Audio exclusion logic | In AudioInputSettingsNotifier | Widget reflects state only, no logic |
| TranscriptViewerScreen | Inside ShellRoute (/history/:id) | Back button returns to list; sidebar persists on desktop |
