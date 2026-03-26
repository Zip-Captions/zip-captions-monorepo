# Zip Captions v2 — Architecture Decision Records

> **Document Status:** Draft v0.5
> **Last Updated:** 2026-03-25
> **Purpose:** Records the key architectural decisions for Zip Captions v2, including context, alternatives considered, and consequences. These decisions constrain and guide all implementation work.

---

## ADR-001: Two-App Strategy with Shared Core

### Status
**Accepted**

### Context
Zip Captions serves two distinct primary personas with meaningfully different needs:
- **Personal users** are mobile-first, need single-tap simplicity, minimal UI, and offline-only operation.
- **Broadcasters** are desktop-first, need OBS integration, line-in audio, multi-output targets, configuration profiles, and potentially premium features that may need to live outside app store distribution.

Additionally, the app store contingency strategy (see Personas document, Premium Feature Payment Model) may require premium features to ship in a separate application to avoid conflicts with platform gatekeeper policies.

### Decision
Build **two applications** sharing a **common Flutter package** (a monorepo with shared libraries). The app split is **persona-based, not platform-based** — Zip Captions serves personal users across all platforms; Zip Broadcast serves broadcasters on desktop.

- **Zip Captions** — the personal/consumer app (Alex and Sam personas). Runs on **mobile and desktop**: iOS, Android, macOS, Windows, Linux, and web. Mobile-first UX but fully functional on desktop. Contains all free accessibility features. Distributed through app stores with no payment references that could cause listing issues.
- **Zip Broadcast** — the broadcaster/professional app (Jordan persona). **Desktop-only**: macOS, Windows, Linux, and web. Contains broadcaster-specific features (OBS integration, multi-output, configuration profiles) and premium functionality. Distributed outside app stores (direct download, alternative stores, PWA) with its own payment integration. No mobile build — mobile social media streaming integration is a future concept.

### Platform Target Matrix

| Platform | Zip Captions | Zip Broadcast | Rationale |
|----------|-------------|---------------|-----------|
| iOS | Primary | — | Alex's primary device |
| Android | Primary | — | Alex's primary device |
| macOS | Secondary | Primary | Jordan's desktop; Alex on laptop |
| Windows | Secondary | Primary | Jordan's desktop; Alex on laptop |
| Linux | Secondary | Primary | Jordan's kiosk/server deployments; inclusive desktop support |
| Web (PWA) | Fallback | Fallback | Fallback distribution channel; no app install required |

**Primary** = first-class support, optimized UX, full feature set for that persona.
**Secondary** = fully functional but UX optimized for the primary platform first; features available but may have platform-specific limitations.
**Fallback** = functional baseline for users who cannot or choose not to install a native app; may have reduced capabilities (e.g., no BLE, limited audio capture).

Both apps depend on a shared `zip_core` Flutter package that contains:
- STT engine abstraction and implementations
- Audio capture pipeline
- Caption rendering engine
- Text processing and segmentation
- Local storage and encryption
- Settings and configuration models
- Localization
- BLE discovery protocol

### Alternatives Considered

**One app with mode switching.** Simpler to maintain initially, but creates app store risk (premium payment references in the same binary as the free app), bloats the mobile app with desktop-specific code (OBS integration, multi-output), and makes the UX confusing for Alex (personal user) who never needs broadcaster features.

**One app now, split later.** Tempting but historically leads to entanglement that makes the split painful. Starting with a clean separation is easier than untangling later, especially with agent-generated code that may not maintain clean boundaries without explicit package separation.

### Consequences
- Monorepo structure with at minimum three packages: `zip_core`, `zip_captions`, `zip_broadcast`
- Shared package must have its own test suite and be independently versioned
- Features must be clearly categorized as "core" (shared), "personal" (Zip Captions only), or "broadcast" (Zip Broadcast only) before implementation
- CI/CD pipeline must build and test all three packages
- The two apps can have independent release cadences

---

## ADR-002: Flutter for All Platforms

### Status
**Accepted**

### Context
Zip Captions v2 must run natively on iOS, Android, macOS, Windows, Linux, and web. The v1 was an Angular PWA with platform limitations (Web Speech API instability, no true offline, limited native integration). A Flutter proof-of-concept already exists with basic speech recognition working.

### Decision
Use **Flutter** as the single cross-platform framework for all targets: iOS, Android, macOS, Windows, Linux, and web.

### Rationale
- Single codebase across all platforms, with platform-specific code isolated via platform channels and conditional imports
- Native performance for audio capture and STT integration
- Strong accessibility widget support (Semantics, screen reader compatibility)
- Active ecosystem for speech recognition (`speech_to_text`), BLE (`flutter_blue_plus`), and audio (`just_audio`, `record`)
- Dart's sound null safety and strong typing improve agent-generated code quality
- The existing PoC provides a head start

### Alternatives Considered

**React Native + Expo.** Viable but the audio/STT/BLE plugin ecosystem is less mature, and bridging to native STT APIs would require more custom native code. Desktop support (via react-native-windows/macos) is less mature than Flutter's.

**Kotlin Multiplatform (KMP).** Strong for shared business logic but requires SwiftUI for iOS UI and Compose for Android UI — two UI codebases instead of one. Desktop support is nascent.

**Separate native apps per platform.** Maximum platform integration but 3-4x the development effort and impossible to maintain with a small team and agent-based development.

### Consequences
- Platform-specific code (native STT APIs, audio capture, BLE) requires platform channels or FFI
- Web platform has limitations for audio capture and BLE that may require feature degradation or alternative approaches
- Flutter desktop (especially Linux) is less mature than mobile — expect some platform-specific bugs
- Agent instructions must specify Flutter/Dart conventions, widget patterns, and testing approaches

---

## ADR-003: Riverpod for State Management

### Status
**Accepted**

### Context
The v1 Angular app used NgRx (Redux pattern) with actions, reducers, effects, and selectors. The Flutter PoC uses Provider. The v2 needs a state management approach that:
- Scales to complex state (multiple STT engines, audio streams, broadcast connections, settings)
- Produces compile-time-safe code (critical for agent-generated code)
- Is well-documented with clear patterns agents can follow
- Supports async operations (STT initialization, network calls, BLE discovery)
- Is testable without widget trees

### Decision
Use **Riverpod** (specifically `riverpod` with code generation via `riverpod_generator`) for all state management.

### Rationale
- **Compile-time safety:** Provider dependencies are resolved at compile time. If an agent writes a provider that references a non-existent dependency, the code won't compile. This is the single most important property for agent-generated code.
- **No BuildContext requirement:** Providers can be read and tested without a widget tree, making unit testing straightforward and agent-friendly.
- **AsyncNotifier pattern:** Maps conceptually to NgRx effects — async operations (STT init, network calls) are contained in notifier classes with explicit state transitions (`loading`, `data`, `error`).
- **Autodispose:** Providers that are no longer listened to are automatically cleaned up, preventing memory leaks from abandoned STT sessions or audio streams.
- **Same author as Provider:** The mental model from the existing PoC transfers directly. Migration is incremental.
- **Code generation:** `riverpod_generator` reduces boilerplate and enforces consistent patterns, which is ideal for agents.

