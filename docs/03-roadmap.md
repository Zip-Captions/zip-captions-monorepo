# Zip Captions v2 — Roadmap

> **Document Status:** Draft v0.2
> **Last Updated:** 2026-03-26
> **Purpose:** Defines the phased development milestones for Zip Captions v2, including dependencies, deliverables, and sequencing. Each phase builds on the previous one. Both apps (Zip Captions and Zip Broadcast) are developed in parallel, with shared work concentrated in `zip_core`.
> **Repository:** `zip-captions-monorepo`

---

## Roadmap Principles

1. **Feature parity before new features.** v1 capabilities must be replicated before new functionality is added. Users migrating from v1 expect what they already have to work.
2. **Both apps in parallel.** Most early work lives in `zip_core`. App-specific work (UI shells, platform configuration) happens alongside core development so both apps are always runnable.
3. **Each phase is shippable.** Even if not publicly released, each phase produces a working artifact that can be tested end-to-end. No phase is purely theoretical.
4. **Dependencies are explicit.** A phase cannot start until its listed prerequisites are complete. This prevents agents from working on features whose foundations don't exist yet.
5. **Research spikes are separate.** Unknowns that could block a phase are called out as spikes that should be completed *before* the phase begins, not discovered mid-phase.

---

## Phase Overview

| Phase | Name | Release | Prerequisites |
|-------|------|---------|---------------|
| 0 | Foundation | — | None |
| 1 | Core Captioning | — | Phase 0 |
| 2 | Broadcasting & Transport | — | Phase 1 |
| 3 | Auth, Encryption & Sync | — | Phase 1 |
| 4 | Entitlements & Payment | — | Phase 3 |
| 5 | BLE Local Discovery | v2.0 | Phase 1 |
| 6 | Release & v1 Deprecation | v2.0 | Phases 1–5 |
| 7 | Observability & Polish | Ongoing | Phases 1–4 |
| 8 | Translation | v2.1 | Phase 1, Phase 2 |

Phases 2, 3, and 5 can run in parallel after Phase 1 is complete. Phase 4 depends on Phase 3 (auth must exist before entitlements). Phase 6 is the v2.0 release milestone — it requires Phases 1–5 (feature parity with v1). Phase 7 runs alongside later phases. Phase 8 (translation) is v2.1 — new functionality beyond v1 parity, scheduled after v2.0 ships.

### Release Targeting
- **v2.0 first platforms:** Zip Captions on Android and iOS (app store submissions)
- **v2.0 fast follow:** Zip Captions on Windows desktop (direct download)
- **v2.0 full rollout:** Zip Captions on macOS, Linux; Zip Broadcast on all desktop platforms; PWA fallbacks
- **v2.1:** Translation features (Phase 8)

---

## Phase 0 — Foundation

### Goal
Establish the monorepo structure, development tooling, CI/CD pipeline, and migrate the existing Flutter PoC into the new architecture. At the end of this phase, both apps compile and run on all target platforms with a hello-world level of functionality.

### Prerequisites
None — this is the starting point.

### Deliverables

**Monorepo scaffold (ADR-010):**
- `zip-captions-monorepo/` initialized with Pub Workspaces + Melos
- `packages/zip_core/` — empty shared library with pubspec, test scaffold, linting
- `packages/zip_captions/` — Flutter app shell targeting iOS, Android, macOS, Windows, Linux, web
- `packages/zip_broadcast/` — Flutter app shell targeting macOS, Windows, Linux, web
- `packages/zip_supabase/` — Supabase project scaffold (Docker Compose, initial migration, seed)
- `docs/` — specification documents (personas, ADRs, roadmap, tech spec, agent guide)
- `melos.yaml` configured with bootstrap, test, analyze, and format scripts

**Riverpod migration (ADR-003):**
- Replace PoC's Provider-based state management with Riverpod
- Set up `riverpod_generator` and `build_runner` in `zip_core`
- Migrate existing PoC providers (speech service, settings) to Riverpod equivalents
- Establish Riverpod patterns and conventions for agents to follow

**CI/CD pipeline:**
- GitHub Actions (or equivalent) workflow for: lint, analyze, test across all packages
- Per-package test isolation (Melos filtered test runs)
- Build verification for all target platforms (compile check, not full build artifacts yet)
- Branch protection rules for `main`

