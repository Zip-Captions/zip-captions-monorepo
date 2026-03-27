# Functional Design Plan — Unit 2: zip_core Library

## Plan Overview

This plan covers the detailed business logic design for all zip_core components that require non-trivial logic: the `RecordingStateNotifier` state machine, the `BaseSettingsNotifier` persistence model, the `AppSettings` value object, and supporting models and enums.

Components that are stubs or interface-only (`sttEngineProvider`, `SttEngine`, `LocaleInfoProvider`) receive minimal design treatment since their real implementation is deferred to Phase 1.

---

## Steps

- [x] Step 1: Collect user input on open design questions (see questions below)
- [x] Step 2: Define `RecordingState` sealed class — states, allowed transitions, guard conditions, error handling strategy
- [x] Step 3: Define `RecordingStateNotifier` — state machine transition table, method preconditions, Phase 0 stub behavior vs Phase 1 hooks
- [x] Step 4: Define `AppSettings` freezed data class — all fields, types, defaults, validation constraints, and supporting enums (`ScrollDirection`, `CaptionTextSize`, `CaptionFont`, `ThemeModeSetting`)
- [x] Step 5: Define `BaseSettingsNotifier` — persistence strategy (SharedPreferences key naming, serialization format, load/save lifecycle, error recovery)
- [x] Step 6: Define `LocaleProvider` — persistence keys, default resolution (device locale fallback), locale validation
- [x] Step 7: Define `SttEngine` abstract interface — method signatures, callback contracts, security constraints (interface only; no implementation)
- [x] Step 8: Define `SpeechLocale` model — fields, equality, relationship to BCP-47
- [x] Step 9: Define `AppTheme` — Monolith Editorial dark/light palettes, Inter UI chrome, caption font integration
- [x] Step 10: Generate functional design artifacts (business-logic-model.md, business-rules.md, domain-entities.md)

---

## Questions

Please answer each question by filling in the letter choice after the [Answer]: tag.
If none of the options match your needs, choose the last option (Other) and describe your preference.

### Question 1
The PoC's `locale_provider` stores both a display locale (`app_locale`) and a speech recognition locale (`speech_locale`) as separate SharedPreferences keys. The application design assigns `LocaleProvider` to manage the display locale and `LocaleInfoProvider` to expose available STT locales. Where should the **selected** speech locale (the one the user picks for STT) be persisted?

A) In `LocaleProvider` alongside the display locale (same provider, two keys — mirrors the PoC)
B) In a separate `SpeechLocaleProvider` in zip_core (clean separation; display locale and STT locale are independent concerns)
C) Defer to Phase 1 — the selected speech locale is only meaningful when STT is wired up; don't persist it in Phase 0
D) Other (please describe after [Answer]: tag below)

[Answer]: B) STT locale can use a more complex model for language and locale, while display locale is only ever top-level language.

### Question 2
The PoC's `recording_provider` handles errors by setting an `errorMessage` field and transitioning back to a non-recording state. For the `RecordingState` sealed class, how should errors be represented?

A) Add a `RecordingState.error(String message)` variant to the sealed class — errors are a first-class state
B) Keep errors separate from the state machine — add an `errorMessage` field on the notifier (not on the state), cleared on next successful transition
C) Use Riverpod's `AsyncValue` pattern — make `RecordingStateNotifier` an `AsyncNotifier` so error/loading states are built-in
D) Other (please describe after [Answer]: tag below)

[Answer]: D) Errors should be separate from the state machine, but should also have a way to indicate severity, so that they can affect machine state if the error is indication that a process halted, and transient errors can be displayed without affecting state.

### Question 3
`AppSettings` introduces `textSize`, `fontFamily`, and `contrastMode` as new fields beyond what the PoC had. The v1 app used semantic size tiers (xs, sm, md, lg, xl, xxl) rendered as icon-sized visual representations mapping to CSS classes. For Flutter, these tiers can map to Material 3 `TextTheme` styles, which respect system accessibility scaling via `MediaQuery.textScaleFactor`. How should `textSize` be modeled?

A) `CaptionTextSize` enum with tiers mapped to Material 3 `TextTheme` styles — the theme resolves enum to `TextStyle` at render time (xs=bodySmall, sm=bodyLarge, md=headlineSmall, lg=headlineMedium, xl=headlineLarge, xxl=displaySmall)
B) `CaptionTextSize` enum with tiers that resolve to a scale factor (e.g., xs=0.5x, sm=0.75x, md=1.0x, lg=1.25x, xl=1.5x, xxl=2.0x) multiplied against a base `TextStyle` — semantic tiers but theme controls the base size
C) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 4
What `ContrastMode` values should be supported?

A) Two modes: `standard` (default theme colors) and `highContrast` (maximum foreground/background separation)
B) Three modes: `standard`, `highContrast`, and `inverted` (dark-on-light swap regardless of system theme)
C) Four modes: `standard`, `highContrast`, `inverted`, and `custom` (user-defined foreground/background colors — Phase 2+)
D) Other (please describe after [Answer]: tag below)

