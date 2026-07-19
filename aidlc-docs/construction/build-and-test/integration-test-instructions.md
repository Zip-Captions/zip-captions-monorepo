# Integration Test Instructions — Phase 1

## Purpose
Test interactions between units to ensure the full Phase 1 stack works end-to-end across package boundaries. These scenarios complement the per-unit widget/provider tests by exercising real wiring rather than fakes.

## Test Scenarios

### Scenario 1: zip_core SttEngine ↔ AudioManager (macOS)
- **Description**: Verify that the macOS SttEngine implementation receives audio frames from the macOS AudioManager implementation and produces transcript events
- **Setup**: macOS device or Simulator with microphone permission granted
- **Test Steps**:
  1. Launch `zip_broadcast` (macOS build)
  2. Tap **Start Recording** with a valid audio input selected
  3. Speak a short phrase ("hello world")
  4. Verify transcript appears in the recording screen caption area
- **Expected Results**: At least one non-empty TranscriptChunk appears within 5 s; no error snackbar
- **Cleanup**: Tap **Stop Recording**

### Scenario 2: OutputTarget ↔ BroadcastRecordingNotifier (OBS WebSocket)
- **Description**: Verify that the OBS WebSocket output target receives captions when broadcast recording is active
- **Setup**: OBS Studio running locally with WebSocket server enabled on `ws://localhost:4455`
- **Test Steps**:
  1. Configure OBS connection in zip_broadcast Settings
  2. Start a broadcast recording session
  3. Verify `obsConnectionNotifier` state transitions to `connected`
  4. Speak; verify OBS caption source receives text via WebSocket
- **Expected Results**: OBS connection status indicator shows green; captions appear in OBS source
- **Cleanup**: Stop recording; close OBS connection

### Scenario 3: zip_broadcast Multi-Source Aggregation
- **Description**: Verify that multiple AudioInputConfigs each route to a separate BroadcastSession and that the UI aggregates their captions correctly
- **Setup**: Two audio input devices (or loopback + mic)
- **Test Steps**:
  1. Configure two audio sources in Settings
  2. Start recording
  3. Speak into source A, then source B
  4. Verify captions from both sources appear in the correct transcript panels
- **Expected Results**: Each panel shows the correct source's captions; no cross-contamination; homeStatusSummary shows "2 sources active"
- **Cleanup**: Stop recording; remove second source

### Scenario 4: zip_captions Recording + Caption Display
- **Description**: Verify that the full STT → caption pipeline works in the Zip Captions app
- **Setup**: macOS device with microphone permission
- **Test Steps**:
  1. Launch `zip_captions`
  2. Tap **Start**
  3. Speak several sentences
  4. Verify scrolling caption display updates in real time
  5. Tap **Stop**; verify session is saved to history
- **Expected Results**: Captions scroll as speech continues; history entry appears on home screen
- **Cleanup**: Delete test history entry

### Scenario 5: Pause / Resume Lifecycle
- **Description**: Verify pause → resume round-trip does not corrupt session state in either app
- **Setup**: macOS device
- **Test Steps**:
  1. Start recording in either app
  2. Tap **Pause** — verify audio stops, UI shows paused state
  3. Tap **Resume** — verify audio resumes, transcript continues from where it paused
  4. Stop recording; verify session contains content from both segments
- **Expected Results**: No transcript gap artifacts; session metadata (duration) is correct

## Setup Integration Test Environment

### 1. Start Required Services (OBS Scenario only)
```bash
# Launch OBS Studio and enable WebSocket plugin:
# Tools → WebSocket Server Settings → Enable WebSocket Server (port 4455)
```

### 2. Grant Permissions
```bash
# macOS: System Settings → Privacy & Security → Microphone → grant to zip_broadcast / zip_captions
```

## Run Integration Tests

Integration tests are currently **manual** — Flutter integration test tooling (flutter_test with integration_test package) is planned for Phase 2. Execute each scenario above on a macOS development build, recording pass/fail in the table below.

### Results Tracking

| Scenario | Status | Notes |
|----------|--------|-------|
| 1: STT ↔ AudioManager | Pending (manual) | Requires real hardware |
| 2: OBS WebSocket Output | Pending (manual) | Requires OBS running |
| 3: Multi-Source Aggregation | Pending (manual) | Requires multiple audio devices |
| 4: Zip Captions Pipeline | Pending (manual) | Requires real hardware |
| 5: Pause/Resume Lifecycle | Automated ✓ | INT-ZB-01 (zip_broadcast), INT-ZC-01 (zip_captions) |

## Automated Integration Tests (CI-Runnable)

The following provider-level integration tests run headlessly with fake/mock services and are included in the standard `flutter test` suite:

| Test ID | File | Coverage |
|---------|------|----------|
| INT-ZB-01 | `zip_broadcast/test/integration/caption_bus_flow_test.dart` | CaptionBus routing, sourceId tagging, pause gate, stop event (5 tests) |
| INT-ZB-02 | `zip_broadcast/test/integration/audio_config_recording_integration_test.dart` | Real AudioInputConfigNotifier → BroadcastRecordingNotifier (4 tests) |
| INT-ZB-03 | `zip_broadcast/test/integration/obs_settings_connection_integration_test.dart` | OBS settings ↔ connection ↔ caption forwarding (4 tests) |
| INT-ZC-01 | `zip_captions/test/integration/recording_pipeline_integration_test.dart` | Full RecordingStateNotifier lifecycle + CaptionBus (7 tests) |

**Total automated integration tests**: 20 (included in the 477-test suite)

### 3. Cleanup
```bash
# No persistent test services to tear down (OBS closure is manual)
```