### Alternatives Considered

**BLoC.** Well-established, maps to the NgRx mental model (events → state). However, BLoC requires significantly more boilerplate per feature (event class, state class, bloc class), which means agents generate more code with more opportunities for errors. BLoC's runtime dependency injection is also less safe than Riverpod's compile-time resolution.

**Provider (status quo from PoC).** Simpler but has known limitations: no compile-time safety for dependencies, `ChangeNotifier` doesn't enforce immutable state, and complex dependency trees become fragile. The PoC's Provider code can be incrementally migrated to Riverpod.

**Redux (flutter_redux).** Closest to NgRx but the Flutter Redux ecosystem is small and not well-maintained. The boilerplate-to-value ratio is poor compared to Riverpod.

### Consequences
- All state must be modeled as Riverpod providers (no raw `setState` or `ChangeNotifier` outside of widgets)
- Agent specifications must include Riverpod patterns and examples
- The existing PoC's Provider code needs migration (incremental, not big-bang)
- `riverpod_generator` and `build_runner` are build-time dependencies
- Team (and agents) need to understand the provider lifecycle (autoDispose, keepAlive, family)

---

## ADR-004: Supabase for Backend Services

### Status
**Accepted**

### Context
The v2 needs a minimal backend for:
- OAuth authentication (Google, Microsoft, Apple)
- Entitlement/license management (linking Patreon supporters to premium features)
- Encrypted transcript blob storage (zero-knowledge, server never sees plaintext)
- Settings sync across devices
- Remote caption relay (premium feature, future)
- Anonymized telemetry ingestion (future)

The v1 used NestJS + MongoDB with custom auth, caching, and session management. The v2 should minimize operational complexity and cost.

### Decision
Use **Supabase** as the backend platform, **self-hosted via Docker Compose on a VPS** for both development and production.

### Components Used
| Supabase Component | Use Case |
|---|---|
| **GoTrue (Auth)** | OAuth login (Google, Microsoft, Apple), JWT issuance |
| **PostgreSQL** | User profiles, entitlements, settings, encrypted transcript blobs, room/session metadata |
| **Storage** | Encrypted transcript file storage (larger transcripts as encrypted blobs) |
| **Edge Functions** | Patreon webhook handler, entitlement checks, Stripe integration (future) |
| **Realtime** | Remote caption streaming, remote status monitoring (premium features) |
| **Row Level Security (RLS)** | Users can only access their own data; enforced at the database level |

### Hosting Strategy
- **Development and production:** Self-host via official Docker Compose on a VPS (Hetzner, DigitalOcean, ~$20-40/month CAD). Full control over data, no tier limitations, predictable flat cost.
- **Scale-up path:** If usage grows beyond what a single VPS can handle, Supabase Cloud is available as an option. The client SDK doesn't change — only the endpoint URL. Self-hosted → Cloud migration is straightforward since both use the same Postgres schema and API surface.
- **Local development:** Docker Compose runs locally for development, matching the production environment exactly.

### Rationale
- **Open source:** All Supabase components are open source. No vendor lock-in — the entire stack is self-hosted from day one.
- **Postgres:** Relational, mature, well-understood. RLS provides defense-in-depth for multi-tenant data isolation.
- **Auth built-in:** GoTrue handles OAuth flows, JWT issuance, and session management out of the box. No custom auth code needed.
- **Realtime built-in:** WebSocket-based realtime subscriptions can power remote caption streaming without building a custom WebSocket server.
- **Edge Functions:** Deno-based serverless functions for webhook handlers and lightweight API endpoints. No separate API server needed for most use cases.
- **Predictable cost:** Self-hosted on a VPS means flat monthly cost regardless of usage. No surprise bills from tier overages.
- **Data sovereignty:** All data stays on infrastructure we control. Consistent with the zero-knowledge and privacy-first principles.
- **Flutter SDK:** Official `supabase_flutter` package with auth, database, storage, and realtime support.

### Alternatives Considered

**Firebase.** Generous free tier, excellent Flutter SDK, but proprietary (Google Cloud lock-in). Firestore's NoSQL model is awkward for relational data like entitlements and user-room associations. No self-hosting option.

**Custom NestJS API on Railway/Fly.io.** Maximum flexibility but maximum ops burden. Would require building auth, storage, realtime, and caching from scratch (or integrating multiple libraries). The v1 demonstrated this approach works but is expensive to maintain.

**PocketBase.** Lightweight, single-binary Go backend. Appealing simplicity but limited ecosystem, no edge functions, and the project's long-term maintenance is a concern for a production dependency.

### Consequences
- Backend development uses Supabase client SDK (Dart) and Edge Functions (TypeScript/Deno)
- Database schema must be designed with RLS policies from day one
- Encrypted transcript storage means the database stores opaque blobs — no server-side search or indexing of transcript content
- Remote caption relay (Supabase Realtime) has bandwidth/connection limits on the free tier that may require upgrading or self-hosting for production
- Agent specifications must include Supabase patterns (RLS, Edge Functions, Storage)

---

## ADR-005: Pluggable STT Engine Architecture

### Status
**Accepted**

### Context
Zip Captions must support multiple speech-to-text engines:
1. Platform-native (Apple Speech, Google on-device) — default, zero-config
2. On-device models (Whisper.cpp, Vosk, Hugging Face) — user-selectable, privacy-focused
3. Cloud APIs (free tier provider, Azure, Google Cloud) — user-selectable, accuracy-focused

The v1 had a hard switch between `web` and `azure` engines. The v2 needs a cleaner abstraction that supports N engines and allows adding new ones without modifying existing code.

### Decision
Define an **STT Engine interface** in `zip_core` that all engine implementations must satisfy. Engine selection is a runtime configuration choice stored in user settings (and per-profile for broadcasters).

```
abstract class SttEngine {
  String get engineId;
  String get displayName;
  bool get requiresNetwork;
  bool get requiresDownload;  // For on-device models that need initial download
  
  Future<bool> isAvailable();
  Future<void> initialize({String? localeId});
  Stream<SttResult> startListening({required String localeId});
  Future<void> stopListening();
  Future<void> pause();
  Future<void> resume();
  Future<List<SpeechLocale>> getAvailableLocales();
  Future<void> dispose();
}

class SttResult {
  final String text;
  final bool isFinal;
  final double? confidence;
  final Duration? timestamp;
  final String? speakerTag;  // Future: for diarization
}
```

### Engine Registration
Engines register themselves at app startup. Each app (Zip Captions, Zip Broadcast) can register different engine sets:

```
// In zip_core
class SttEngineRegistry {
  void register(SttEngine engine);
  List<SttEngine> getAvailable();
  SttEngine getById(String id);
}

// In zip_captions (mobile app)
registry.register(PlatformSttEngine());      // Apple/Google native
registry.register(WhisperSttEngine());       // On-device Whisper
registry.register(VoskSttEngine());          // On-device Vosk

// In zip_broadcast (desktop app)  
registry.register(PlatformSttEngine());
registry.register(WhisperSttEngine());
registry.register(VoskSttEngine());
registry.register(AzureSttEngine());         // Premium cloud
registry.register(GoogleCloudSttEngine());   // Premium cloud
```

