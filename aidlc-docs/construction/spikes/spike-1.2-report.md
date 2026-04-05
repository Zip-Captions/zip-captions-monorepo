# Spike 1.2 Report: System Audio Capture Feasibility

**Date**: 2026-03-30
**Status**: Complete
**Scope**: Investigate system audio capture (loopback) feasibility per platform. macOS entitlements and virtual audio devices, Windows WASAPI loopback, Linux PulseAudio/PipeWire monitor sources. Document what works and what doesn't.

---

## Executive Summary

System audio capture is **feasible on all three desktop platforms** but requires a custom Flutter platform plugin with per-platform native implementations. No mature cross-platform Flutter package exists.

**macOS** is the most complex: Core Audio taps (macOS 14.2+) provide the best path with a dedicated "System Audio Recording Only" permission that avoids screen recording entitlements. **Windows** is straightforward: WASAPI loopback requires no permissions and is well-documented. **Linux** is the simplest: PulseAudio/PipeWire monitor sources work with no special permissions.

The recommended approach is a single Flutter plugin (`zip_audio_capture`) with native implementations per platform, prioritizing Core Audio taps on macOS, WASAPI loopback on Windows, and PulseAudio monitor sources on Linux.

---

## Platform Analysis

### macOS

#### Approach 1: Core Audio Taps (Recommended — macOS 14.2+)

Apple introduced `AudioHardwareCreateProcessTap` in macOS 14.2 (refined in 14.4) for intercepting system audio output.

