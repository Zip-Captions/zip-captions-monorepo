# Tech Stack Decisions — Zip Captions Viewer (Unit 7)

## Dependencies

**No new dependency** (Q6). Every new class builds on packages already declared:

| New artifact | Built from |
|---|---|
| `ViewerSessionNotifier`, `ViewerSessionState`, `ReconnectPolicy`, `_ViewerResources` | `flutter_riverpod`/`riverpod_annotation`, `freezed` (state), `logging`, `uuid` (if a session-scoped id is needed), `meta` |
| `viewerTransportFactoryProvider` | `riverpod_annotation`, existing `TransportSelector`/`ViewerTransport` |
| Additive `ConnectFailure` variants (`RateLimited`, `ResolutionFailed`, `NotFound`) | `meta` (`@immutable`), hand-written `==`/`hashCode` matching the shipped four |
| `JoinBroadcastScreen`, `BroadcastViewerScreen`, guide/back/dialog widgets | `flutter`/`material`, `go_router`, `flutter_riverpod`, `zip_core` (`CaptionDisplayWidget`, `displaySettingsProvider`, `ConnectFailure`) |
| Announcement seam (Q8) | `flutter`'s `SemanticsService`/`Semantics` — Flutter SDK, no package |
| `broadcastBaseUrl` (Q9) | none — `String.fromEnvironment` |

If any future item needs more than the above (e.g. a semantics/AX package, an
announcement plugin, a routing package), that is a new finding requiring FR-9.5's
human approval and a SECURITY-10 supply-chain justification — not assumed here.

**SDK-level wiring (not a pub dependency):** Q8 may add `flutter_localizations` (Flutter
SDK) and the `intl` transitive SDK package to `zip_captions` if the Code Generation
mechanism is `flutter gen-l10n`. That is an SDK package, not a registry dependency, and
is scoped to the viewer's copy only. The alternative mechanism — a plain ARB-backed
`ZcStrings` lookup class with no new SDK wiring — is equally acceptable at Code
Generation; the NFR requires the outcome (strings in the ARB, no literals in widgets),
not the mechanism.

## Test Tooling

No new test dependency.

- `zip_core`: `flutter_test`, `fake_async ^1.3.2`, `mocktail ^1.0.4`, and the in-tree
  `test/helpers/pbt.dart` shim already cover every suite this unit needs.
- `zip_captions`: `flutter_test` alone. The widget tests use a hand-written
  `FakeViewerSessionNotifier` subclass and `pumpAndSettle`; no `mocktail`, no
  `fake_async`, no golden framework (this project has none).
- New fakes (`FakeBroadcastResolver`, `FakeViewerTransport`, the `statusChannel`-shaped
  signaling adapter) are plain Dart classes added to the existing helper file.

## PBT Framework

**Decision (PBT-09):** the in-tree shim at `packages/zip_core/test/helpers/pbt.dart` is
the project's Dart PBT framework. No `glados` dependency exists and none is added.
`Glados<T>(generator).test(...)` runs 100 deterministic seeds (`0..99`) and supports
async bodies; it does not shrink, so counterexamples are reduced by hand and pinned as
example tests (PBT-10). The shim's earlier `// Lightweight PBT helper replacing glados`
comment should be updated at Code Generation to state that this is the selected
framework, not a stopgap.

## Migration

None. No `zip_supabase` migration, no RLS change, no SQL function. The viewer is an
anonymous consumer of existing policies.

## Component Placement

- `zip_core`:
  - `lib/src/services/broadcast/viewer_session_notifier.dart` (+ `.g.dart`) — beside
    `broadcast_session_notifier.dart`, the established location for session notifiers.
  - `lib/src/services/broadcast/viewer_session_state.dart` or
    `lib/src/models/viewer_session_state.dart` — follow where `broadcaster_session_state.dart`
    lives (`models/`), for consistency.
  - `lib/src/services/broadcast/viewer_session_resources.dart` (private holder;
    package-internal, not exported from the barrel — same treatment as
    `session_resources.dart`).
  - `lib/src/models/reconnect_policy.dart` (or `services/broadcast/`) — a pure policy
    object, no I/O.
  - `lib/src/models/connect_failure.dart` — **additive edit only**: three new `final
    class` variants; the four shipped ones are untouched (a boundary the run
    configuration names explicitly).
  - `lib/src/providers/viewer_transport_factory_provider.dart` — mirrors
    `broadcast_transport_factory_provider.dart`.
  - `lib/src/constants/broadcast_link_config.dart` (new) + `lib/src/models/broadcast_link.dart`
    (edit: interpolate the constant, remove `baseUrl`).
  - Barrel updates in `models.dart`/`services.dart`/`providers.dart` as needed.
- `zip_captions`:
  - `lib/src/screens/join_broadcast_screen.dart`, `lib/src/screens/broadcast_viewer_screen.dart`.
  - `lib/src/widgets/` — any extracted state widgets (e.g. the status/notice widgets),
    following the existing directory.
  - `lib/src/providers/viewer_announcer_provider.dart` (Q8 seam) — or wherever the
    project's provider convention places app-level callback providers.
  - `lib/src/routing/zc_router.dart` — `/join` inside the `ShellRoute`,
    `/b/:broadcastId` outside it; `ZcNavDrawer` + `HomeScreen` entry affordances.
  - `l10n/arb/app_en.arb` — every viewer string; plus whatever minimum wiring Q8's
    chosen mechanism requires.
- **Explicitly out of scope:** `packages/zip_captions/web/` (any scaffold),
  `build-verify.yml` (any web job), security-header configuration, `docs/`, and
  `packages/zip_broadcast/macos/Podfile.lock` (a pre-existing unrelated dirty file).

## Platform Neutrality

No `dart:io`, `dart:html`, platform channel, or native-only import in
`ViewerSessionNotifier`, its resources, the providers, the announcement seam, or the two
screens (FD Rule 12). The routes are plain go_router paths. A `grep` audit of the new
files is a Code Generation gate.