**Supabase local development (ADR-004):**
- Docker Compose configuration for local Supabase (Postgres, GoTrue, Storage, Realtime, Edge Functions)
- Initial database migration (empty schema, RLS enabled)
- Development environment documentation (how to start, seed, reset)

**Localization scaffold (ADR-014):**
- Flutter l10n setup with ARB files in `zip_core`
- English (en) as source language
- Import v1 translations for: ar, de, es, fr, id, it, pl, pt, uk (carried forward, flagged as machine-generated)
- Quality tier metadata per language file

**Agentic development framework:**
- Integrate `ai-dlc` (aidlc-workflows) as a git submodule
- Configure AGENTS.md, CLAUDE.md, GEMINI.md for the monorepo and per-package
- Configure `.clinerules/` and `.aidlc-rule-details/` for Roo Code / Cline support
- Establish agent autonomy boundaries and human gate points (inception phase approval, PR review)

**Task coordination:**
- Git worktrees as the unit-of-work isolation mechanism — one worktree per feature, one PR per worktree
- AI-DLC inception as the single source of feature requirements (derived from roadmap and user personas)
- `Using AI-DLC, determine the next feature to build` as the standard entry point for discovering work
- Document the workflow for multi-developer coordination: each developer or agent runs inception independently, parallel worktrees avoid conflicts

### Research Spikes (complete during or before Phase 0)
- **Spike 0.1:** Confirm Flutter desktop builds work on macOS, Windows, and Linux for both app shells. Identify and document any platform-specific setup requirements.
- **Spike 0.2:** Identify VPS provider and tier. Evaluate Hetzner, DigitalOcean, and alternatives for: Supabase Docker Compose + Coturn (STUN/TURN) + Grafana/Prometheus. Target $20-40 CAD/month. Confirm resource requirements (CPU, RAM, disk, bandwidth).
- **Spike 0.3:** Research current state of on-device realtime STT. Survey platform-native APIs (Apple Speech, Google on-device), open-source models (Whisper.cpp, Vosk, Sherpa-ONNX), and evaluate accuracy, latency, language support, and offline capability per platform. Produce a comparison matrix.

### Exit Criteria
- `melos bootstrap` succeeds
- `melos run test` passes for all packages
- Both apps launch on at least one platform each (e.g., Zip Captions on iOS simulator, Zip Broadcast on macOS)
- Supabase local stack starts and accepts connections
- Riverpod is the sole state management solution — no remaining Provider code

---

## Phase 1 — Core Captioning

### Goal
Deliver the core captioning experience: speech goes in, text comes out, on all target platforms. This is the foundation that every subsequent feature builds on. At the end of this phase, a user can open either app, tap start, and see live captions from their microphone.

### Prerequisites
Phase 0 complete.

### Deliverables

**STT engine interface and platform-native implementation (ADR-005):**
- `SttEngine` abstract class and `SttResult` model in `zip_core`
- `SttEngineRegistry` for runtime engine registration
- `PlatformSttEngine` implementation:
  - iOS/macOS: Apple Speech Recognition (via platform channel)
  - Android: Google on-device speech (via `speech_to_text` package or platform channel)
  - Web: Web Speech API (fallback, best-effort)
  - Windows/Linux: investigate availability; may require Whisper.cpp as default on these platforms
- Engine selection UI (list available engines, switch between them)
- Language/locale selection within the selected engine

**Caption bus (ADR-008):**
- Pub-sub stream in `zip_core`
- STT engine publishes `SttResult` to the bus
- On-screen renderer subscribes and displays captions
- Transcript recorder subscribes and accumulates text

**Caption rendering UI:**
- Live caption display with configurable text size, font, contrast
- Text flow direction (top-to-bottom / bottom-to-top)
- Visual break on speaker change (best-effort, based on STT engine pauses)
- Screen wake lock during active captioning
- Pause/resume without losing context