| Aspect | Detail |
|--------|--------|
| API | `AudioHardwareCreateProcessTap`, `AudioHardwareCreateAggregateDevice` |
| Min OS | macOS 14.2 (Sonoma) |
| Permission | "System Audio Recording Only" — separate from Screen Recording |
| Entitlement | `NSAudioCaptureUsageDescription` in Info.plist |
| App Store | No screen capture entitlement needed — low rejection risk |
| Scope | Per-process or entire system audio |
| Latency | Near-zero (direct audio tap) |
| Reference | [Apple docs](https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps), [AudioCap sample](https://github.com/insidegui/AudioCap) |

**Verdict**: Best option for macOS. Users see a clean "System Audio Recording Only" permission prompt (Settings > Privacy & Security > Screen & System Audio Recording). Does not trigger the aggressive monthly re-prompting that Screen Recording triggers on macOS Sequoia.

#### Approach 2: ScreenCaptureKit (macOS 13.0–14.1 fallback)

| Aspect | Detail |
|--------|--------|
| API | `SCStream` with `capturesAudio = true` |
| Min OS | macOS 13.0 (Ventura) |
| Permission | **Screen Recording** (even for audio-only capture) |
| App Store | **High rejection risk** — `com.apple.security.screen-capture` entitlement has caused validation failures |
| Scope | Per-app or full display audio |

**Verdict**: Viable as a fallback for macOS 13.0–14.1 only. The Screen Recording permission is overly invasive for an audio-only use case, and macOS Sequoia's monthly re-prompting makes UX poor.

#### Approach 3: Virtual Audio Devices (Not recommended as primary)

BlackHole (v0.6.1, Jan 2026) is actively maintained, works on Intel and Apple Silicon, requires no kernel extensions. However, it requires users to install third-party software — unacceptable as a primary strategy when Core Audio taps are available.

**Verdict**: Document as optional advanced setup for macOS 12 and below. Not part of default app flow.

#### macOS Recommendation

| macOS Version | Strategy |
|---------------|----------|
| 14.2+ (Sonoma+) | Core Audio taps (primary) |
| 13.0–14.1 (Ventura–early Sonoma) | ScreenCaptureKit with Screen Recording permission |
| 12 and below | Not supported (document BlackHole as manual option) |

---

### Windows

#### WASAPI Loopback Capture

The standard, well-established approach. Used by OBS, Discord, and most Windows audio applications.

| Aspect | Detail |
|--------|--------|
| API | `IAudioClient::Initialize` with `AUDCLNT_STREAMFLAGS_LOOPBACK` |
| Permission | **None required** — any app can open a loopback stream |
| Mode | Shared mode only (`AUDCLNT_SHAREMODE_SHARED`) |
| Scope | Captures all system audio output on the selected endpoint |
| Event-driven | Supported natively on Windows 10 1703+ |
| DRM | DRM-protected content cannot be captured |
| Reference | [Microsoft docs](https://learn.microsoft.com/en-us/windows/win32/coreaudio/loopback-recording) |

**Per-app capture**: Windows 10+ added `ActivateAudioInterfaceAsync` for per-process audio capture (used by OBS 27+ "Application Audio Capture").

**Flutter integration**: No existing Flutter package wraps WASAPI loopback. Implementation requires a C++ native plugin exposed via platform channels or Dart FFI. The [miniaudio](https://miniaud.io/) library (single-header C, v0.11.23) supports WASAPI loopback in its low-level API and could simplify the native layer.

#### Windows Recommendation

WASAPI loopback is the clear and only practical choice. Zero permissions, well-documented, battle-tested.

---

### Linux

#### PulseAudio Monitor Sources

| Aspect | Detail |
|--------|--------|
| API | PulseAudio simple or async API with monitor source |
| Permission | **None** for native apps |
| Discovery | `pactl list sources short` — monitors named "Monitor of [sink]" |
| Scope | Captures all audio on a specific output sink |

Every PulseAudio output sink automatically has a companion monitor source. Opening the monitor source as a regular capture input gives all audio playing through that sink.

#### PipeWire Compatibility

PipeWire (default on Fedora 34+, Ubuntu 22.10+, most modern distros) maintains full PulseAudio compatibility. Monitor sources appear and work identically. The PipeWire Stream API (`pw_stream_connect`) provides a native alternative but is unnecessary given the compatibility layer.

**Sandboxed apps**: Flatpak/Snap apps may need xdg-desktop-portal integration for permission. Native (non-sandboxed) Flutter desktop apps have unrestricted access.

#### Flutter/Dart Packages

- [`pulseaudio`](https://pub.dev/packages/pulseaudio): Dart FFI wrapper. Can enumerate sources including monitors and capture from them.
- `record`: Microphone only, no monitor source selection.

#### Linux Recommendation

PulseAudio monitor source capture via the `pulseaudio` Dart package or direct FFI. Works on both PulseAudio and PipeWire systems with no additional effort.

---

## Existing Flutter Packages

| Package | Version | macOS | Windows | Linux | Maturity |
|---------|---------|-------|---------|-------|----------|
| `desktop_audio_capture` | 0.0.2 | ScreenCaptureKit | Unclear | Unclear | Very early, 2 likes |
| `shadow_plugin` | — | ScreenCaptureKit | No | No | macOS only |
| `record` | Stable | Mic only | Mic only | Mic only | No loopback |
| `flutter_sound` | Stable | Mic only | Mic only | Mic only | No loopback |
| `pulseaudio` | Stable | N/A | N/A | PulseAudio FFI | Linux only |

**Conclusion**: No existing package meets our needs. A custom plugin is required.

---

## Implementation Recommendation

### Custom Plugin: `zip_audio_capture`

A single Flutter plugin with per-platform native implementations:

| Platform | Native Language | API | Permission |
|----------|----------------|-----|------------|
| macOS 14.2+ | Swift | Core Audio taps | System Audio Recording Only |
| macOS 13–14.1 | Swift | ScreenCaptureKit | Screen Recording |
| Windows | C++ | WASAPI loopback | None |
| Linux | C (via FFI) | PulseAudio | None |

### Plugin Surface Area

```dart
abstract class SystemAudioCapture {
  /// Whether system audio capture is available on this platform.
  Future<bool> isAvailable();

  /// Available system audio sources (sinks/endpoints).
  Future<List<AudioSource>> availableSources();

  /// Start capturing from a specific source.
  /// Returns a stream of PCM audio buffers.
  Stream<Uint8List> capture(AudioSource source);

  /// Stop capture.
  Future<void> stop();
}
```

### Implementation Priority

1. **Windows (WASAPI)** — Simplest, no permissions, fastest to validate
2. **Linux (PulseAudio)** — Simple, existing Dart FFI wrapper available
3. **macOS (Core Audio taps)** — Most complex, requires Swift bridge and entitlements

### Effort Estimate

| Platform | Complexity | Notes |
|----------|-----------|-------|
| Windows | Medium | C++ WASAPI code + platform channel. miniaudio may simplify |
| Linux | Low-Medium | Dart FFI to PulseAudio. `pulseaudio` package may suffice |
| macOS | Medium-High | Swift Core Audio taps + aggregate device setup + entitlements |
| Plugin shell | Low | Federated plugin structure, platform channel interface |

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| macOS Core Audio taps API changes | Low | Apple-documented public API, unlikely to break |
| macOS 13 users on ScreenCaptureKit path get invasive permission | Medium | Document clearly; Core Audio taps path (14.2+) is primary |
| App Store rejection for screen capture entitlement | High | Avoid ScreenCaptureKit path for App Store builds; Core Audio taps don't need it |
| WASAPI loopback DRM blocking | Low | Affects only DRM content (Spotify DRM, etc.); user-facing limitation, not a bug |
| PipeWire compatibility regression | Low | PulseAudio compat layer is a PipeWire priority; tested on major distros |
| No audio when no playback device | Low | Graceful empty state — system audio option hidden per FR-6.2 design |

---

## Exit Criteria Assessment

| Criterion | Status |
|-----------|--------|
| Feasibility documented per platform | PASS — all three platforms have viable approaches |
| Permission model documented | PASS — macOS (System Audio Recording Only / Screen Recording), Windows (none), Linux (none) |
| Implementation approach defined | PASS — custom plugin with per-platform native code |
| Limitations identified | PASS — macOS version matrix, DRM on Windows, sandboxing on Linux |
| Recommendation for Unit 2/6 | PASS — system audio is feasible; implement in Unit 6 (Zip Broadcast) |

---

## Impact on Construction Units

- **Unit 2 (Platform STT + Audio)**: Microphone capture only. System audio is out of scope for Unit 2.
- **Unit 6 (Zip Broadcast)**: System audio capture is in scope. Use this spike's recommendations to implement `zip_audio_capture` plugin. FR-6.2 implementation should follow the per-platform strategy above.
- **Graceful absence**: Per S-06 acceptance criteria, system audio options must not appear on unsupported platforms/versions. The `isAvailable()` check handles this.
