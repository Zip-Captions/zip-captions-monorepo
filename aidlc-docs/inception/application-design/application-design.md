# Application Design — Zip Captions v2, Phase 0

## Summary

Phase 0 establishes the monorepo architecture that all subsequent phases build on. The design is intentionally minimal: providers are stubs or simple persistence wrappers, UI is hello-world, and the focus is on getting the right structure in place.

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| State management | Riverpod (`riverpod_generator`) only | ADR-003; replaces PoC's `provider` package |
| Settings architecture | Abstract `BaseSettingsNotifier` in `zip_core`; concrete subclass per app | Allows app-specific settings fields in later phases without modifying shared code |
| Localization | Shared strings in `zip_core`; app-specific strings in each app's `lib/l10n/` | Clean separation; apps own their branding strings |
| App theme | Shared `AppTheme` in `zip_core` | Both apps share a single Material 3 design foundation; customizable via overrides |
| `zip_supabase` Dart code | None in Phase 0 | Infrastructure-only; Dart client wrapper deferred to Phase 3 (auth/encryption) |
| Transcript logging | Prohibited at all levels | Absolute constraint (AGENTS.md, SECURITY-03) |

---

## Package Structure

```
zip-captions-monorepo/
  packages/
    zip_core/
      lib/
        src/
          models/
            app_settings.dart          (freezed)
            recording_state.dart       (sealed class)
            speech_locale.dart         (freezed)
          providers/
            locale_provider.dart
            locale_info_provider.dart
            settings/
              base_settings_notifier.dart   (abstract)
            recording_state_notifier.dart
            stt_engine_provider.dart        (stub)
          services/
            stt/
              stt_engine.dart              (abstract interface)
          theme/
            app_theme.dart
        l10n/
          app_en.arb
          app_ar.arb  (+ de, es, fr, id, it, pl, pt, uk)
        zip_core.dart                  (barrel export)
      test/
        providers/
          locale_provider_test.dart
          settings_notifier_test.dart
          recording_state_notifier_test.dart
        models/
          app_settings_test.dart

    zip_captions/
      lib/
        app.dart                       (ZipCaptionsApp)
        main.dart
        providers/
          zip_captions_settings_notifier.dart
        screens/
          home_screen.dart
        l10n/
          app_en.arb
      test/
        widget_test.dart

    zip_broadcast/
      lib/
        app.dart                       (ZipBroadcastApp)
        main.dart
        providers/
          zip_broadcast_settings_notifier.dart
        screens/
          home_screen.dart
        l10n/
          app_en.arb
      test/
        widget_test.dart

    zip_supabase/
      docker-compose.yml
      supabase/
        config.toml
        migrations/
          20260326000000_initial.sql
      .env.example
      README.md
```

---

## Component Responsibilities (Summary)

| Component | Package | Phase 0 Status | Notes |
|---|---|---|---|
| `LocaleProvider` | zip_core | Full implementation | Persists selected locale |
| `LocaleInfoProvider` | zip_core | Stub (empty list) | Phase 1: populated from SttEngine |
| `BaseSettingsNotifier` | zip_core | Full implementation | Shared settings fields |
| `ZipCaptionsSettingsNotifier` | zip_captions | Full implementation | Key-prefixed subclass |
| `ZipBroadcastSettingsNotifier` | zip_broadcast | Full implementation | Key-prefixed subclass |
| `RecordingStateNotifier` | zip_core | Stub (state machine only) | Phase 1: wired to SttEngine |
| `sttEngineProvider` | zip_core | Stub (throws) | Phase 1: platform engine |
| `SttEngine` (interface) | zip_core | Interface only | Phase 1: PlatformSttEngine |
| `AppSettings` | zip_core | Full implementation | Freezed value object |
| `RecordingState` | zip_core | Full implementation | Sealed class |
| `SpeechLocale` | zip_core | Full implementation | Freezed value object |
| `AppTheme` | zip_core | Full implementation | Material 3 light + dark |
| `ZipCaptionsApp` | zip_captions | Hello-world shell | Phase 1: recording screen |
| `ZipBroadcastApp` | zip_broadcast | Hello-world shell | Phase 2: broadcast screen |
| Docker Compose | zip_supabase | Full implementation | Local Supabase stack |

---

## Security Design Notes

1. **No transcript logging** (SECURITY-03, AGENTS.md): `RecordingStateNotifier` and all future providers that handle text content must never log, emit to analytics, or surface transcript text. This constraint is explicit in `RecordingStateNotifier`'s documentation and will be enforced in code review.

2. **No hardcoded credentials** (SECURITY-09, SECURITY-12): `zip_supabase` uses `.env` + `.env.example`. Flutter apps read Supabase URL and anon key from `--dart-define` at build time, never from source.

3. **Dependency pinning** (SECURITY-10): `pubspec.lock` committed. All packages use exact version constraints in lock file.

---

## Detailed Artifacts

- [components.md](components.md) — Full component definitions and responsibilities
- [component-methods.md](component-methods.md) — Provider and model method signatures
- [services.md](services.md) — Service layer and orchestration patterns
- [component-dependency.md](component-dependency.md) — Dependency graph and data flows