**Transcript management:**
- Save transcript to local storage (TXT, SRT, VTT formats)
- Export/share transcript via platform share sheet
- Session history (list of past transcripts with date, duration, word count)
- Local storage only (no sync, no encryption yet — that's Phase 3)

**Audio capture:**
- Microphone input capture for all platforms
- External microphone support (USB, Bluetooth audio devices)
- Audio level indicator in UI
- Platform permission handling (microphone permission requests per platform)

**Zip Captions app UI (Alex's scenarios):**
- Single-tap start captioning from home screen
- Settings screen (STT engine, language, text appearance, flow direction)
- Recording screen with live captions and controls
- Session history / transcript viewer

**Zip Broadcast app UI (Jordan's scenarios — captioning only, no broadcasting yet):**
- Start captioning from home screen
- Settings screen (same core settings as Zip Captions, plus broadcast-specific placeholders)
- Recording screen with live captions
- Line-in / system audio source selection (where platform supports it)

### Research Spikes (complete during or before Phase 1)
- **Spike 1.1:** Windows and Linux STT availability. Test platform-native speech recognition APIs. If unavailable or unreliable, Whisper.cpp becomes the default on these platforms — scope the FFI integration effort.
- **Spike 1.2:** System audio capture feasibility per platform. macOS requires specific entitlements and possibly a virtual audio device. Windows has WASAPI loopback. Linux has PulseAudio/PipeWire monitor sources. Document what works and what doesn't.
- **Spike 1.3:** Whisper.cpp Flutter FFI integration. Build a minimal proof-of-concept that loads a Whisper model and transcribes audio via FFI on at least one desktop platform. Determine model size, memory usage, and latency characteristics.

### Exit Criteria
- User can open Zip Captions on a mobile device (iOS or Android), tap start, speak, and see live captions
- User can open Zip Captions on a desktop (macOS, Windows, or Linux), tap start, speak, and see live captions
- User can open Zip Broadcast on a desktop (macOS, Windows, or Linux), tap start, speak, and see live captions
- Captions appear with < 1 second perceived latency using platform-native STT
- User can save and export a transcript in TXT format
- Text size, font, contrast, and flow direction are configurable
- At least two STT engine options are available on at least one platform (e.g., platform-native + Whisper on macOS)

---

## Phase 2 — Broadcasting & Transport

### Goal
Restore v1's broadcast functionality: a broadcaster can start a session, viewers can connect and receive live captions. The v1's Socket.IO + PeerJS architecture is replaced with Supabase Realtime signaling + WebRTC. Stable broadcast URLs replace join codes.

### Prerequisites
Phase 1 complete (caption bus must exist for broadcast output targets to subscribe to).

### Deliverables

**WebRTC transport (ADR-011):**
- WebRTC data channel implementation in `zip_core` using `flutter_webrtc`
- Signaling via Supabase Realtime channels (SDP offer/answer, ICE candidate exchange)
- STUN/TURN configuration (self-hosted Coturn on VPS — see ADR-011)
- TURN integration (Coturn on VPS) for NAT traversal fallback
- Connection status reporting to UI (P2P, TURN relayed, disconnected)

**Supabase Realtime relay (ADR-011):**
- Opt-in Supabase Realtime caption relay as fallback transport
- Broadcaster toggle in broadcast configuration ("Allow server relay")
- Warning text when enabling relay
- Mid-broadcast toggle support (enable/disable without interruption)
- E2E encryption of caption payloads over Realtime channels

**Broadcast session management:**
- Create broadcast session (persisted in Supabase Postgres)
- Stable broadcast URLs: auto-generated persistent broadcast ID per authenticated user
- Broadcast URL resolution: `zipcaptions.app/b/{broadcast_id}` → current active session
- "Not currently broadcasting" state for inactive broadcasts
- Viewer join flow (navigate to URL or enter broadcast ID in app)
- Viewer count and connection status in broadcaster dashboard
- End broadcast (notify viewers, clean up session)
- Reconnection handling (viewer temporarily disconnects, rejoins seamlessly)

**Caption output targets (ADR-008 subscribers):**
- Realtime broadcast output (publishes to WebRTC/Realtime for viewers)
- OBS WebSocket output (send captions as closed captions to OBS)
- Browser source output (local HTTP server serving caption overlay page)
- External display / second screen output (where platform supports it)

**Zip Broadcast app — broadcast UI:**
- Create/configure broadcast screen (session name, relay toggle, output target selection)
- Live broadcast dashboard (viewer count, connection types, caption preview, audio level)
- OBS connection settings (host, port, password)
- Browser source URL display and copy

**Zip Captions app — viewer UI:**
- Join broadcast screen (enter broadcast ID or URL)
- Live caption viewer (same rendering as self-captioning, but receiving from broadcast)
- Connection status indicator

**Vanity broadcast URLs (premium):**
- Custom broadcast ID selection and reservation
- Uniqueness checking
- Entitlement gate (requires premium — Phase 4 dependency for enforcement, but URL reservation logic built here)

### Research Spikes (complete during or before Phase 2)
- **Spike 2.1:** Supabase Realtime channel limits and performance. How many concurrent connections can self-hosted Supabase Realtime handle? What's the message throughput? Test with simulated viewer load.
- **Spike 2.2:** OBS WebSocket protocol. Confirm the closed-caption API and test with current OBS versions. Document the protocol interaction.
- **Spike 2.3:** Coturn deployment on VPS alongside Supabase. Confirm resource usage and configuration. Test TURN relay with devices behind symmetric NATs.

### Exit Criteria
- Broadcaster starts a session on Zip Broadcast, viewer connects on Zip Captions via stable URL, viewer sees live captions
- WebRTC P2P connection works between two devices on the same network
- TURN relay works when P2P fails (tested with restricted NAT simulation)
- Supabase Realtime relay works when opted in and WebRTC fails entirely
- OBS receives closed captions from Zip Broadcast
- Browser source serves a caption overlay page
- Viewer reconnects automatically after temporary disconnection

---

## Phase 3 — Auth, Encryption & Sync

### Goal
Add user authentication, zero-knowledge transcript encryption, and cross-device sync. At the end of this phase, users can sign in, their transcripts are encrypted, and they can optionally sync settings and encrypted transcripts across devices.

### Prerequisites
Phase 1 complete (transcripts must exist to encrypt). Can run in parallel with Phase 2.

### Deliverables

**Authentication (ADR-004, Personas cross-persona requirements):**
- Supabase GoTrue integration via `supabase_flutter`
- OAuth login with arbitrary providers (Google, Microsoft, Apple at minimum; architecture must support adding providers without code changes)
- Cross-platform account merging: accounts linked to the same email address across different OAuth providers are automatically merged (e.g., user signs in with Google on Android, then signs in with Apple on iPhone — same account)
- Session management (JWT, refresh tokens)
- Sign-in is optional — all core features work without an account
- Account deletion flow (removes all server-side data)
- User profile (minimal: display name, email, preferences)

**Zero-knowledge encryption (ADR-006):**
- Encryption key generation (256-bit, cryptographically secure RNG)
- Key storage in platform secure storage (iOS Keychain, Android Keystore, desktop OS keychain via `flutter_secure_storage`)
- AES-256-GCM encryption/decryption of transcript data
- Device security posture check: devices without authentication cannot save transcripts
- Local transcript storage encrypted at rest

**Multi-device key transfer (ADR-006):**
- P2P key transfer via WebRTC data channel (primary — most seamless UX)
- QR code key transfer as offline fallback (device A displays QR, device B scans)
- Key backup/recovery UX with clear warning about permanence of key loss
- Key transfer flow documentation for users

**Settings sync:**
- Sync user preferences (text size, font, flow direction, STT engine selection, language) via Supabase Postgres
- Sync is opt-in (toggle in settings)
- Conflict resolution: last-write-wins for settings

**Transcript sync (ADR-006):**
- Encrypted transcript upload to Supabase Storage
- Encrypted transcript download on other devices (requires key transfer first)
- Sync is opt-in and separate from settings sync
- Server stores only encrypted blobs — zero-knowledge enforced via RLS

**Device security enforcement:**
- Detect device authentication status (PIN, biometrics)
- Block transcript saving on devices without authentication
- Warning UI for insecure device configurations

### Research Spikes (complete during or before Phase 3)
- **Spike 3.1:** `flutter_secure_storage` cross-platform behavior. Test on all target platforms. Confirm hardware-backed storage on iOS/Android. Document desktop platform behavior (Linux keyring, Windows Credential Manager, macOS Keychain).
- **Spike 3.2:** P2P and QR code key transfer UX. Prototype both flows. For P2P: establish WebRTC data channel between two devices and transfer key material. For QR: device A displays QR, device B scans and imports. Evaluate security of both approaches.
- **Spike 3.3:** Supabase GoTrue cross-provider account merging. Confirm that GoTrue supports automatic account linking by email when a user signs in with different OAuth providers. Document any configuration required.
- **Spike 3.4:** YubiKey/FIDO2 key storage feasibility in Flutter. Investigate `yubico_flutter` or platform FIDO2/PIV APIs for storing the encryption key on a hardware security key. This is a premium feature — scope the effort and defer implementation if complex.

### Exit Criteria
- User can sign in with any supported OAuth provider on any platform
- User who signs in with Google on Android and Apple on iOS (same email) has a single merged account
- Transcripts are encrypted at rest on-device
- Encryption key can be transferred to a new device via P2P connection or QR code
- Encrypted transcripts sync to Supabase Storage and are retrievable on a second device (after key transfer)
- Settings sync across devices when opted in
- Device without PIN/biometrics cannot save transcripts
- Account deletion removes all server-side data
- A user who loses all devices and hasn't backed up their key cannot recover transcripts (by design)

---

## Phase 4 — Entitlements & Payment

### Goal
Implement the entitlement system and payment integration so premium features can be gated and monetized. Patreon is the interim payment provider; the system is designed for Stripe migration.

### Prerequisites
Phase 3 complete (authentication must exist — entitlements are tied to authenticated users).

### Deliverables

**Entitlement system (ADR-009):**
- Entitlements table in Supabase Postgres (user_id, entitlement_key, granted_at, expires_at, source)
- RLS policies: users can only read their own entitlements
- Client-side entitlement cache with periodic re-validation
- Entitlement check API in `zip_core` (used by feature gates in both apps)
- Offline entitlement validity window (cached entitlements work offline for N days)

**Patreon integration (ADR-009):**
- Patreon OAuth linking (user connects their Patreon account)
- Patreon webhook handler (Supabase Edge Function): pledge created → grant entitlements, pledge deleted → revoke entitlements
- Patreon tier → entitlement mapping configuration
- Manual entitlement override (for admin/support purposes)

**Premium feature gates:**
- Gate implementation in both apps for all premium features defined in Personas document
- Graceful UX for locked features (show what's available, explain how to unlock, link to Patreon/payment)
- No degradation of free features — premium gates must never affect accessibility features

**Web account portal:**
- Simple web page for managing subscription/payment, linking/unlinking Patreon, viewing active entitlements, and account deletion

### Exit Criteria
- A Patreon supporter at the correct tier has premium features unlocked in both apps
- A non-supporter sees premium features locked with clear upgrade path
- Removing a Patreon pledge revokes entitlements within a reasonable window
- Premium feature gates work offline (cached entitlements)
- Free features are completely unaffected by the entitlement system

---

## Phase 5 — BLE Local Discovery

### Goal
Implement Bluetooth Low Energy session discovery for local/offline scenarios (conference, classroom). A broadcaster advertises available sessions; nearby attendees discover and connect without internet.

### Prerequisites
Phase 1 complete (caption bus must exist). Phase 2 recommended (transport negotiation logic exists) but discovery can be developed against mock transports.

### Deliverables

**BLE advertising (ADR-007) — Zip Broadcast:**
- Custom BLE service UUID for Zip Captions
- Advertise session metadata: session name, session ID, transport hint
- Multi-session advertising (one device advertises multiple sessions)
- Background advertising support (where platform allows)
- Start/stop advertising tied to broadcast session lifecycle

**BLE scanning — Zip Captions:**
- Scan for Zip Captions BLE service UUID
- Read session metadata from discovered services
- Display available sessions sorted by signal strength
- Auto-refresh session list
- Handle sessions appearing and disappearing

**Local transport negotiation (ADR-011):**
- After BLE discovery, negotiate best transport: local Wi-Fi WebSocket → BLE GATT → internet (if available)
- Local Wi-Fi WebSocket server on broadcaster device
- BLE GATT caption delivery as last-resort fallback
- Transport type indicator in viewer UI

**BLE protocol specification:**
- Document the BLE service UUID, characteristic UUIDs, payload format, and protocol version
- Version the protocol for future extensibility

### Research Spikes (complete during or before Phase 5)
- **Spike 5.1:** `flutter_blue_plus` capabilities and limitations per platform. Test BLE advertising on iOS (background mode restrictions), Android, macOS, Windows, Linux. Document what works.
- **Spike 5.2:** BLE GATT caption delivery throughput. Test actual achievable throughput for text delivery via GATT notifications across device combinations. Confirm ~2KB/s estimate.
- **Spike 5.3:** Local Wi-Fi WebSocket server from Flutter. Test hosting a WebSocket server on a mobile/desktop Flutter app and connecting from another device on the same network.

### Exit Criteria
- Zip Broadcast advertises a BLE session on macOS/Windows/Linux
- Zip Captions discovers the session on iOS/Android without internet
- Viewer receives live captions via local Wi-Fi WebSocket
- Viewer receives live captions via BLE GATT when no shared network exists
- Session appears/disappears from the list as broadcaster starts/stops
- Works with both devices in airplane mode (BLE radio still active)

---

## Phase 6 — Release & v1 Deprecation

### Goal
Ship v2.0 to production and manage the transition from v1. This phase covers production infrastructure deployment, app store submissions, v1 migration guidance, and a planned deprecation timeline for v1.

### Prerequisites
Phases 1–5 complete (all v1 feature parity functionality working). Phase 7 (observability) should be sufficiently advanced to monitor production.

### Deliverables

**Production infrastructure:**
- VPS provisioned and configured (Supabase self-hosted + Coturn STUN/TURN + Grafana/Prometheus)
- Production database migrations applied
- SSL/TLS certificates configured
- Backup strategy for Supabase Postgres (automated, tested restore)
- Domain configuration (`zipcaptions.app` or equivalent) for broadcast URLs and web builds

**v2.0 first release — Zip Captions mobile:**
- Android: Google Play Store submission and listing
- iOS: App Store submission and listing
- App store metadata, screenshots, accessibility statement, privacy policy
- Both listings emphasize: free accessibility tool, no account required, offline-first

**v2.0 fast follow — Zip Captions desktop:**
- Windows: direct download (installer or portable), Microsoft Store if feasible
- macOS: direct download (DMG), Mac App Store if feasible
- Linux: AppImage, Flatpak, or Snap

**v2.0 full rollout — Zip Broadcast:**
- macOS, Windows, Linux: direct download
- PWA fallback for both apps

**v1 deprecation plan:**
- **Overlap period:** v1 and v2 run simultaneously for a defined period (suggest 3–6 months) after v2 reaches feature parity on the platforms v1 serves (web)
- **Migration guide:** Documentation for v1 users explaining what's changed, how to get v2, and how to migrate any saved data (if applicable)
- **In-app notice in v1:** Banner or notification in the v1 web app directing users to v2 with download links
- **v1 backend sunset:** After the overlap period, the v1 NestJS/MongoDB backend is shut down. The v1 web app can remain as a static page redirecting to v2.
- **Data migration:** If v1 stores any user data server-side (beyond the session cache), provide an export mechanism before shutdown. Given v1's architecture (client-side encryption, minimal server state), this may be minimal.

### Exit Criteria
- Zip Captions is live on Android Play Store and iOS App Store
- Zip Captions Windows desktop download is available
- Zip Broadcast is available for download on at least one desktop platform
- Production Supabase, Coturn, and monitoring are running and healthy
- v1 displays deprecation notice directing users to v2
- Migration guide is published
- v1 sunset date is announced

---

## Phase 7 — Observability & Polish

### Goal
Add infrastructure monitoring, application telemetry, localization quality improvements, and a project dashboard. This phase runs in parallel with later phases and continues ongoing.

### Prerequisites
Phases 1–4 complete (core functionality, broadcasting, auth, and entitlements must be stable). Phase 6 production infrastructure must exist for monitoring to target.

### Deliverables

**Infrastructure monitoring (ADR-012):**
- VPS monitoring (CPU, memory, disk, network)
- Supabase usage dashboards (database size, storage, Realtime connections, Edge Function invocations)
- Coturn STUN/TURN metrics (bytes relayed, concurrent connections, relay ratio)
- Alerting thresholds for cost-relevant metrics
- Grafana + Prometheus deployment on VPS

**Project dashboard — public-facing:**
- A privacy-respecting public Grafana dashboard (or similar) showing aggregate project health metrics
- Public metrics: total registered users, active broadcasts, community size indicators, uptime
- Explicitly excluded from public view: any per-user data, any content data, any granular session data
- This serves transparency and community trust — users can see the project is alive and growing without compromising anyone's privacy
- Dashboard URL linked from the app's about/info screen

**Project dashboard — maintainer-only:**
- Private Grafana dashboard with detailed infrastructure metrics, cost tracking, error rates
- TURN relay bandwidth tracking and cost projections
- Supabase resource usage trends
- Alerting to maintainer email/webhook

**Application telemetry (ADR-012):**
- Telemetry opt-in flow in app first-run experience
- Telemetry ingestion endpoint (Supabase Edge Function)
- Anonymous event collection (platform, STT engine, transport type, session duration, error rates)
- Aggregate dashboards for feature usage and error patterns

**Community metrics (ADR-012):**
- Dashboard for registered accounts, active users, broadcast counts, viewer counts
- Derived from existing Supabase data (no additional tracking)

**Localization quality (ADR-014):**
- In-app translation quality tier display (verified / community-reviewed / machine-generated)
- Community contribution CTA ("Help improve this translation")
- Contribution submission mechanism (lightweight form, no GitHub account required)
- Review workflow for community contributions
- Chinese (zh) translation: source new quality translation, verify before inclusion

**Documentation:**
- User-facing help documentation / FAQ
- Contributor guide (for community translations and open-source contributions)
- API documentation for browser source styling / customization

### Exit Criteria
- Infrastructure dashboards (public and private) are live
- Alerting is configured and tested
- Telemetry opt-in flow works and anonymized data is being collected (from test users)
- At least one non-English UI translation has been upgraded from "machine-generated" to "community-reviewed"
- Public dashboard is accessible and linked from the app
- Privacy policy accurately reflects the app's data practices

---

## Phase 8 — Translation (v2.1)

### Goal
Add real-time translation capabilities: conversation translation (S1.5), bilingual broadcast display (S2.6), and viewer-side translation (S3.4). This is new functionality beyond v1 feature parity.

### Prerequisites
Phase 1 complete (caption bus must exist for translation middleware). Phase 2 complete (for broadcast bilingual display S2.6).

### Deliverables

**Translation engine interface (ADR-013):**
- `TranslationEngine` abstract class and `TranslationResult` model in `zip_core`
- Language detection integration
- Platform-native implementations:
  - iOS/macOS: Apple Translation
  - Android: Google ML Kit Translation
- Desktop implementation: bundled NLLB model via FFI (or alternative based on Spike 6.1)
- Web implementation: Chrome Translator API (where available)
- Cloud translation implementation (Google Cloud Translation or DeepL) — premium

**Translation middleware (ADR-013, ADR-008):**
- Caption bus stream transformer that translates `SttResult` text
- `TranslatedCaptionResult` model (source text + translated text + source language + target language)
- Translation pipeline does not block caption delivery — source text renders immediately, translation appends when ready

**Conversation translation mode (S1.5):**
- Bidirectional language selection (language A ↔ language B)
- Automatic language detection per utterance
- Split-screen or alternating display showing both languages
- Persistent disclaimer: "Source language: [detected]. Translation may be inaccurate."

**Bilingual broadcast display (S2.6):**
- Dual-language caption rendering (source + translated) on broadcast outputs
- Configurable layout (side-by-side, stacked, alternating lines)
- Bilingual mode in browser source and external display outputs
- Persistent disclaimer on all outputs

**Viewer-side translation (S3.4):**
- Viewer selects preferred language in caption viewer
- Translation happens on viewer's device (no broadcaster involvement)
- Toggle between translated only, source only, or both
- Persistent disclaimer

**Language pack management:**
- Download/delete language packs for on-device translation
- Storage usage display
- Download progress indicators

### Research Spikes (complete during or before Phase 6)
- **Spike 6.1:** Desktop on-device translation feasibility. Test NLLB model via ONNX Runtime FFI on Windows, macOS, Linux. Measure model size, load time, translation latency, and memory usage. Determine if the quality/performance tradeoff is acceptable for common language pairs (en↔fr, en↔es, en↔de). If not feasible, the fallback is cloud-only translation on desktop.
- **Spike 6.2:** Google ML Kit Translation API in Flutter. Test on Android via platform channel or existing Flutter package. Measure latency for real-time translation of short phrases (caption-length text).
- **Spike 6.3:** Combined STT + translation latency budget. Measure end-to-end latency from speech to translated caption display. Determine if the combined pipeline stays under acceptable thresholds for live captioning.

### Exit Criteria
- User enables conversation mode, speaks English, sees Spanish translation (and vice versa) on a single device
- Broadcaster enables bilingual display, audience sees captions in two languages on projected screen
- Viewer joining a French broadcast can see English translations on their device
- On-device translation works offline for at least en↔fr and en↔es
- Translation disclaimer is visible and persistent in all translation modes
- Cloud translation works as a premium option with higher quality for more language pairs

---

## Dependency Graph

```
Phase 0 (Foundation)
  │
  ▼
Phase 1 (Core Captioning)
  │
  ├──────────────┬──────────────┐
  ▼              ▼              ▼
Phase 2        Phase 3        Phase 5
(Broadcasting) (Auth/Crypto)  (BLE Discovery)
  │              │
  │              ▼
  │            Phase 4
  │            (Entitlements)
  │              │
  ├──────────────┘
  ▼
Phase 6 (Release & v1 Deprecation) ← v2.0
  │
  ▼
Phase 8 (Translation) ← v2.1

Phase 7 (Observability & Polish) — runs alongside Phases 4–8
```

---

## Parked / Future Work

These items are captured in the specification documents but intentionally not scheduled. They will be added to the roadmap when the prerequisite phases are stable and the project's needs justify the investment.

**Remote captioning machine (S2.5):** E2E encrypted tunnel between two Zip Broadcast instances for off-site STT processing. Requires Phase 2 (transport) and Phase 3 (encryption). Complex networking and UX challenges.

**Community hardware sharing (Personas doc, future concept):** Volunteer compute donation for STT processing. Requires significant trust, scheduling, and privacy infrastructure. Requires Phase 3 (encryption) at minimum.

**Professional interpreter persona (Personas doc, parked):** Manual text input as a caption source, replacing the STT engine in the pipeline. Requires Phase 1 (caption bus) but inverts the input model.

**Mobile social media streaming integration:** Zip Broadcast on mobile for integration with social media streaming platforms. Requires investigation into platform APIs and feasibility.

**Stripe payment integration:** Replace Patreon with direct Stripe payment processing. Requires Phase 4 (entitlement system) as foundation. The entitlement system is payment-provider-agnostic by design (ADR-009), so this is an adapter swap.

**YubiKey / hardware security key support:** Store the encryption key on a FIDO2/PIV hardware token for device-independent key backup. Premium feature. Requires Phase 3 (encryption). Feasibility depends on Spike 3.4 results.

**Caption overlay (S3.5):** Transparent always-on-top caption window overlaying other applications. Desktop-primary feature (limited iOS support, Android via SYSTEM_ALERT_WINDOW). Premium. Requires Phase 1.

**Additional STT engines:** Vosk, Hugging Face models, Azure Speech, Google Cloud Speech. Each is an independent implementation of the `SttEngine` interface (ADR-005) and can be added at any time after Phase 1.

**Additional translation engines:** DeepL, additional open-source models, Chrome Translator API. Each is an independent implementation of the `TranslationEngine` interface (ADR-013) and can be added at any time after Phase 8.

---

## Document Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-03-26 | 0.1 | Initial draft — 8 phases (0–7) covering foundation through release prep. Feature parity before new features. Translation is Phase 6 (after v1 parity). Dependency graph and parked items defined. |
| 2026-03-26 | 0.2 | Major revision: Added Phase 6 (Release & v1 Deprecation) with overlap period and migration guide. Renumbered Translation to Phase 8 (v2.1). Expanded Phase 7 (Observability) with public Grafana dashboard and maintainer-only dashboard. Added ai-dlc git submodule and GitHub Projects to Phase 0. Added VPS provider research (Spike 0.2) and on-device STT survey (Spike 0.3) to Phase 0. Fixed Phase 1 exit criteria to reflect Zip Captions on mobile AND desktop. Fixed Phase 3: provider-agnostic OAuth, cross-platform account merging by email, P2P key transfer, YubiKey spike. Self-hosted STUN via Coturn (no Google dependency). Added release targeting (Android/iOS first, Windows fast follow). Added caption overlay and YubiKey to parked items. |
| 2026-03-26 | 0.3 | Fixed Phase 2 deliverable: STUN configuration now references self-hosted Coturn (was incorrectly referencing Google's free STUN servers, contradicting ADR-011). |
