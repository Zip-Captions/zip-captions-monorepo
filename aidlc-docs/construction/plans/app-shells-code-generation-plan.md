# Code Generation Plan — Unit 3: App Shells

## Unit Context

**Packages**: `packages/zip_captions/`, `packages/zip_broadcast/`
**Branch**: `feature/phase0-app-shells`
**Depends on**: Unit 1 merged (monorepo scaffold), Unit 2 merged (zip_core library)

### Requirements Implemented

| Requirement | Description |
|---|---|
| FR-01.3 | `zip_captions` Flutter app shell |
| FR-01.4 | `zip_broadcast` Flutter app shell |
| FR-05.4 | Both apps consume `zip_core` l10n + own app-specific ARBs |
| NFR-01.1 | `very_good_analysis` zero warnings |
| NFR-01.3 | Package imports only |
| NFR-01.4 | `snake_case` files, `PascalCase` classes, `camelCase` variables |
| NFR-02.1 | At least one passing test per package |

### Existing Files (from Unit 1 scaffold)

Both packages have: `pubspec.yaml`, `lib/main.dart` (stub), `test/widget_test.dart` (stub), `analysis_options.yaml`, `AGENTS.md`.

### File Organization

```
packages/zip_captions/
  lib/
    main.dart                         # App entry point with ProviderScope
    src/
      app.dart                        # ZipCaptionsApp ConsumerWidget
      home_screen.dart                # Hello-world home screen
      providers/
        settings_notifier.dart        # ZipCaptionsSettingsNotifier
        settings_notifier.g.dart      # generated
  l10n/
    l10n.yaml                         # App-specific l10n config
    arb/
      app_en.arb                      # App-specific English strings
  test/
    app_test.dart                     # Widget test for app shell

packages/zip_broadcast/
  lib/
    main.dart                         # App entry point with ProviderScope
    src/
      app.dart                        # ZipBroadcastApp ConsumerWidget
      home_screen.dart                # Hello-world home screen
      providers/
        settings_notifier.dart        # ZipBroadcastSettingsNotifier
        settings_notifier.g.dart      # generated
  l10n/
    l10n.yaml                         # App-specific l10n config
    arb/
      app_en.arb                      # App-specific English strings
  test/
    app_test.dart                     # Widget test for app shell
```

---

## Steps

### Step 1: Update zip_captions pubspec.yaml
- [x] Add runtime dependencies: `zip_core` (path), `flutter_riverpod`, `riverpod_annotation`, `shared_preferences`
- [x] Add dev dependencies: `riverpod_generator`, `build_runner`
- [x] Sort dependencies alphabetically
- [x] Run `melos bootstrap` to verify resolution

### Step 2: Update zip_broadcast pubspec.yaml
- [x] Same dependency additions as Step 1

### Step 3: Create ZipCaptionsSettingsNotifier
- [x] Create `lib/src/providers/settings_notifier.dart`
- [x] Concrete subclass of `BaseSettingsNotifier` with `keyPrefix => 'zip_captions'`
- [x] `@riverpod` annotation

### Step 4: Create ZipBroadcastSettingsNotifier
- [x] Create `lib/src/providers/settings_notifier.dart`
- [x] Concrete subclass of `BaseSettingsNotifier` with `keyPrefix => 'zip_broadcast'`
- [x] `@riverpod` annotation

### Step 5: Create ZipCaptionsApp
- [x] Create `lib/src/app.dart` — `ConsumerWidget` with `MaterialApp`, `AppTheme.dark()` default, localization delegates
- [x] Home route points to `HomeScreen`

### Step 6: Create ZipBroadcastApp
- [x] Create `lib/src/app.dart` — same structure, `Zip Broadcast` title

### Step 7: Create HomeScreen for both apps
- [x] `lib/src/home_screen.dart` in each package
- [x] Simple `Scaffold` with `AppBar` showing app title, body with centered placeholder text
- [x] `ConsumerWidget` to demonstrate Riverpod integration

### Step 8: Update main.dart for both apps
- [x] Replace stub `main.dart` with: `SharedPreferences.getInstance()`, `ProviderScope` with `sharedPreferencesProvider` override, run app widget
- [x] `WidgetsFlutterBinding.ensureInitialized()` before async work

### Step 9: Create app-specific l10n scaffold
- [x] Create `l10n/l10n.yaml` for each app (pointing to app-specific ARB dir)
- [x] Create `l10n/arb/app_en.arb` for each app with app-specific string keys (app name, home screen text)

### Step 10: Run build_runner for riverpod code generation
- [x] Run `dart run build_runner build --delete-conflicting-outputs` in each app package
- [x] Verify `.g.dart` files generated for settings notifiers

### Step 11: Write widget tests
- [x] Replace `test/widget_test.dart` with `test/app_test.dart` in each app
- [x] Test: app renders without error
- [x] Test: home screen shows expected text
- [x] Uses `ProviderScope` with mock `SharedPreferences`

### Step 12: Final verification
- [x] `dart analyze` on both packages — zero warnings
- [x] `flutter test` on both packages — all tests pass
- [x] Verify no `provider` dependency in either package
- [x] Verify `zip_core` dependency present via path

---

## Exit Criteria Checklist

- [x] `flutter run` launches `zip_captions` on iOS simulator (shows home screen)
- [x] `flutter run` launches `zip_broadcast` on macOS (shows home screen)
- [x] `melos run test` passes for both app packages
- [x] No `provider` dependency in either app package
- [x] Both apps consume `zip_core` providers and theme
- [x] App-specific l10n ARB files present
- [x] `very_good_analysis` zero warnings on both packages