[Answer]: D) We should support the system `light` or `dark` modes, and allow the user to configure between `system (default)`, `dark` and `light`. Contrast mode is a misnomer, it should be renamed something more appropriate and descriptive, all UI must be adequately contrasting to meet accessibility standards.

### Question 5
For the `fontFamily` field in `AppSettings`, how should available fonts be managed in Phase 0?

A) Hard-coded list of known system-safe fonts (e.g., "default", "serif", "monospace") stored as string keys; extensible later
B) Free-form string — any value accepted; UI provides a picker but the model imposes no constraints
C) Enum-backed (`FontFamily` enum) with a fixed Phase 0 set; extensible by adding enum values in later phases
D) Other (please describe after [Answer]: tag below)

[Answer]: D) is there a way to provide consistent font families across build targets? We can look for accessible fonts, I know that Lexend is open source, for example, so it might be possible to include. We should try to accommodate as many of the fonts from v1, they were specifically selected to be available cross-platform as web fonts.

### Question 6
The `BaseSettingsNotifier` uses SharedPreferences with a per-app key prefix (`zip_captions.` or `zip_broadcast.`). How should the prefix mechanism work?

A) Abstract getter (`String get keyPrefix`) that each subclass overrides — simple and explicit
B) Constructor parameter (`BaseSettingsNotifier({required String keyPrefix})`) — set at instantiation
C) Derived from the Riverpod provider name automatically — no explicit prefix needed
D) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 7
When `BaseSettingsNotifier.build()` loads persisted settings from SharedPreferences and encounters corrupt or missing data for a field, what should the recovery strategy be?

A) Fall back to `AppSettings.defaults()` for the entire object — if any field is corrupt, reset all
B) Fall back per-field — use the default for any field that fails to load; preserve successfully loaded fields
C) Fall back per-field with a logged warning (debug-level only, no transcript content) — so developers can detect storage issues
D) Other (please describe after [Answer]: tag below)

[Answer]: C)

### Question 8
The `AppTheme` needs a seed color for Material 3 `ColorScheme.fromSeed()`. The PoC uses blue. What seed color should Phase 0 use?

A) Blue (matches PoC; neutral, accessible)
B) Teal/cyan (aligns with accessibility/captioning branding)
C) Defer to a `ThemeConfig` parameter so each app can pass its own seed color (zip_captions vs zip_broadcast may want different branding)
D) Other (please describe after [Answer]: tag below)

[Answer]: D) Adapt only the applicable sections of the following design document, and incorporate those inclusions as part of the application spec for future agent work. Where there are conflicts, disregard the following and prioritize my answers to questions. For example, disregard the font restrictions contained below.

```
# Design System Specification: The Monolith Editorial

## 1. Overview & Creative North Star
**Creative North Star: The Monolith Editorial**

This design system moves away from the generic "SaaS-blue" aesthetic toward a visual language rooted in **Architectural Whisper**. It is a celebration of stark clarity, structural integrity, and high-contrast precision. By prioritizing a "Monolith" approach, we treat the UI as a series of carved, intentional slabs of information rather than a cluttered web page.

To achieve an award-winning editorial feel, we break the traditional grid through **intentional asymmetry** and **typographic dominance**. While we adhere to a flat design philosophy (no gradients), we create "soul" through the sophisticated interaction of solid color blocks, generous negative space, and a rigorous commitment to WCAG AAA legibility. This system doesn't just display data; it curates it.

---

## 2. Colors & Tonal Architecture
The palette is a deep, obsidian-inspired spectrum designed for maximum legibility and reduced eye strain.

### Surface Hierarchy & Nesting
Instead of relying on borders to separate content, we utilize a **Tonal Layering** approach. Hierarchy is defined by the "physical" depth of the surface.
- **The Foundation:** Use `surface` (`#0B141D`) for the primary canvas.
- **The Inset:** Use `surface_container_lowest` (`#060F18`) to "carve out" areas like sidebars or background utilities.
- **The Plinth:** Use `surface_container_high` (`#222B34`) or `surface_container_highest` (`#2D3640`) for cards and interactive modules to make them "rise" toward the user.

### The "No-Line" Rule (Architectural Separation)
Standard 1px borders are strictly prohibited for general sectioning. Boundaries must be defined by:
1. **Background Shifts:** Placing a `surface_container_low` module against a `surface` background.
2. **The Ghost Border:** If a boundary is functionally required for high-contrast accessibility in dense layouts, use the `outline_variant` (`#41474F`) at a **20% opacity maximum**. It should be felt, not seen.

### High-Contrast Brand Integration
The brand blue (`#427EB5`) is used with surgical precision. It is reserved for **active states** and **focus indicators** where it provides a clear, unmistakable signal against the dark surfaces. For primary actions, we prefer the high-contrast `primary` token (`#9ACBFF`) to ensure AAA compliance against the dark background.

---

## 3. Typography: The Editorial Voice
We use **Inter** as our sole typeface, relying on extreme scale and weight shifts to convey meaning.

