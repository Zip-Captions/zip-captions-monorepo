# Application Design Plan — Phase 1: Core Captioning

## Plan Overview

Phase 1 introduces significant new architecture on top of the Phase 0 scaffold: STT engine implementations, a caption bus (pub-sub), four output target types, transcript storage with FTS5 search, multi-input audio management, OBS WebSocket integration, a browser source HTTP server, and a caption overlay system. This plan identifies all new components, their interfaces, service orchestration, and dependencies.

## Design Steps

- [ ] Step 1: Identify all new Phase 1 components and their package locations
- [ ] Step 2: Define modifications to existing Phase 0 components
- [ ] Step 3: Design the CaptionBus pub-sub architecture and CaptionOutputTarget interface
- [ ] Step 4: Design the TranscriptProvider and SQLite storage layer
- [ ] Step 5: Design the multi-input audio source management system (Zip Broadcast)
- [ ] Step 6: Design the OBS WebSocket client component
- [ ] Step 7: Design the browser source HTTP server component
- [ ] Step 8: Design the caption overlay system (desktop always-on-top window)
- [ ] Step 9: Design app-level settings extensions (transcript capture toggle, OBS config, multi-input config)

## Mandatory Artifacts

- [ ] Generate `components.md` with component definitions and high-level responsibilities
- [ ] Generate `component-methods.md` with method signatures
- [ ] Generate `services.md` with service definitions and orchestration patterns
- [ ] Generate `component-dependency.md` with dependency relationships and communication patterns
- [ ] Update `application-design.md` as consolidated summary
- [ ] Validate design completeness and consistency

---

## Questions

### Question 1 — CaptionBus Implementation Pattern

The CaptionBus is a pub-sub stream where the STT engine publishes `SttResult` events and output targets subscribe independently (ADR-008). How should this be modeled in the Riverpod architecture?

A) **Riverpod StreamProvider**: CaptionBus is a `@riverpod` provider that exposes a `Stream<SttResult>`. Output targets are separate providers that watch the stream. Session state changes are a separate stream or merged into the same stream via a union type.
B) **Standalone service class**: CaptionBus is a plain Dart class (not a Riverpod provider itself) that manages subscriptions internally. A Riverpod provider holds the CaptionBus instance. Output targets register/unregister directly with the CaptionBus instance.
C) **Broadcast StreamController**: CaptionBus wraps a `StreamController.broadcast()` exposed through a Riverpod provider. Output targets subscribe to the broadcast stream. This is the simplest Dart-native approach.

[Answer]: B

### Question 2 — CaptionOutputTarget Lifecycle

Output targets (on-screen renderer, transcript writer, OBS WebSocket, browser source) subscribe to the CaptionBus. How should their lifecycle be managed?

A) **Provider-managed**: Each output target is its own Riverpod provider. When the provider is disposed (e.g., user disables OBS output), the subscription is automatically cleaned up.
B) **Registry-managed**: A CaptionOutputTargetRegistry holds all active targets. Targets are added/removed explicitly. The registry manages subscription lifecycle.
C) **Self-managed**: Each target subscribes to the bus on creation and cancels on dispose. No central registry — targets are independent.

[Answer]: B

### Question 3 — SQLite Package Selection

Transcript storage requires SQLite with FTS5 support. Which package approach?

A) **sqflite + raw SQL**: Use `sqflite` (or `sqflite_common_ffi` for desktop) with hand-written SQL for schema, queries, and FTS5 virtual tables. Minimal abstraction, direct control.
B) **drift (formerly moor)**: Type-safe ORM with code generation, built-in migration support, and FTS5 integration via `drift`'s full-text search API. More abstraction, compile-time safety.
C) **sqlite3 + sqlite3_flutter_libs**: Use the low-level `sqlite3` Dart package directly with `sqlite3_flutter_libs` for platform binaries. Maximum control, no ORM overhead, but more boilerplate.

[Answer]: B

### Question 4 — Browser Source HTTP Server

The browser source serves a caption overlay page via local HTTP. Which approach?

A) **shelf package**: Use the `shelf` HTTP server package (Dart team maintained). Structured middleware, routing, easy to test. Widely used in the Dart ecosystem.
B) **dart:io HttpServer directly**: Use `dart:io`'s built-in `HttpServer`. No additional dependency, but more boilerplate for routing and static file serving.
C) **Other** (please specify)

