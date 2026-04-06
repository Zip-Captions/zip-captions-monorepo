# Platform Setup — Zip Captions

## Build Results (Phase 0 Spike)

| Platform | App | Result | Runner | Notes |
|---|---|---|---|---|
| macOS | zip_captions | **Pass** | Local (macOS) | 36.0MB .app |
| macOS | zip_broadcast | **Pass** | Local (macOS) | 36.0MB .app |
| Android | zip_captions | Untested locally | GitHub Actions (ubuntu-latest) | Scaffolded; tested via CI |
| iOS | zip_captions | Untested locally | GitHub Actions (macos-latest) | Scaffolded; tested via CI |
| Linux | zip_captions | Untested locally | GitHub Actions (ubuntu-latest) | Scaffolded; tested via CI |
| Windows | zip_captions | Untested locally | GitHub Actions (windows-latest) | Scaffolded; tested via CI |

## Prerequisites by Platform

### macOS

- macOS 13+ (Ventura or later)
- Xcode 15+ (install from App Store or developer.apple.com)
- Xcode command-line tools: `xcode-select --install`
- CocoaPods: `brew install cocoapods` or `gem install cocoapods`
- Flutter SDK (see below)

```bash
flutter build macos
# Output: build/macos/Build/Products/Release/<app>.app
```

### iOS

- macOS with Xcode 15+
- iOS Simulator or physical device
- CocoaPods installed
- For physical device: Apple Developer account + provisioning profile

```bash
flutter build ios --no-codesign    # Simulator / CI
flutter build ios                   # Device (requires codesign)
```

### Android

- Android Studio or Android SDK command-line tools
- JDK 17 (bundled with Android Studio or install separately)
- Android SDK 34+ with build-tools
- Accept licenses: `flutter doctor --android-licenses`

```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Linux

- Ubuntu 22.04+ (or equivalent)
- Build dependencies:
  ```bash
  sudo apt-get install -y ninja-build libgtk-3-dev
  ```
- clang (usually pre-installed on Ubuntu)

```bash
flutter build linux
# Output: build/linux/x64/release/bundle/
```

### Windows

- Windows 10/11
- Visual Studio 2022 with "Desktop development with C++" workload
- Flutter SDK

```bash
flutter build windows
# Output: build\windows\x64\runner\Release\
```

## Flutter SDK Setup

All platforms require the Flutter SDK:

```bash
# Version used in this project
flutter --version
# Flutter 3.38.7 • channel stable

# Verify all platform tools
flutter doctor -v
```

## Known Issues

- **Xcode "Run Script" warning**: macOS/iOS builds show a warning about the "Run Script" build phase not specifying outputs. This is a known Flutter issue and does not affect the build.
- **zip_broadcast platform builds**: Only zip_captions is included in CI build verification. zip_broadcast uses the same scaffolding and is expected to build identically.

## CI Build Verification

Platform builds are verified via `.github/workflows/build-verify.yml`:
- Triggered manually (`workflow_dispatch`) or on PRs to main/develop
- Runs 5 parallel jobs: Android, iOS, macOS, Linux, Windows
- All builds use zip_captions as the test target