- **Display Scales:** Use `display-lg` and `display-md` to create "Editorial Moments." These should be used for high-level data or section headers to break the monotony of the grid.
- **The Robust Secondary Rule:** To maintain WCAG AAA compliance, all secondary information (labels, helper text) must use `body-md` or `label-md` with a minimum weight of **Medium (500)** or **Semi-Bold (600)**. Never use "Light" weights for small text on dark backgrounds.
- **Tracking:** For `label-sm` and `label-md`, increase letter-spacing by `0.05em` to ensure legibility on high-resolution displays.

---

## 4. Elevation & Depth: Tonal Stacking
In a flat design system, "depth" is a psychological construct created through value shifts.

- **Layering Principle:** Stacks should move from Dark (bottom) to Light (top).
- *Example:* `surface` (Bottom) → `surface_container_low` (Middle) → `surface_container_highest` (Top/Active).
- **Ambient Shadows:** Standard drop shadows are banned. If an element must "float" (e.g., a Modal), use a highly diffused, ambient shadow: `Color: #000000`, `Opacity: 40%`, `Blur: 40px`, `Y-Offset: 20px`. The shadow must feel like a natural occlusion of light, not a digital effect.
- **The "High-Contrast" Edge:** For floating elements, a solid `outline` (`#8B919A`) may be used only if the background of the element and the surface below it have a contrast ratio of less than 3:1.

---

## 5. Components

### Buttons
- **Primary:** Solid `primary` (`#9ACBFF`) with `on_primary` (`#003355`) text. Bold (700) weight. Sharp `md` (0.375rem) corners.
- **Secondary:** Solid `secondary_container` (`#414A54`) with `on_secondary_container` (`#B0B9C6`) text.
- **Tertiary:** Ghost style. No background. `primary` text with an underline on hover only.

### Cards & Lists
- **No Dividers:** Prohibit the use of line dividers between list items. Use `2rem` (spacing-8) of vertical white space or alternating subtle background shifts (`surface` to `surface_container_low`).
- **Nesting:** A card should always be at least one "tier" higher than the surface it sits on (e.g., a `surface_container_high` card on a `surface` background).

### Input Fields
- **States:**
- **Default:** `surface_container_highest` background with a 1px `outline_variant` at 40% opacity.
- **Focus:** 2px solid `primary` (`#9ACBFF`) border.
- **Error:** 2px solid `error` (`#FFB4AB`) border.
- **Text:** All input text must be `on_surface` (`#DAE3F0`) to ensure 7:1 contrast ratios.

### Tooltips & Overlays
- **Visuals:** Use `inverse_surface` (`#DAE3F0`) for the background and `inverse_on_surface` (`#28313B`) for text. This "inverted" look immediately signals a temporary, floating utility state.

---

## 6. Do’s and Don'ts

### Do
- **Do** use `headline-lg` for data points that deserve emphasis, creating an editorial hierarchy.
- **Do** ensure all text targets a contrast ratio of 7:1 (WCAG AAA) where possible, and never below 4.5:1.
- **Do** use the `spacing-12` and `spacing-16` tokens to create "Breathing Zones" between major architectural blocks.

### Don’t
- **Don’t** use gradients or blurs. Every color must be a solid, intentional choice.
- **Don’t** use the `brand blue` (#427EB5) for large blocks of text; it is an accent, not a primary reading color.
- **Don’t** use `1px` lines to separate content; use the `surface` tokens to create "steps" in the layout.
- **Don’t** use font weights below 500 for any text smaller than 14px. Dark mode "eats" thin fonts; stay robust.
```

light theme:
```
# Design System

This document outlines the core aesthetic and functional principles of our design system, reflecting the current theme settings.

## 1. Color Palette

Our color palette is designed to be vibrant yet accessible, ensuring a consistent brand experience across all touchpoints.

*   **Color Mode**: light
*   **Primary Color**: `#427EB5` - Used for primary actions, main branding, and key interactive elements.
*   **Secondary Color**: `#DAE3F0` - Supports the primary color for less prominent UI elements, chips, and secondary actions.
*   **Tertiary Color**: `#FFFFFF` - An additional accent color for highlights, badges, or decorative elements.
*   **Neutral Color**: `#0B141D` - Provides a versatile base for backgrounds, surfaces, and non-chromatic UI elements.

## 2. Typography

We use a carefully selected set of fonts to establish a clear hierarchy and enhance readability.

*   **Headlines**: `inter` - Bold and impactful for titles and headings.
*   **Body Text**: `inter` - Clear and legible for all long-form content.
*   **Labels**: `inter` - Concise and functional for interactive elements and form labels.

## 3. Shape and Form

The geometry of our UI elements contributes to the overall feel and user perception.

*   **Roundedness**: `1` (Subtle roundedness) - Provides a balanced, approachable look to our components, offering a gentle softness without losing structure.

## 4. Spacing

Consistent spacing is crucial for readability, organization, and a harmonious visual flow.

*   **Spacing**: `2` (Normal) - Our standard spacing provides a comfortable layout, offering good separation between elements while maintaining a cohesive design.
```