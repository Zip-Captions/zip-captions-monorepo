# Components — Zip Captions v2, Phase 0

## Package Overview

| Package | Type | Role |
|---|---|---|
| `zip_core` | Dart library | Shared providers, models, l10n, theme — imported by both apps |
| `zip_captions` | Flutter app | Personal user app; extends zip_core for captions-specific settings and strings |
| `zip_broadcast` | Flutter app | Broadcaster app; extends zip_core for broadcast-specific settings and strings |
| `zip_supabase` | Infrastructure | Docker Compose, SQL migrations, .env templates — no Dart code in Phase 0 |

---

## zip_core Components

### Providers

#### `LocaleProvider`
- **File**: `lib/src/providers/locale_provider.dart`
- **Type**: `@riverpod` Notifier, state type: `Locale`
- **Responsibility**: Manages the user-selected display locale. Persisted via `shared_preferences`. Migrated from PoC `locale_provider.dart`.
- **Visibility**: Exported from `package:zip_core/zip_core.dart`

#### `LocaleInfoProvider`
- **File**: `lib/src/providers/locale_info_provider.dart`
- **Type**: `@riverpod` (auto-dispose, returns `List<SpeechLocale>`)
- **Responsibility**: Exposes the list of locales available to the user. In Phase 0, returns a stub list. Phase 1 populates from the active `SttEngine`. Migrated from PoC `locale_info_provider.dart`.
- **Visibility**: Exported

#### `BaseSettingsNotifier` / `baseSettingsProvider`
- **File**: `lib/src/providers/settings/base_settings_notifier.dart`
- **Type**: Abstract Dart class (NOT directly Riverpod-annotated); each app subclasses this with `@riverpod` annotation on the concrete class.
- **Responsibility**: Shared display settings (scroll direction, text size, font family, contrast mode, max visible lines). Persisted via `shared_preferences`. Each app creates its own `@riverpod`-annotated concrete subclass, giving each app its own independent settings store and allowing app-specific fields to be added without modifying zip_core.
- **Visibility**: Exported as abstract base; concrete subclasses live in each app package.

#### `RecordingStateNotifier` / `recordingStateProvider`
- **File**: `lib/src/providers/recording_state_notifier.dart`
- **Type**: `@riverpod` Notifier, state type: `RecordingState` (sealed class)
- **Responsibility**: State machine for recording lifecycle (idle → recording → paused → stopped). Phase 0 implementation is a stub — state transitions are wired up but STT engine integration is Phase 1. Migrated and restructured from PoC `recording_provider.dart`.
- **Security constraint**: MUST NOT log any transcript text content, current segments, or finalized segments in any log output (SECURITY-03, AGENTS.md absolute constraint). The PoC's `print()` statements logging segment text must not be carried forward.
- **Visibility**: Exported

#### `sttEngineProvider`
- **File**: `lib/src/providers/stt_engine_provider.dart`
- **Type**: `@riverpod` AsyncNotifier, state type: `SttEngine`
- **Responsibility**: Stub provider. Phase 0: throws `UnimplementedError` with message "STT engine implementation is Phase 1". Phase 1: returns the platform-appropriate `SttEngine` implementation.
- **Visibility**: Exported (interface only; implementation is Phase 1)

---

### Models

#### `AppSettings`
- **File**: `lib/src/models/app_settings.dart`
- **Type**: `@freezed` data class
- **Responsibility**: Immutable value object for shared display settings. Fields: `scrollDirection`, `textSize`, `fontFamily`, `contrastMode`, `maxVisibleLines`. *(Inception-phase names; `textSize`→`captionTextSize`, `fontFamily`→`captionFont`, `contrastMode`→`themeModeSetting` per construction-phase functional design — see `component-methods.md` supersession note.)*
- **Visibility**: Exported

#### `RecordingState`
- **File**: `lib/src/models/recording_state.dart`
- **Type**: Sealed class
- **Responsibility**: Represents the recording state machine states. Values: `idle`, `recording`, `paused`, `stopped`. Phase 1 extends `stopped` to carry accumulated segment data.
- **Visibility**: Exported

#### `SpeechLocale`
- **File**: `lib/src/models/speech_locale.dart`
- **Type**: `@freezed` data class
- **Responsibility**: Represents a locale available for speech recognition. Fields: `localeId` (BCP-47), `displayName`. Migrated from PoC `speech_locale.dart`.
- **Visibility**: Exported

