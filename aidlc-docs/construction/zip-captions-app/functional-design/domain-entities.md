# Domain Entities — Unit 5: Zip Captions App

**Unit**: Unit 5: Zip Captions App (S-09)
**Stage**: Functional Design
**Status**: COMPLETE
**Feeds into**: NFR Requirements

---

## Overview

Unit 5 introduces no new model classes. All domain entities were established in Units 1–3
and are consumed unchanged by the screen layer. This document records which entities each
screen or component depends on, and introduces the one new piece of provider state added
in this unit.

---

## 1. Entities Consumed by Unit 5

### From Unit 1 / Unit 2 (zip_core)

| Entity | Where used |
|--------|-----------|
| `RecordingState` (sealed) | HomeScreen, RecordingScreen — drives button visibility and auto-navigation |
| `DisplaySettings` | RecordingScreen, SettingsScreen, CaptionDisplayWidget — font, size, scroll direction |
| `CaptionDisplayEntry` | CaptionDisplayWidget — the live caption buffer entries |
| `CaptionTextSize` (enum) | CaptionDisplayWidget, AppearancePanel |
| `CaptionFont` (enum) | CaptionDisplayWidget, AppearancePanel |
| `ScrollDirection` (enum) | CaptionDisplayWidget |
| `ThemeModeSetting` (enum) | SettingsScreen |

### From Unit 3 (zip_core)

| Entity | Where used |
|--------|-----------|
| `TranscriptSession` | HistoryScreen (session tiles), TranscriptViewerScreen (title) |
| `TranscriptSegment` | TranscriptViewerScreen (segment list) |
| `TranscriptSearchResult` | `transcriptSessionListProvider` internal — mapped to `TranscriptSession` |
| `TranscriptSettings` | SettingsScreen — capture-enabled toggle |
| `ExportFormat` (enum) | ExportFormatSheet — TXT / SRT / VTT options |

### From Unit 1 (zip_core — providers)

| Provider | Entity type | Where used |
|----------|------------|-----------|
| `recordingStateNotifierProvider` | `RecordingState` | HomeScreen, RecordingScreen |
| `onScreenCaptionTargetProvider` | `List<CaptionDisplayEntry>` | RecordingScreen → CaptionDisplayWidget |
| `displaySettingsNotifierProvider` (ZC instance) | `DisplaySettings` | RecordingScreen, SettingsScreen, CaptionDisplayWidget |
| `transcriptSettingsNotifierProvider` | `TranscriptSettings` | SettingsScreen |
| `transcriptRepositoryProvider` | `TranscriptRepository` | New providers (§2) |
| `activeEngineIdProvider` | `String?` | SettingsScreen |
| `localeInfoProvider` | `List<SpeechLocale>` | SettingsScreen |
| `wakeLockSettingsProvider` | `WakeLockSettings` | SettingsScreen |
| `audioDeviceServiceProvider` | `AudioDeviceService` | SettingsScreen |

---

## 2. New Provider State — Unit 5

### `transcriptSearchQueryProvider`

**Package**: `zip_captions` (not zip_core — depends on no cross-package consumers)

```dart
final transcriptSearchQueryProvider = StateProvider<String>((ref) => '');
```

| Property | Value |
|----------|-------|
| Type | `StateProvider<String>` |
| Default | `''` (empty = no active search) |
| Scope | HistoryScreen only |
| Persistence | None — resets on app restart |

This is the only new state type introduced by Unit 5. It is a raw `String` representing
the text the user has typed into the HistoryScreen search bar. It drives the
`transcriptSessionListProvider` family (see Business Logic Model §6).

---

## 3. Evolution from ID Spec

The ID spec defined `transcriptSessionListProvider` as a no-argument provider
returning `Future<List<TranscriptSession>>`. This unit's FD evolves it into a
**family provider** that accepts a `String query` argument:

```dart
@riverpod
Future<List<TranscriptSession>> transcriptSessionList(Ref ref, String query)
```

**Rationale**: The HistoryScreen needs to display either all sessions (empty query) or
search results (non-empty query). Passing `query` as a family argument lets the
HistoryScreen watch a single provider regardless of search state, and lets Riverpod
cache and invalidate results per query string. The HistoryScreen passes
`ref.watch(transcriptSearchQueryProvider)` as the argument.

This is the only divergence from the ID spec's provider signatures.
