# E2E and UI/UX Validation Instructions — Phase 1

## Purpose
Validate the shipped UI against the Phase 1 HTML prototypes and user story acceptance criteria. This is a structured manual review; automated E2E (Patrol or Maestro) is planned for Phase 2.

## Reference Prototypes
All prototypes are in `aidlc-docs/construction/prototypes/`. Open each HTML file in a browser to compare side-by-side with the running app.

| Prototype | App | Screen |
|-----------|-----|--------|
| `zip-broadcast-home.html` | zip_broadcast | HomeScreen |
| `zip-broadcast-recording.html` | zip_broadcast | RecordingScreen |
| `zip-broadcast-audio-config.html` | zip_broadcast | Audio source settings |
| `zip-broadcast-settings.html` | zip_broadcast | SettingsScreen |
| `zip-captions-home.html` | zip_captions | HomeScreen |
| `zip-captions-recording.html` | zip_captions | RecordingScreen |
| `zip-captions-settings.html` | zip_captions | SettingsScreen |
| `zip-captions-history.html` | zip_captions | History screen |
| `zip-captions-viewer.html` | zip_captions | Viewer/caption display |

## Validation Checklist

### zip_broadcast — HomeScreen
- [ ] Correct app title and branding
- [ ] Audio source list shows configured devices
- [ ] Connection status badge displays correctly (disconnected/connected)
- [ ] Status summary uses correct pluralization (0 / 1 / N sources)
- [ ] Start Recording button enabled only when ≥ 1 source configured
- [ ] ComingSoonCard shown for Phase 2 features (remote viewers output)
- [ ] Navigation to Settings works

### zip_broadcast — RecordingScreen
- [ ] Shows all active sessions (one card per source)
- [ ] Per-session caption text scrolls in real time
- [ ] Pause / Resume controls respond correctly
- [ ] Stop ends all sessions and returns to HomeScreen
- [ ] Reconnecting state shows overlay (simulated by disconnecting OBS mid-session)
- [ ] Error snackbar appears on idle state with `lastError`

### zip_broadcast — SettingsScreen
- [ ] Audio input list populated from system devices
- [ ] Add / remove source flows work
- [ ] OBS WebSocket URL field saves and loads correctly
- [ ] Language / locale selector works

### zip_captions — HomeScreen
- [ ] Start button navigates to RecordingScreen
- [ ] History list populates after sessions complete
- [ ] Empty state shows placeholder

### zip_captions — RecordingScreen
- [ ] Captions display in real time
- [ ] Font size and scroll direction settings respected
- [ ] Pause / Resume / Stop controls work
- [ ] Navigation back to Home after Stop

### zip_captions — SettingsScreen
- [ ] Caption font, size, scroll direction controls save state
- [ ] Language selector works

### zip_captions — History / Viewer
- [ ] Saved session opens in Viewer
- [ ] Full transcript renders correctly
- [ ] Delete session removes from list

## Accessibility Checks
- [ ] All interactive elements meet WCAG AA contrast ratio (verified at design time via AppTheme tests; spot-check in app)
- [ ] VoiceOver labels present on all buttons and status indicators
- [ ] No layout overflow at default window size (1280 × 800)

## Running the Apps for Review
```bash
# zip_broadcast (macOS)
cd packages/zip_broadcast
flutter run -d macos

# zip_captions (macOS)
cd packages/zip_captions
flutter run -d macos
```

## Results Tracking

| Area | Status | Notes |
|------|--------|-------|
| ZB HomeScreen | Pending | |
| ZB RecordingScreen | Pending | |
| ZB SettingsScreen | Pending | |
| ZC HomeScreen | Pending | |
| ZC RecordingScreen | Pending | |
| ZC SettingsScreen | Pending | |
| ZC History / Viewer | Pending | |
| Accessibility spot-check | Pending | |