---

### Localization

#### `ZipCoreLocalizations`
- **Directory**: `lib/l10n/`
- **Files**: `app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_id.arb`, `app_it.arb`, `app_pl.arb`, `app_pt.arb`, `app_uk.arb`
- **Responsibility**: Shared strings used by both apps — settings labels, common error messages, accessibility labels. Seeded from v1 translation JSON files (ar, de, es, fr, id, it, pl, pt, uk), all tagged `machine-generated`. zh excluded due to source quality.
- **Generated class**: `ZipCoreLocalizations` (via Flutter l10n codegen)
- **Visibility**: Exported via `l10n.yaml`

---

### Theme

#### `AppTheme`
- **File**: `lib/src/theme/app_theme.dart`
- **Responsibility**: Provides Material `ThemeData` for both apps (light and dark). Both apps use this factory; app-specific visual customization is passed as overrides. Migrated and generalized from PoC `app_theme.dart`.
- **Visibility**: Exported

---

## zip_captions Components

### Application

#### `ZipCaptionsApp`
- **File**: `lib/app.dart`
- **Type**: `ConsumerWidget` (Riverpod)
- **Responsibility**: App root. Wraps in `ProviderScope`. Configures `MaterialApp` with `AppTheme.light()` / `AppTheme.dark()`, `ZipCaptionsLocalizations`, and initial route to `HomeScreen`.

#### `HomeScreen`
- **File**: `lib/screens/home_screen.dart`
- **Responsibility**: Hello-world home screen for Phase 0. Displays app name and a placeholder "Start Captioning" button (non-functional in Phase 0).

### Providers

#### `ZipCaptionsSettingsNotifier` / `zipCaptionsSettingsProvider`
- **File**: `lib/providers/zip_captions_settings_notifier.dart`
- **Type**: `@riverpod` Notifier extending `BaseSettingsNotifier`
- **Responsibility**: Settings store for zip_captions. Phase 0 has no additional fields beyond `BaseSettingsNotifier`. Exists as a separate provider so zip_captions settings are stored independently from zip_broadcast settings.

### Localization

#### `ZipCaptionsLocalizations`
- **Directory**: `lib/l10n/`
- **Files**: `app_en.arb` (and per-language files as needed)
- **Responsibility**: Strings specific to zip_captions — app name ("Zip Captions"), app-specific screen titles, onboarding copy.

---

## zip_broadcast Components

### Application

#### `ZipBroadcastApp`
- **File**: `lib/app.dart`
- **Type**: `ConsumerWidget` (Riverpod)
- **Responsibility**: App root. Same structure as `ZipCaptionsApp` but uses `ZipBroadcastLocalizations`.

#### `HomeScreen`
- **File**: `lib/screens/home_screen.dart`
- **Responsibility**: Hello-world home screen. Displays "Zip Broadcast" and a placeholder "Start Broadcasting" button (non-functional in Phase 0).

### Providers

#### `ZipBroadcastSettingsNotifier` / `zipBroadcastSettingsProvider`
- **File**: `lib/providers/zip_broadcast_settings_notifier.dart`
- **Type**: `@riverpod` Notifier extending `BaseSettingsNotifier`
- **Responsibility**: Settings store for zip_broadcast. Phase 0 has no additional fields. Phase 2 adds broadcast-specific settings (relay toggle, output targets) as additional fields.

### Localization

#### `ZipBroadcastLocalizations`
- **Directory**: `lib/l10n/`
- **Files**: `app_en.arb` (and per-language files as needed)
- **Responsibility**: Strings specific to zip_broadcast — app name ("Zip Broadcast"), broadcaster-specific labels.

---

## zip_supabase Components (Infrastructure Only — No Dart)

| File/Directory | Purpose |
|---|---|
| `docker-compose.yml` | Local Supabase stack (Postgres, GoTrue, Storage, Realtime, Edge Functions runtime) |
| `supabase/config.toml` | Supabase CLI configuration for local dev |
| `migrations/20260326000000_initial.sql` | Empty schema; RLS enabled at database level |
| `.env.example` | Template documenting required environment variables; actual `.env` is gitignored |
| `README.md` | Local dev setup instructions |
