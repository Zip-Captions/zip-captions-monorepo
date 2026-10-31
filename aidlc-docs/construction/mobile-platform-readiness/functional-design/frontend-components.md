# Frontend Components: Unit 10, Mobile Platform Readiness (G10)

**Date**: 2026-10-25. One change in `zip_captions`.

## `RecordingScreen` (existing, changed)

- **State added:** a local `StartFailureView? _failure` (E3) and a `_starting` flag. No new provider.
- **initState:** the existing post-frame callback calls `start()` as today, but awaits it. On completion, if mounted, the state is still `IdleState` and `lastError != null`, it sets `_failure = StartFailureView.from(lastError)`. A successful start leaves `_failure` null and the existing caption UI is unchanged.
- **Build:** when `_failure != null`, show a failure panel in place of the caption area: icon, localised text, then `Try again` (always), `Open settings` (when `showOpenSettings`), and `Back` (to Home, `context.go('/')`).
- **Controls bar:** `RecordingControlsBar` shows a `CircularProgressIndicator` whenever the state is `IdleState` (`recording_controls_bar.dart:33-44`). A failed start leaves the state at `IdleState`, so while `_failure != null` the screen does not build the controls bar; otherwise the spinner would run under the failure panel indefinitely. It returns when `_failure` is cleared (Try again) or the start succeeds.
- **Platform:** `StartFailureView.from` receives `defaultTargetPlatform` and `kIsWeb`. "Open settings" is built only when `showOpenSettings` (iOS and Android).
- **Try again:** clears `_failure`, sets `_starting`, awaits `start()` again, repeats the check.
- **Open settings:** `recordingNotifier.openMicrophoneSettings()`.
- **Unchanged:** the `StoppedState` → `/history` listener, appearance panel, pop-out banner and toggle.
- **Strings:** new localised strings go in `l10n/arb/app_en.arb` and are generated with `flutter gen-l10n`. Generated Dart l10n files are never edited by hand. Keys are named in the Code Generation plan.
- **Logging:** the screen logs nothing about the error beyond its kind.

## `HomeScreen`

Unchanged.

## API integration points

None (no backend). Platform calls: `openAppSettings()` through the existing notifier method.