### Rationale
- New engines can be added without modifying any existing code — just implement the interface and register
- Engine selection UI is generated from the registry — no hardcoded engine lists in the UI
- The `SttResult` stream provides a uniform output regardless of engine, which means the rendering pipeline doesn't know or care which engine is producing text
- `requiresNetwork` and `requiresDownload` flags allow the UI to show appropriate warnings and filter available engines based on current conditions
- `speakerTag` in `SttResult` is optional and future-proofed for diarization without requiring it now

### Consequences
- Each engine implementation lives in its own Dart package or file within `zip_core`
- Engine implementations may require platform channels (e.g., Apple Speech on iOS requires Swift, Whisper.cpp requires FFI to C++)
- Model download management is needed for engines like Whisper (download progress, storage management, model selection)
- The interface must be stable — changes to `SttEngine` affect all implementations
- Agent specifications must include the interface contract and example implementation

---

## ADR-006: Zero-Knowledge Transcript Encryption

### Status
**Accepted**

### Context
The Personas document establishes that transcript data belongs exclusively to the user and must be encrypted such that server-side access is technically impossible. The v1 used a client-side encryption key stored in localStorage with server-side key derivation via HMAC — a reasonable approach but with some weaknesses (the HMAC key derivation happens server-side, meaning the server briefly handles key material).

### Decision
Implement **client-side-only encryption** for all transcript data that leaves the device:

1. **Key generation:** On first use (or account creation), the client generates a 256-bit encryption key using a cryptographically secure random number generator.
2. **Key storage:** The key is stored exclusively in the device's secure storage (iOS Keychain, Android Keystore, desktop OS keychain). It is **never** transmitted to the server.
3. **Encryption:** Transcripts are encrypted client-side using AES-256-GCM before being sent to the server for sync/backup.
4. **Server storage:** The server stores only opaque encrypted blobs. No plaintext transcript data exists server-side.
5. **Multi-device sync:** When a user adds a new device, they must transfer the encryption key via a secure device-to-device channel. The server cannot facilitate this transfer because it never has the key. Transfer mechanisms (in order of preference):
   - **Direct P2P transfer:** Establish a WebRTC data channel between the two devices (using the same signaling infrastructure from ADR-011) and transfer the key over the encrypted P2P connection. Most seamless UX — user initiates transfer on device A, confirms on device B.
   - **QR code scan:** Device A displays the key as a QR code, device B scans it. Works without network connectivity. Requires physical proximity and line-of-sight.
   - **Hardware security key (YubiKey or similar):** The encryption key is stored on a FIDO2/PIV-capable hardware token (e.g., YubiKey 5 with NFC). The key is read from the token on any device via USB or NFC. This provides device-independent key storage that survives device loss. Premium feature due to niche hardware requirement.
   - **Manual key entry:** User exports the key as a base64 string and manually enters it on the new device. Last resort — error-prone but always works.
6. **Key loss:** If the user loses all devices, has no hardware security key, and has not backed up their key, their server-stored transcripts are permanently irrecoverable. This is a feature, not a bug — it's the cost of true zero-knowledge encryption.

### Local Transcript Storage
- Transcripts stored locally on-device are also encrypted, using the same key
- Decryption requires device authentication (PIN, biometrics) — the key is released from secure storage only after device auth
- Devices without authentication cannot save transcripts (enforced by the app, as specified in the Personas document)

### Rationale
- True zero-knowledge: the server is a dumb blob store. Even a complete database breach reveals nothing.
- No server-side key derivation or handling eliminates an entire class of key-management vulnerabilities
- Device secure storage (Keychain/Keystore) provides hardware-backed key protection on modern devices
- AES-256-GCM provides authenticated encryption (confidentiality + integrity + authenticity)

### Data in Transit: Zero-Retention Principle
Caption and transcript data that passes through any server-side infrastructure (Supabase Realtime relay, TURN servers, any future relay service) must **never be logged, stored, cached, or inspected**. The server is a dumb pipe — bytes in, bytes out, zero retention. This applies to:
- WebRTC relay traffic (TURN server)
- Supabase Realtime broadcast channels
- Any future caption relay infrastructure
- Server-side logs (must explicitly exclude message payloads)

This is not a policy — it is an architectural constraint. Server-side components must be configured and audited to ensure caption content cannot be captured, even by project maintainers with full infrastructure access.

### Alternatives Considered

**Server-derived keys (v1 approach).** The client sends a user-provided key to the server, which derives an encryption key via HMAC and returns it. This means the server handles key material, even if briefly. A compromised server could intercept keys.

**Password-based key derivation (PBKDF2/Argon2).** User provides a password, key is derived client-side. Usable but adds a password that users can forget, and password-derived keys are only as strong as the password.

**End-to-end encrypted sync service (e.g., built on Signal Protocol).** Overkill for transcript sync. The Signal Protocol is designed for multi-party messaging with forward secrecy — transcript sync is a simpler problem.

### Consequences
- Multi-device onboarding requires a key transfer step (adds friction but is essential)
- The app must implement at least two key transfer mechanisms: P2P transfer (primary) and QR code (offline fallback)
- YubiKey/hardware security key support is a premium feature requiring FIDO2/PIV integration (e.g., `yubico_flutter` or platform-specific FIDO2 APIs)
- Server-side search or indexing of transcripts is impossible (by design)
- Key backup/recovery UX must clearly communicate the permanence of key loss
- The `flutter_secure_storage` package (or equivalent) is a critical dependency
- Supabase Storage is used as a dumb encrypted blob store — no Supabase-side processing of transcript content

---

## ADR-007: BLE-Based Local Session Discovery

### Status
**Accepted**

### Context
Scenario S3.2 (Personas document) requires attendees to discover nearby broadcast sessions without internet connectivity. The broadcaster (conference AV setup) advertises available caption sessions; attendees' devices discover them and connect.

### Decision
Use **Bluetooth Low Energy (BLE) advertising** for session discovery. The broadcaster device advertises a BLE service containing session metadata. Attendee devices scan for this service and display available sessions.

### Protocol Design

**Broadcaster (advertiser):**
- Advertises a custom BLE service UUID registered to Zip Captions
- Service characteristics contain: session name (UTF-8, ≤20 bytes), session ID (UUID), transport hint (enum: BLE-GATT, local-WiFi, internet)
- Multiple sessions can be advertised by a single device (one characteristic per session)
- Advertising continues as long as the broadcast session is active

**Attendee (scanner):**
- Scans for the Zip Captions BLE service UUID
- Reads session metadata from discovered services
- Presents a list of available sessions sorted by signal strength (closest first)
- User taps a session to connect