[Answer]: A

### Question 5 — Caption Overlay Window Management

The caption overlay for Zip Broadcast is a transparent, always-on-top, click-through window that renders on a target display. This requires platform-specific desktop window management. Which approach?

A) **Multi-window Flutter package** (e.g., `desktop_multi_window`): Use an existing package that supports creating secondary Flutter windows with per-window configuration (always-on-top, transparency, click-through).
B) **Platform channels**: Implement native window creation via platform channels (Swift/Kotlin/C++) for each desktop platform. Full control, but significant per-platform implementation effort.
C) **Spike-dependent**: Defer the specific approach to Spike 1.2 or a dedicated investigation during construction Unit 3 (Output Targets). Define only the interface now.

[Answer]: C

### Question 6 — Multi-Input Audio Source Model

Zip Broadcast supports multiple simultaneous audio inputs, each with its own speaker label, visual style, and STT engine instance. How should this be modeled?

A) **List-based provider**: A single Riverpod provider manages a `List<AudioInputConfig>` where each config has source ID, speaker label, visual style, and a reference to its STT engine instance. Adding/removing inputs mutates the list.
B) **Family provider**: Use Riverpod's `.family` modifier to create per-input providers keyed by input ID. Each input's STT engine, label, and style are managed by its own provider instance.
C) **Dedicated manager class**: An `AudioInputManager` class (held by a Riverpod provider) that encapsulates the collection of active inputs, each with its own STT engine lifecycle.

[Answer]: A

### Question 7 — Output Target Package Location

Where should `CaptionOutputTarget` implementations live?

A) **All in zip_core**: All output target implementations (on-screen renderer, transcript writer, OBS WebSocket, browser source) live in zip_core. Apps just configure which targets are active.
B) **Interface in zip_core, implementations split**: The `CaptionOutputTarget` interface and shared implementations (on-screen renderer, transcript writer) live in zip_core. App-specific implementations (OBS WebSocket, browser source, caption overlay) live in zip_broadcast.
C) **Interface only in zip_core**: Only the abstract interface lives in zip_core. All concrete implementations live in the app package that uses them (on-screen renderer in both apps, OBS/browser source/overlay in zip_broadcast, transcript writer in both apps).

[Answer]: B

### Question 8 — OBS WebSocket Package

OBS WebSocket integration requires a WebSocket client that speaks the OBS WebSocket protocol (v5). Which approach?

A) **obs_websocket pub.dev package**: Use an existing OBS WebSocket client package from pub.dev if one exists with adequate quality and v5 protocol support.
B) **web_socket_channel + custom protocol**: Use the standard `web_socket_channel` package and implement the OBS WebSocket v5 protocol (authentication, message framing) directly.
C) **Spike-dependent**: Evaluate available packages during Spike 1.3 or early construction and decide then. Define only the interface now.

[Answer]: B

### Question 9 — Settings Architecture Extension

Phase 1 adds new settings fields (transcript capture toggle, wake lock behavior, OBS connection, output target toggles, multi-input configs). How should these extend the Phase 0 `BaseSettingsNotifier` / `AppSettings` pattern?

A) **Extend AppSettings**: Add all new shared fields (transcript capture, wake lock behavior) to `AppSettings` in zip_core. Add app-specific fields (OBS connection, multi-input config) as additional fields in the app-level settings notifiers (`ZipCaptionsSettingsNotifier`, `ZipBroadcastSettingsNotifier`).
B) **Separate providers per concern**: Keep `AppSettings` for display settings only. Create separate providers for transcript settings (`TranscriptSettingsProvider`), OBS settings (`ObsSettingsProvider`), and audio input settings (`AudioInputSettingsProvider`).
C) **Flat extension**: Add all new fields to `AppSettings` regardless of which app uses them. Unused fields in a given app are simply ignored.

[Answer]: B - app settings nomenclature should be refactored to be more accurate, rather than a generic "app settings" namespace. Pick something that describes the category of settings included within.

---

## Instructions

Please fill in each `[Answer]:` tag with your choice (A, B, C, etc.) and any additional context. You can edit this file directly or respond with your answers in chat.
