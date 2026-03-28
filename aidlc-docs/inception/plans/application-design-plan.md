# Application Design Plan — Zip Captions v2, Phase 0

## Execution Plan

- [x] Answer clarifying questions (Questions 1–4 below)
- [x] Generate `components.md` — package and component definitions with responsibilities
- [x] Generate `component-methods.md` — Riverpod provider signatures and key method interfaces
- [x] Generate `services.md` — service layer and orchestration patterns
- [x] Generate `component-dependency.md` — inter-package dependency graph and data flow
- [x] Generate `application-design.md` — consolidated summary document
- [x] Validate design completeness and consistency

---

## Clarifying Questions

Most of Phase 0's architecture is unambiguous from the specification documents. The four questions below represent genuine design decision points where your preference determines the component structure.

---

## Question 1
For the localization scaffold, where should app-specific strings live?

Both apps will share common strings (e.g., error messages, settings labels) from `zip_core`, but each app also has strings unique to it (app name, app-specific screen titles, onboarding copy).

A) All strings in `zip_core` — one unified ARB for everything; both apps reference the same localizations
B) Shared strings in `zip_core`, app-specific strings in each app's own `lib/l10n/` — two ARB namespaces
C) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 2
For `SettingsProvider`, should settings be a single unified model shared between both apps, or should each app have its own settings scope?

Context: The PoC has one settings model. Phase 0 requirements list: scroll direction, text size, font, contrast. `zip_broadcast` will eventually add broadcast-specific settings (output targets, relay preferences) that don't apply to `zip_captions`.

A) Single unified `SettingsProvider` in `zip_core` — both apps share one settings model; broadcast-specific settings are added to it later when needed
B) Base `SettingsProvider` in `zip_core` for shared settings; each app subclasses or extends it for app-specific settings
C) Separate providers — `ZipCaptionsSettingsProvider` and `ZipBroadcastSettingsProvider` — both in `zip_core` sharing a common base
X) Other (please describe after [Answer]: tag below)

[Answer]: B)

---

## Question 3
Does `packages/zip_supabase/` contain any Dart code in Phase 0?

The package will hold Docker Compose, SQL migrations, and eventually TypeScript Deno Edge Functions. The question is whether it also contains a Dart client helper (e.g., Supabase connection configuration, client factory) that `zip_captions` and `zip_broadcast` would import.

A) No Dart code in Phase 0 — `zip_supabase` is infrastructure-only (Docker, SQL); Flutter apps connect to Supabase directly using `supabase_flutter` with locally configured URLs
B) Yes — include a minimal Dart library in `zip_supabase` with a `SupabaseConfig` class that centralizes the Supabase URL and anon key; apps import from `package:zip_supabase/`
X) Other (please describe after [Answer]: tag below)

[Answer]: A)

---

## Question 4
Should a shared app theme / design tokens component live in `zip_core`, or is each app responsible for its own theme?

The PoC has `lib/theme/app_theme.dart`. For Phase 0 hello-world shells, both apps can share a single `AppTheme` in `zip_core`, or each app can define its own independently (allowing them to diverge visually later).

A) Shared `AppTheme` in `zip_core` — a single Material `ThemeData` factory used by both apps; apps can customize later by passing overrides
B) Per-app theme — each app defines its own `AppTheme`; no shared theme in `zip_core`
X) Other (please describe after [Answer]: tag below)

[Answer]: A)
