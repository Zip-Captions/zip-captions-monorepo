# Unit 2: zip_core — Functional Design Clarification Questions

## Status: Resolved

All questions and contradictions below were resolved during the Functional Design stage. Authoritative answers are captured in the functional design artifacts:
- `aidlc-docs/construction/zip-core/functional-design/domain-entities.md`
- `aidlc-docs/construction/zip-core/functional-design/business-logic-model.md`
- `aidlc-docs/construction/zip-core/functional-design/business-rules.md`

---

## Resolved: Question 6 (BaseSettingsNotifier key prefix)

Resolved as **Option A**: abstract getter (`String get keyPrefix`) that each subclass overrides.

See `business-logic-model.md` BaseSettingsNotifier section — keys use format `{keyPrefix}.{fieldName}`.

---

## Resolved: Contradiction 1 (Inter as sole typeface vs. v1 font selection)

Resolved as: **Inter is the UI chrome font** (labels, buttons, navigation); the 8 v1 fonts are user-selectable **caption display** fonts via the `CaptionFont` enum.

See `domain-entities.md` CaptionFont enum (line 49+) and `business-logic-model.md` AppTheme section.

---

## Resolved: Contradiction 2 (Dark-first design spec vs. system/dark/light theme modes)

Resolved as: The Monolith Editorial spec defines the **dark theme**; a complementary light theme was designed from the same palette. `ThemeModeSetting` enum supports `system` (default), `dark`, and `light`.

See `domain-entities.md` ThemeModeSetting enum and `business-logic-model.md` AppTheme section (dark and light palette definitions).

---

## Note on Q5 (fonts): v1 Font Availability in Flutter

All 8 v1 fonts are available via Flutter's `google_fonts` package, which fetches and caches them at runtime. Alternatively, the `.ttf` files can be bundled directly in the app assets for offline availability. Both approaches work cross-platform (iOS, Android, macOS, Windows, Linux, web).

User selected Option B in NFR Requirements (bundle .ttf assets, offline-first). `google_fonts` flagged for dependency approval.