**Caption data transport (after discovery):**
- BLE is used for **discovery only** — the limited bandwidth (~2KB/s for BLE GATT notifications) is sufficient for text but would be strained by high-throughput multi-language sessions
- Once a session is selected, the actual caption stream is delivered via the best available transport: (1) same local Wi-Fi network (WebSocket), (2) BLE GATT notifications (fallback if no shared network), (3) internet relay via Supabase Realtime (if both devices have connectivity)
- The transport is negotiated automatically based on what's available

### Rationale
- BLE is available on all target platforms (iOS, Android, macOS, Windows, Linux) with no internet dependency
- Limited range (~10-30m) is a feature: users only see sessions they're physically near
- BLE advertising payload is small but sufficient for session name + ID + transport hint
- Separating discovery (BLE) from transport (Wi-Fi/BLE GATT/internet) gives flexibility without coupling
- No pairing required — BLE advertising and scanning doesn't need device pairing

### Alternatives Considered

**mDNS/Bonjour.** Requires both devices to be on the same local network. Conference Wi-Fi is unreliable and may isolate clients. Not viable for the "no internet, no shared network" requirement.

**Wi-Fi Direct.** Requires explicit connection setup between devices. Clunky UX for a conference setting where dozens of attendees need to discover sessions simultaneously.

**QR code / join code (v1 approach).** Requires the broadcaster to display a code and the attendee to manually enter it. Works but is higher friction than automatic discovery, and doesn't solve the "no internet" requirement for the actual data transport.

**NFC.** Too short range for session discovery in an auditorium setting.

