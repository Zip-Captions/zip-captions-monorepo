# Component Dependencies — Zip Captions v2, Phase 0

## Package Dependency Graph

```
zip_captions ──depends on──> zip_core
zip_broadcast ──depends on──> zip_core
zip_supabase: standalone (no Dart deps; no reverse dependency from Flutter apps in Phase 0)
```

No circular dependencies. `zip_core` has no dependency on either app package.

### Text Alternative

```
+------------------+         +------------------+
|  zip_captions    |         |  zip_broadcast   |
|  (Flutter app)   |         |  (Flutter app)   |
+------------------+         +------------------+
         |                           |
         |  depends on               |  depends on
         |                           |
         v                           v
+------------------------------------------------+
|               zip_core                         |
|  (Dart shared library)                         |
|  providers | models | l10n | theme             |
+------------------------------------------------+

+------------------+
|  zip_supabase    |  (standalone — Docker, SQL, .env)
|  infrastructure  |  No Dart; no app dependency
+------------------+
```

---

## Dependency Matrix

| Consumer | zip_core | zip_captions | zip_broadcast | zip_supabase |
|---|---|---|---|---|
| zip_captions | IMPORTS | — | none | none |
| zip_broadcast | IMPORTS | none | — | none |
| zip_core | — | none | none | none |
| zip_supabase | none | none | none | — |

---

## Inter-Component Communication Patterns

### Pattern 1: Provider State → Widget

Widgets observe provider state via `ref.watch`. State changes cause widget rebuilds.

```
RecordingStateNotifier.state (RecordingState)
      |
      | ref.watch(recordingStateProvider)
      v
HomeScreen widget rebuilds with current state
```

### Pattern 2: Widget → Provider Mutation

Widgets trigger state changes via `ref.read(provider.notifier).method()`.

```
User taps "Start" button
      |
      | ref.read(recordingStateProvider.notifier).start()
      v
RecordingStateNotifier.start() → state = RecordingState.recording()
      |
      | notifies all watchers
      v
Widgets rebuild
```

### Pattern 3: Provider → Service (SharedPreferences)

Notifiers read from and write to `shared_preferences` directly. No intermediate service class.

```
BaseSettingsNotifier.build()
      |
      | SharedPreferences.getInstance()
      v
reads 'zip_captions.scroll_direction' etc.
      |
      v
returns AppSettings(...)
```

### Pattern 4: App Settings Isolation

Each app uses its own settings provider with a key prefix, ensuring settings don't bleed across apps (relevant during development when both apps share a simulator/device).

```
zip_captions app
  zipCaptionsSettingsProvider (key prefix: 'zip_captions.')
      |
      v SharedPreferences
  'zip_captions.scroll_direction' = 1

zip_broadcast app
  zipBroadcastSettingsProvider (key prefix: 'zip_broadcast.')
      |
      v SharedPreferences
  'zip_broadcast.scroll_direction' = 0
```

---

## Riverpod Provider Dependency Graph (Phase 0)

```
localeInfoProvider
      (no dependencies)

localeProvider
      (no dependencies — reads SharedPreferences directly)

baseSettingsProvider (abstract — not instantiated directly)
      (no dependencies — reads SharedPreferences directly)
      ^
      |  extended by
      |
      +-- zipCaptionsSettingsProvider (in zip_captions)
      +-- zipBroadcastSettingsProvider (in zip_broadcast)

recordingStateProvider
      (no dependencies in Phase 0 — stub)
      (Phase 1: will depend on sttEngineProvider)

sttEngineProvider
      (no dependencies in Phase 0 — stub throws UnimplementedError)
      (Phase 1: will depend on localeProvider for active locale)
```

---

## Phase 0 → Phase 1 Dependency Evolution

When Phase 1 implements the STT engine, the dependency graph evolves:

```
Before (Phase 0):            After (Phase 1):
recordingStateProvider       recordingStateProvider
   (stub, no deps)              depends on sttEngineProvider
                                depends on localeProvider

sttEngineProvider            sttEngineProvider
   (stub, no deps)              depends on localeProvider
```

No Phase 0 component boundaries need to change for Phase 1 — the stubs are replaced with implementations using the same provider names and interfaces.

---

## Data Flow: Settings Read (Phase 0)

```
App startup
  |
  v
ProviderScope initializes
  |
  v
zipCaptionsSettingsProvider.build()
  |
  v
SharedPreferences.getInstance()
  |
  v
Read 'zip_captions.scroll_direction', 'zip_captions.captionTextSize', ...
  |
  v
Return AppSettings(scrollDirection: ..., captionTextSize: ..., ...)
  # Note: inception-phase names (textSize, fontFamily, contrastMode) superseded;
  # see component-methods.md supersession note
  |
  v
Widgets watching zipCaptionsSettingsProvider rebuild with persisted settings
```

## Data Flow: Locale Selection (Phase 0)

```
User selects locale in Settings screen
  |
  v
ref.read(localeProvider.notifier).setLocale(Locale('fr'))
  |
  v
LocaleProvider persists to SharedPreferences
  |
  v
MaterialApp rebuilds with new locale
  |
  v
ZipCoreLocalizations + app-specific localizations reload with 'fr' strings
```