### Consequences
- `flutter_blue_plus` (or equivalent) is a dependency for both apps
- BLE permissions must be requested and handled per platform (iOS requires Info.plist entries, Android requires BLUETOOTH_SCAN/ADVERTISE permissions)
- BLE advertising while the app is backgrounded is limited on iOS (can advertise but with reduced frequency)
- Session name must fit within BLE advertising limits (~20 bytes for the name characteristic)
- A BLE protocol specification must be defined as a separate technical document for implementation
- Testing BLE discovery requires physical devices (simulators don't support BLE advertising)

---

## ADR-008: Caption Output Pipeline

### Status
**Accepted**

### Context
Captions produced by the STT engine need to be delivered to multiple output targets simultaneously:
- On-screen display (all personas)
- OBS WebSocket (broadcaster — closed captions)
- Browser source window (broadcaster — visual overlay)
- Remote viewers via Supabase Realtime (broadcaster)
- External display / projected output (broadcaster — auditorium mode)
- BLE GATT notifications (local attendees without Wi-Fi)
- Transcript recording (all personas)

The v1 had ad-hoc connections between the recognition service and each output (OBS, peer broadcast, UI). The v2 needs a clean pipeline.

### Decision
Implement a **publish-subscribe caption bus** in `zip_core`. The STT engine publishes `SttResult` objects to the bus. Output targets subscribe to the bus and consume results independently.

```
Caption Bus (in zip_core):
  STT Engine → publishes SttResult stream
    ├→ On-Screen Renderer (always subscribed)
    ├→ Transcript Recorder (subscribed when transcription enabled)
    ├→ OBS WebSocket Sender (subscribed when OBS connected)
    ├→ Browser Source Server (subscribed when browser source active)
    ├→ Realtime Broadcast (subscribed when broadcasting)
    ├→ BLE GATT Notifier (subscribed when advertising)
    └→ External Display Renderer (subscribed when second screen active)
```

### Rationale
- Adding a new output target requires zero changes to existing code — just subscribe to the bus
- Each output target handles its own formatting, buffering, and delivery independently
- Output targets can be independently enabled/disabled at runtime
- The bus can be extended with middleware (e.g., profanity filter, text formatting, trigger-word detection) that transforms results before they reach output targets
- Clean testability — each output target can be tested with a mock bus

### Consequences
- The bus is a Dart Stream (or Riverpod StreamProvider) in `zip_core`
- Output target implementations live in the respective app packages (OBS output in `zip_broadcast`, on-screen renderer in both apps)
- Middleware/transforms (premium features like trigger-word actions) plug into the bus as stream transformers
- Back-pressure handling is needed if an output target is slow (e.g., BLE notifications are rate-limited)

---

## ADR-009: Entitlement System (Patreon Interim → Stripe)

### Status
**Accepted**

### Context
Premium features need a way to verify that a user has paid for them. The project currently has Patreon integration. Long-term, a dedicated payment processor is needed for one-time purchases and subscriptions, handled outside app store channels.

### Decision
Implement a **server-side entitlement system** decoupled from the payment provider:

1. **Entitlements table** in Supabase Postgres stores what each user has access to (e.g., `custom_themes`, `config_profiles`, `remote_monitoring`)
2. **Payment providers** (Patreon now, Stripe later) are adapters that translate payment events into entitlement grants
3. **The client checks entitlements** via a Supabase query (cached locally) — it never checks payment status directly
4. **Patreon interim:** Patreon webhook events (pledge created, updated, deleted) trigger a Supabase Edge Function that maps Patreon tier to entitlements and updates the entitlements table
5. **Stripe future:** Same pattern — Stripe webhook → Edge Function → entitlements table
6. **Entitlement check in-app:** The app queries the user's entitlements on login and caches them locally. Premium feature gates check the local cache. Periodic re-validation ensures entitlements stay current.

### Rationale
- Decoupling entitlements from payment provider means switching from Patreon to Stripe (or adding both) requires only a new webhook adapter, not changes to the client
- Local caching of entitlements means premium features work offline (within a validity window)
- Server-side entitlement management prevents client-side tampering
- RLS policies ensure users can only read their own entitlements

### Consequences
- Entitlement schema must be designed to be payment-provider-agnostic
- Patreon webhook handler must be implemented as a Supabase Edge Function
- Client must handle entitlement expiry gracefully (e.g., subscription lapsed)
- Need a web-based account management portal where users can manage their subscription/purchases outside the app

---

## ADR-010: Monorepo Structure

### Status
**Accepted**

### Context
ADR-001 established two apps sharing a core package. The codebase needs a structure that supports this, enables agent-based development with clear boundaries, and allows independent builds and tests.

### Decision
Use a **Dart/Flutter monorepo** managed with **Melos** (monorepo management tool for Dart/Flutter):

```
zip-captions-monorepo/
├── packages/
│   ├── zip_core/                  # Shared library
│   │   ├── lib/
│   │   │   ├── stt/              # STT engine abstraction + implementations
│   │   │   ├── audio/            # Audio capture pipeline
│   │   │   ├── caption_bus/      # Pub-sub caption output bus
│   │   │   ├── storage/          # Local DB, encryption, secure storage
│   │   │   ├── models/           # Shared data models
│   │   │   ├── settings/         # Settings/configuration models
│   │   │   ├── l10n/             # Shared localizations
│   │   │   ├── ble/              # BLE discovery protocol
│   │   │   └── auth/             # Supabase auth wrapper
│   │   ├── test/
│   │   └── pubspec.yaml
│   │
│   ├── zip_captions/              # Personal user app
│   │   ├── lib/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   ├── providers/        # Riverpod providers (app-specific)
│   │   │   └── main.dart
│   │   ├── test/
│   │   ├── ios/
│   │   ├── android/
│   │   ├── web/
│   │   └── pubspec.yaml          # depends on zip_core
│   │
│   ├── zip_broadcast/             # Broadcaster app
│   │   ├── lib/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   ├── providers/
│   │   │   ├── obs/              # OBS WebSocket integration
│   │   │   ├── output/           # Multi-output management
│   │   │   └── main.dart
│   │   ├── test/
│   │   ├── macos/
│   │   ├── windows/
│   │   ├── linux/
│   │   ├── web/
│   │   └── pubspec.yaml          # depends on zip_core
│   │
│   └── zip_supabase/              # Supabase Edge Functions + migrations
│       ├── functions/
│       ├── migrations/
│       └── seed.sql
│
├── docs/                          # Specification documents (this file, personas, etc.)
│   ├── 01-user-personas.md
│   ├── 02-architecture-decisions.md
│   ├── 03-technical-specification.md
│   ├── 04-roadmap.md
│   └── 05-agent-development-guide.md
│
├── .github/                       # CI/CD workflows
├── melos.yaml                     # Monorepo configuration
└── README.md
```

### Rationale
- **Melos** provides monorepo tooling for Dart/Flutter: coordinated versioning, cross-package dependency management, and scripts that run across all packages
- Clear package boundaries enforce separation of concerns — agents working on `zip_captions` can't accidentally import `zip_broadcast` internals
- `zip_core` is an independently testable, publishable package (even if only used internally)
- Edge Functions and database migrations live in the same repo as the client code
- Specification documents live alongside the code they describe

### Consequences
- All developers (and agents) must understand the monorepo structure and which package to work in
- `melos bootstrap` replaces `flutter pub get` for initial setup
- CI must run tests for all packages on every PR
- Agent task specifications must include which package the work belongs to

---

## ADR-011: Caption Transport Layer (WebRTC + Fallbacks)

### Status
**Accepted**

### Context
The v1 uses Socket.IO for room management and signaling, with PeerJS (WebRTC wrapper) for peer-to-peer caption data delivery. This works well when WebRTC can establish a direct connection, but users have reported connectivity failures behind corporate firewalls and symmetric NATs. The v1 relies on Google's free STUN servers, which cannot traverse these network topologies — a TURN relay is needed but the v1 doesn't have one.

The v1 also used a "join code" displayed on screen for viewers to connect. This was friction-heavy and didn't work well in practice.

The v2 needs a transport layer that:
- Works peer-to-peer when possible (lowest latency, no server cost)
- Falls back gracefully when P2P fails (firewalls, symmetric NATs)
- Works without internet for local scenarios (conference, classroom)
- Never logs, stores, or inspects caption content in transit (see ADR-006, Zero-Retention Principle)
- Minimizes server-side cost with observable usage metrics

### Decision
Implement a **layered transport strategy**:

**1. WebRTC Data Channels (primary for remote streaming)**
- Used for all remote caption streaming between broadcaster and viewers
- Provides lowest latency when P2P connection succeeds
- Signaling (SDP offer/answer, ICE candidate exchange) is handled via **Supabase Realtime** channels, eliminating the need for a separate signaling server (replaces v1's Socket.IO + PeerJS server)
- ICE servers: **self-hosted Coturn** providing both STUN and TURN on the same VPS. No dependency on Google's STUN servers — all ICE infrastructure is self-hosted for privacy and independence.

**2. Supabase Realtime Relay (opt-in fallback for remote streaming)**
- **Not enabled by default.** The broadcaster explicitly enables "Allow server relay" in the broadcast configuration screen.
- When enabled, if WebRTC (including TURN) fails to establish a connection, the caption stream falls back to Supabase Realtime pub/sub channels.
- When enabling this option, the app warns the broadcaster: caption data will temporarily pass through a server in transit. Data is E2E encrypted and zero-retention, but the user makes an informed choice.
- This setting can be toggled mid-broadcast without interrupting the session. Enabling it makes relay available for new viewers; disabling it gracefully closes existing relay connections with a message to affected viewers.
- Also used (always, regardless of toggle) for non-caption features: signaling, remote status monitoring, session management, room metadata.

**3. Local Wi-Fi (primary for local streaming)**
- When broadcaster and attendee are on the same local network, captions are delivered via a local WebSocket server hosted by the broadcaster's device
- Discovered via the transport hint in BLE advertisement (see ADR-007)
- No internet required; lowest possible latency

**4. BLE GATT Notifications (fallback for local streaming)**
- When no shared network exists and no internet is available, caption text is delivered directly via BLE GATT characteristic notifications
- Limited bandwidth (~2KB/s) but sufficient for single-language text captions
- Highest latency of all transports, used only as last resort
- Maximum range ~10-30m (adequate for conference rooms)

### Transport Negotiation
After session discovery (via BLE or stable broadcast URL), the client automatically selects the best available transport:
1. Same local network detected? → Local Wi-Fi WebSocket
2. Internet available on both devices? → WebRTC (attempt P2P via STUN, fall back to TURN relay, fall back to Supabase Realtime if broadcaster has enabled it)
3. No internet, BLE connected? → BLE GATT notifications
4. No connectivity or all fallbacks exhausted? → Cannot connect (inform viewer with specific reason)

The transport selection is transparent to the viewer. The caption bus (ADR-008) emits the same `SttResult` stream regardless of transport — the rendering pipeline is transport-agnostic. The broadcaster sees the current transport type per viewer in the broadcast dashboard.

### Stable Broadcast URLs (replaces v1 join codes)
The v1's join code approach (display a code on screen, viewer types it in) was high-friction and didn't work well in practice. The v2 replaces it with **stable broadcast URLs**:

- Each authenticated broadcaster gets a **persistent broadcast ID** tied to their account. This is a short auto-generated string (e.g., `k7m9x2`).
- The broadcast URL is `zipcaptions.app/b/{broadcast_id}` — shareable via link, QR code, social media, stream description, etc.
- When a viewer navigates to the URL (or enters the ID in the app), it resolves to the broadcaster's current active session. If the broadcaster is not live, the viewer sees a "not currently broadcasting" message.
- The broadcast ID is permanent and reusable across sessions. The underlying session ID rotates per broadcast, but the public-facing URL stays the same.
- **Vanity URLs** (e.g., `zipcaptions.app/b/jordan` or `zipcaptions.app/b/techconf2026`) are a **premium feature** — user-chosen, memorable strings. Free users get the auto-generated stable ID.

This requires a Supabase table mapping `broadcast_id → current_session_id → signaling channel`. The broadcast_id is permanent; the session_id rotates per broadcast.

### Signaling Architecture (replaces v1 Socket.IO + PeerJS)
The v1's signaling server (Socket.IO for room management, PeerJS for WebRTC signaling) is replaced by **Supabase Realtime**:
- **Room management:** Supabase Realtime channels (one channel per broadcast session). Presence API tracks who is in each room.
- **WebRTC signaling:** SDP offers/answers and ICE candidates are exchanged via Supabase Realtime messages. Once the WebRTC connection is established, the Realtime channel is used only for signaling/control, not caption data.
- **Broadcast lifecycle:** Room creation, join, leave, and end-broadcast events are Realtime messages with associated Postgres state (session metadata, room status).

This eliminates the v1's separate signaling server entirely. Supabase Realtime handles signaling (always) and caption relay (when opted in) in a single infrastructure component.

### STUN/TURN Server Strategy
- **Self-hosted from day one:** Coturn runs on the same VPS as Supabase, providing both STUN and TURN services. No dependency on Google's free STUN servers or any third-party ICE infrastructure. This is consistent with the project's privacy and independence principles.
- **Cost model:** STUN has negligible cost (small UDP packets for NAT discovery). TURN relay traffic costs bandwidth, but caption data is text-only (~100-500 bytes/second per viewer), so bandwidth costs are negligible compared to audio/video TURN usage. Even thousands of concurrent relayed viewers would consume modest bandwidth on a standard VPS.
- **Monitoring:** STUN/TURN usage (bytes relayed, concurrent connections, connection duration, relay ratio) must be instrumented and observable (see ADR-012). Alerting thresholds should be set to catch unexpected cost growth before it becomes a problem.
- **TURN is automatic** — unlike the Supabase Realtime relay, TURN is not user-opt-in. It's part of the standard WebRTC ICE negotiation and activates transparently when direct P2P fails. The cost risk is low for text-only data, but monitoring ensures visibility.

### Rationale
- WebRTC is proven for real-time P2P streaming and is what v1 already uses successfully (when NAT traversal works)
- Adding TURN solves the firewall/symmetric NAT failures users have reported
- Making Supabase Realtime relay opt-in gives the broadcaster control and informed consent about server-transited data, while keeping TURN automatic (since it's standard WebRTC behavior with low cost risk)
- Using Supabase Realtime for signaling eliminates a separate server (reduces ops burden and cost)
- Stable broadcast URLs are lower friction than join codes and support the "reusable broadcast" use case users have requested
- The layered approach means local scenarios work offline while remote scenarios degrade gracefully
- All transports carry the same `SttResult` payload, keeping the transport layer decoupled from the caption pipeline

### Alternatives Considered

**Keep Socket.IO + PeerJS (v1 approach).** Works but requires maintaining a separate signaling server. Since we're already using Supabase Realtime for other features, using it for signaling too consolidates infrastructure.

**Keep join codes (v1 approach).** Higher friction than stable URLs. Requires displaying a code and manual entry. Doesn't support reusable broadcasts. Replaced by stable broadcast URLs.

**WebRTC only (no Supabase Realtime fallback).** Risky — even with TURN, some enterprise networks block non-standard traffic. Supabase Realtime over WSS/443 traverses virtually any network. Making it opt-in balances reliability with the broadcaster's data-transit preferences.

**Supabase Realtime only (no WebRTC).** Simpler but adds unnecessary latency and server load for scenarios where P2P would work fine. Also creates a server dependency for local streaming scenarios that should work without internet.

**LiveKit / Janus / MediaSoup.** Full-featured WebRTC SFU/MCU servers. Overkill for text-only caption streaming. These are designed for audio/video conferencing with many participants. The complexity and cost are not justified.

### Consequences
- `flutter_webrtc` (or equivalent) is a dependency in `zip_core`
- Supabase Realtime channels need a naming convention and access control (RLS for channel subscriptions)
- TURN server adds a small infrastructure cost (self-hosted) or usage-based cost (managed); must be monitored (ADR-012)
- Transport negotiation logic lives in `zip_core` and must be well-tested across network conditions
- E2E encryption of caption payloads is required for Supabase Realtime relay (server must not see plaintext)
- The transport layer must expose connection status to the UI (P2P connected, TURN relayed, server relayed, BLE, disconnected)
- Broadcast configuration screen needs the "Allow server relay" toggle with appropriate warning text
- Stable broadcast URL resolution requires a Supabase table and Edge Function for lookup
- Vanity URL uniqueness checking and reservation logic needed for the premium feature

---

## ADR-012: Observability and Instrumentation

### Status
**Accepted**

### Context
The project operates on a minimal budget with cost-sensitive infrastructure (self-hosted VPS, TURN relay, Supabase usage). Without observability, unexpected usage growth could cause cost overruns before anyone notices. Additionally, understanding community size, feature adoption, and usage patterns is essential for prioritizing development and sustaining the project.

There are two distinct categories of observability with different privacy characteristics:
1. **Infrastructure metrics** — server-side monitoring of our own systems (not user-facing, not opt-in)
2. **Application telemetry** — client-side usage data that requires explicit user opt-in (as established in the Personas document)
3. **Community metrics** — aggregate counts for understanding project health and growth

### Decision

#### Infrastructure Metrics (Internal, Always-On)
Server-side monitoring of infrastructure we operate. This data never contains user content or personally identifiable information. It is collected by our own systems about our own systems.

**VPS / Host metrics:**
- CPU, memory, disk utilization
- Network bandwidth (ingress/egress) with breakdown by service
- Process health (Supabase containers, Coturn, any edge services)

**TURN relay metrics (critical for cost management):**
- Bytes relayed per time period (hourly, daily, monthly)
- Concurrent relayed connections (current, peak, average)
- Connection duration distribution
- Relay vs. P2P connection ratio (what percentage of WebRTC connections require TURN?)
- Alerting threshold: warn if monthly relayed bandwidth exceeds a configurable ceiling (e.g., 50% of VPS bandwidth allocation)

**Supabase usage metrics:**
- Database size and row counts for key tables
- Storage usage (encrypted transcript blobs)
- Realtime connection count (current, peak)
- Realtime message throughput (for relay-enabled broadcasts)
- Edge Function invocation count and duration
- Auth active sessions

**Alerting:**
- Cost-relevant metrics must have configurable alerting thresholds
- Alerts should fire before costs become a problem, not after
- Delivery via email, webhook, or a monitoring dashboard (Grafana, or Supabase's built-in dashboard for Cloud)

#### Community Metrics (Aggregate, Anonymous)
Understanding project health and community size. These are aggregate server-side counts derived from data we already have — not additional tracking.

**From server-side data (no opt-in needed — we already have this):**
- Total registered accounts (Supabase Auth count)
- Monthly/weekly/daily active authenticated users (auth session activity)
- Broadcasts created per day/week/month (session table count)
- Peak concurrent viewers per broadcast and aggregate (Realtime presence count)
- Broadcast duration distribution

**From app store public data (no instrumentation needed):**
- Download counts (App Store, Play Store, direct download stats)
- Ratings and review counts

**For unauthenticated users:** We accept that we cannot count users who never sign in and never join a broadcast. App store download stats serve as a rough proxy. We do not add tracking pings or anonymous device IDs for unauthenticated users — this conflicts with the privacy-first principle.

#### Application Telemetry (Opt-In, Anonymized)
Client-side usage data, collected only with explicit user consent. As established in the Personas document: anonymized, never tied to user identity, never includes transcript content.

**What is collected (when opted in):**
- Platform (iOS/Android/macOS/Windows/Linux/web)
- STT engine selection and switch frequency
- STT engine latency (time from audio to text result)
- Language/locale selection distribution
- Session duration and frequency
- Transport type used (P2P, TURN, Supabase relay, local Wi-Fi, BLE) and connection success rates
- Feature usage flags (which output targets active, which settings enabled)
- Error rates by category (STT failures, transport failures, BLE discovery failures)
- App version and OS version
- Crash reports (stack traces only — **never transcript content, never audio data**)

**How it is anonymized:**
- No user ID, device ID, or any persistent identifier is attached to telemetry events
- Events are fire-and-forget — no correlation between events from the same device across sessions
- Telemetry endpoint accepts anonymous POST requests with no authentication
- Data is stored in aggregate (counters, histograms, percentiles) — not as individual events — wherever possible

**What is NEVER collected, under any circumstances:**
- Transcript content (partial or complete)
- Audio data
- User identity or any identifier that could be correlated to a user
- Location data
- IP addresses (stripped at the ingestion point if present in the request)

### Rationale
- Infrastructure metrics are essential for cost management on a minimal budget — you can't manage what you can't measure
- TURN relay monitoring specifically addresses the cost risk identified in ADR-011
- Community metrics provide the project health indicators needed for sustainability decisions without adding any user-facing tracking
- Application telemetry, when opted in, provides the data needed to prioritize features and identify problems (e.g., if 80% of users are on a specific STT engine, focus quality efforts there)
- The strict separation between infrastructure metrics (internal), community metrics (aggregate), and application telemetry (opt-in) maintains consistency with privacy principles

### Consequences
- Infrastructure monitoring tooling must be provisioned alongside the VPS (Grafana + Prometheus, or lightweight alternatives like Uptime Kuma + custom scripts)
- Alerting configuration is part of the infrastructure setup, not an afterthought
- A telemetry ingestion endpoint (Supabase Edge Function or lightweight service) must be built for opt-in application telemetry
- The opt-in telemetry consent flow must be designed as part of the app's first-run experience, with clear language about what is and isn't collected
- Community metrics are derived from existing Supabase data — no additional infrastructure needed, just queries/dashboards
- Telemetry data retention policy must be defined (how long do we keep aggregate data?)

---

## ADR-013: Pluggable Translation Engine Architecture

### Status
**Accepted**

### Context
Zip Captions v2 needs real-time translation capabilities for three scenarios: bidirectional conversation translation (S1.5), bilingual broadcast display (S2.6), and viewer-side translation (S3.4). Translation must follow the same principles as STT: free on-device default, pluggable alternatives, cloud premium.

The translation landscape offers several on-device options: Google ML Kit (50+ languages, Android/iOS only), Apple Translation (iOS/macOS only), Chrome's Translator API (desktop Chrome only, web builds), and open-source models (NLLB, Helsinki-NLP — cross-platform but require bundling and FFI). No single solution covers all platforms.

### Decision
Define a **Translation Engine interface** in `zip_core` that mirrors the STT Engine interface (ADR-005). Translation engine selection is a runtime configuration choice. The interface abstracts over platform-native, bundled, and cloud translation backends.

```
abstract class TranslationEngine {
  String get engineId;
  String get displayName;
  bool get requiresNetwork;
  bool get requiresDownload;  // For language packs that need initial download

  Future<bool> isAvailable();
  Future<List<LanguagePair>> getSupportedPairs();
  Future<bool> isLanguagePairAvailable(String source, String target);
  Future<void> downloadLanguagePack(String source, String target);
  Future<TranslationResult> translate(String text, {
    required String sourceLanguage,
    required String targetLanguage,
  });
  Future<String> detectLanguage(String text);
  Future<void> dispose();
}

class TranslationResult {
  final String translatedText;
  final String sourceLanguage;   // Detected or specified
  final String targetLanguage;
  final double? confidence;
  final bool isOnDevice;         // Whether this was translated locally or via cloud
}
```

### Engine Implementations (by platform)

| Platform | Free Default | Alternative | Premium |
|----------|-------------|-------------|---------|
| iOS | Apple Translation | Google ML Kit | Google Cloud, DeepL |
| Android | Google ML Kit | — | Google Cloud, DeepL |
| macOS | Apple Translation | Bundled NLLB model | Google Cloud, DeepL |
| Windows | Bundled NLLB model | — | Google Cloud, DeepL |
| Linux | Bundled NLLB model | — | Google Cloud, DeepL |
| Web | Chrome Translator API (if available) | — | Google Cloud, DeepL |

### Desktop Gap Strategy
Windows and Linux lack platform-native translation APIs. The strategy is:
1. **Bundle an open-source model** (NLLB-200 distilled, ~600MB) for common language pairs. This runs via FFI (C++ inference runtime) and provides offline translation without platform dependencies.
2. **Quality tradeoff:** Bundled models are less accurate than platform-native or cloud APIs, especially for non-English pairs. The persistent translation disclaimer mitigates user expectations.
3. **Investigation required:** The exact model, quantization strategy, and inference runtime (ONNX Runtime, ExecuTorch, or similar) need evaluation during implementation. This is a spike/research task on the roadmap.

### Translation Disclaimer Requirement
All translated text must display: **"Source language: [detected language]. Translation may be inaccurate."** This disclaimer is persistent and cannot be dismissed while translation is active. It appears in all translation modes (conversation, broadcast bilingual, viewer-side).

### Integration with Caption Bus (ADR-008)
Translation plugs into the caption bus as a **stream transformer** — a middleware layer between the STT output and the rendering/output targets:

```
Caption Bus with Translation:
  STT Engine → SttResult stream
    → Translation Transformer (when enabled)
      → TranslatedCaptionResult (source text + translated text)
        ├→ On-Screen Renderer (shows both or translated only)
        ├→ Bilingual Display Renderer (shows both side-by-side)
        ├→ Transcript Recorder (records both source and translation)
        └→ All other output targets
```

For viewer-side translation (S3.4), the translation happens on the viewer's device after receiving caption data — the broadcaster's pipeline is not involved.

### Rationale
- Same pluggable pattern as STT engines means agents apply the same implementation approach
- Platform-native APIs are free and highest quality where available
- Bundled open-source models fill the desktop gap without cloud dependency
- Translation as a bus middleware means it composes with all existing output targets without modifying them
- The disclaimer requirement is non-negotiable — translation accuracy varies and users must be informed

### Consequences
- `zip_core` gains a `translation/` module with the engine interface and middleware
- Language pack management UI needed (download, delete, storage usage display)
- Bundled NLLB models add ~600MB to desktop app size (or downloaded on first use)
- FFI bridge needed for native inference on desktop (C++ ONNX Runtime or equivalent)
- Translation adds latency to the caption pipeline — must be measured and optimized
- Three language lists (UI, STT, translation) may not overlap — the app must handle gaps gracefully

---

## ADR-014: UI Localization and Translation Quality

### Status
**Accepted**

### Context
The v1 supports 11 UI languages: Arabic (ar), German (de), English (en), Spanish (es), French (fr), Indonesian (id), Italian (it), Polish (pl), Portuguese (pt), Ukrainian (uk), and Chinese (zh). These translations were generated via a Python script and kept in sync programmatically. Community contributions were solicited but limited (Ukrainian received some community input). The Chinese translation is reported to be poor quality. There is no mechanism for users to report translation issues or contribute improvements.

### Decision

#### Baseline Language Set
The v2 must support **at minimum** the same UI languages as v1, minus Chinese (which will be redone):

**Verified (English as source):** en
**Carried forward from v1 (unverified quality):** ar, de, es, fr, id, it, pl, pt, uk
**To be redone:** zh (Chinese — dropped from v1, new translation required before re-inclusion)

Additional languages may be added based on community demand and contributor availability.

#### Quality Tiers and Transparency
Each UI language translation is assigned a quality tier, displayed to users:

1. **Verified** — reviewed and approved by a native speaker. Only English starts at this tier.
2. **Community-reviewed** — translated and reviewed by at least one community contributor who is a native or fluent speaker.
3. **Machine-generated** — produced by automated translation (LLM, Google Translate, or similar) and not yet reviewed by a native speaker.

The app displays the quality tier for the current UI language in settings, along with a call-to-action:
- For machine-generated translations: "This translation has not been verified by a native speaker. Help us improve it!" with a link to contribute.
- For community-reviewed translations: "This translation was contributed by the community. Suggest a correction." with a link to report issues.

#### Community Contribution Workflow
- Users can report incorrect translations or suggest improvements via a lightweight in-app mechanism (link to a contribution form or GitHub issue template)
- Contributions are reviewed before inclusion (to prevent vandalism or low-quality submissions)
- Contributors are credited in the app's acknowledgments (with consent)
- The contribution mechanism must be low-friction — a user sees a bad translation, taps "suggest correction," provides the corrected text, and submits. No GitHub account required.

#### Localization File Management
- All UI strings are externalized in standard Flutter l10n format (ARB files)
- A script (successor to the v1 Python script) keeps translation files in sync when source strings change
- New strings are initially machine-translated and flagged as "machine-generated" until reviewed
- The sync script must not overwrite community-reviewed translations with machine-generated ones

#### Distinction: UI Localization vs. STT vs. Translation
Three separate language capabilities exist in the app, and they may not overlap:

1. **UI localization** — the app's buttons, labels, settings, and messages. Managed via ARB files. Limited to languages with maintained translations.
2. **STT recognition languages** — what the speech engine can listen for. Determined by the selected STT engine's capabilities (platform-native engines typically support 50+ languages).
3. **Translation target languages** — what the translation engine can translate into. Determined by the selected translation engine's capabilities.

A user may run the app in English (UI), recognize Polish speech (STT), and translate to French (translation). The three settings are independent.

### Rationale
- Transparency about translation quality builds trust and sets appropriate expectations
- The community contribution CTA turns a quality problem into a community engagement opportunity
- Quality tiers prevent the project from implicitly endorsing translations it hasn't verified
- Keeping the sync script prevents translation rot when source strings change
- The three-list distinction prevents user confusion when a language is available for one capability but not another

### Consequences
- Each ARB file needs metadata tracking its quality tier and last review date
- The community contribution mechanism must be built (in-app form + backend to receive submissions)
- A review process for community translations must be established (even if lightweight)
- The sync script from v1 needs to be adapted for Flutter ARB format
- Chinese (zh) is excluded from v2 launch until a quality translation is available
- Quality tier display adds a small amount of UI complexity to the language settings screen

---

## Decision Summary

| ADR | Decision | Key Consequence |
|-----|----------|-----------------|
| 001 | Two apps (Zip Captions + Zip Broadcast) sharing `zip_core` | Clean separation of personal vs. broadcast; platform target matrix defines primary/secondary/fallback per app |
| 002 | Flutter for all platforms | Single codebase; platform channels for native STT/audio/BLE |
| 003 | Riverpod for state management | Compile-time safety for agent-generated code; AsyncNotifier for side effects |
| 004 | Supabase for backend | Auth, Postgres, Storage, Realtime, Edge Functions; open source, self-hostable |
| 005 | Pluggable STT engine interface | New engines without modifying existing code; uniform SttResult stream |
| 006 | Zero-knowledge transcript encryption | Client-only key; server stores encrypted blobs; key loss = data loss; zero-retention for data in transit |
| 007 | BLE for local session discovery | No internet needed; limited range is a feature; transport layer is separate |
| 008 | Pub-sub caption output bus | New outputs without modifying existing code; middleware for transforms |
| 009 | Decoupled entitlement system | Patreon now, Stripe later; payment provider is an adapter, not the source of truth |
| 010 | Melos monorepo | Three packages (`zip_core`, `zip_captions`, `zip_broadcast`) + Supabase + docs |
| 011 | WebRTC + fallback transport layer | P2P primary, TURN automatic, Supabase Realtime opt-in fallback; stable broadcast URLs replace join codes; replaces v1 Socket.IO + PeerJS |
| 012 | Observability and instrumentation | Infrastructure metrics (always-on), community metrics (aggregate), application telemetry (opt-in anonymized); TURN cost monitoring |
| 013 | Pluggable translation engine architecture | Platform-native free default, bundled NLLB for desktop, cloud premium; translation as caption bus middleware; persistent accuracy disclaimer |
| 014 | UI localization and translation quality | v1 languages carried forward (minus Chinese); quality tiers (verified/community/machine); in-app correction CTA; community contribution workflow |

---

## Document Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-03-25 | 0.1 | Initial draft — 10 ADRs covering app strategy, platform, state management, backend, STT architecture, encryption, BLE discovery, caption pipeline, entitlements, and monorepo structure |
| 2026-03-25 | 0.2 | Added platform target matrix to ADR-001 (removed mobile from Zip Broadcast). Added zero-retention transit data principle to ADR-006. Added ADR-011: Caption Transport Layer (WebRTC + Supabase Realtime fallback, replaces v1 Socket.IO + PeerJS). |
| 2026-03-26 | 0.3 | Revised ADR-011: Supabase Realtime relay is now opt-in (broadcaster setting with warning), TURN remains automatic with cost monitoring. Replaced join codes with stable broadcast URLs (auto-generated free, vanity premium). Added ADR-012: Observability and Instrumentation (infrastructure metrics, community metrics, opt-in application telemetry). |
| 2026-03-26 | 0.4 | Added ADR-013: Pluggable Translation Engine Architecture (mirrors STT pattern, platform-native free, NLLB for desktop, cloud premium, translation disclaimer requirement). Added ADR-014: UI Localization and Translation Quality (v1 language baseline, quality tiers, community contribution CTA, three-list distinction). |
| 2026-03-26 | 0.5 | ADR-001: clarified persona-based app split (not platform-based) — Zip Captions serves personal users on mobile AND desktop. ADR-006: added P2P key transfer as primary mechanism, YubiKey/FIDO2 as premium option, updated consequences. ADR-011: self-hosted STUN via Coturn (dropped Google STUN dependency), renamed section to STUN/TURN Server Strategy. |
