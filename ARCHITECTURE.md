# Zip Captions v2: System Architecture

**Version:** 0.1.0
**Last Updated:** 2026-03-26
**Status:** Design Specification

---

## 1. Overview

Zip Captions is a free, open-source accessibility tool that provides real-time speech-to-text captioning. It runs natively on iOS, Android, macOS, Windows, Linux, and web. Transcription data belongs exclusively to the user — the system is built so that server-side access to transcript content is technically impossible.

Two applications share a common library in a monorepo:

- **Zip Captions** — personal/consumer app for deaf and hard-of-hearing users (mobile and desktop)
- **Zip Broadcast** — broadcaster/professional app for streamers, educators, and event organizers (desktop only)

### 1.1 Design Principles

- **Accessibility is always free.** Any feature that enables a person to understand spoken language through text never requires payment, an account, or network connectivity.
- **Transcript data belongs to the user.** Zero-knowledge encryption. The server stores only encrypted blobs. Not even project maintainers can access transcript content.
- **No Google dependency.** Self-hosted STUN/TURN via Coturn. No reliance on third-party ICE infrastructure.
- **Platform independence.** No app store dependency for premium features. Core accessibility must never be at risk due to platform gatekeeper disputes.
- **Feature parity before new features.** v1 capabilities must be replicated before new functionality is added.

### 1.2 Detailed Specifications

The architecture is defined across four specification documents. **Read the relevant sections before making changes to any component.**

| Document | Covers | Read when... |
|----------|--------|-------------|
| `docs/01-user-personas.md` | Three user personas (Alex, Jordan, Sam), 16 scenarios, free/premium matrices, cross-persona requirements, STT/translation strategy, payment model | ...you need to understand WHY a feature exists, who it serves, what is free vs. premium |
| `docs/02-architecture-decisions.md` | 14 ADRs: two-app strategy, Flutter, Riverpod, Supabase, pluggable STT/translation engines, zero-knowledge encryption, BLE discovery, caption bus, entitlements, monorepo structure, WebRTC transport, observability, localization | ...you are making a technical decision or need to understand WHY the system is designed this way |
| `docs/03-roadmap.md` | 9 phases (0-8), dependencies, deliverables, research spikes, exit criteria, release targeting | ...you need to understand WHEN something is built and what comes before it |
| `docs/04-technical-specification.md` | Code style, Riverpod patterns, testing rules, platform channels, error handling, dependency management, git workflow, security constraints, Supabase conventions, agent rules, package responsibilities | ...you are WRITING CODE — this is your coding standards reference |

### 1.3 ADR Quick Reference

| ADR | Decision | Spec Section |
|-----|----------|-------------|
| 001 | Two apps (Zip Captions + Zip Broadcast) sharing `zip_core` | 02-architecture-decisions.md |
| 002 | Flutter for all platforms | 02-architecture-decisions.md |
| 003 | Riverpod for state management | 02-architecture-decisions.md |
| 004 | Self-hosted Supabase for backend | 02-architecture-decisions.md |
| 005 | Pluggable STT engine interface | 02-architecture-decisions.md |
| 006 | Zero-knowledge transcript encryption | 02-architecture-decisions.md |
| 007 | BLE for local session discovery | 02-architecture-decisions.md |
| 008 | Pub-sub caption output bus | 02-architecture-decisions.md |
| 009 | Decoupled entitlement system (Patreon now, Stripe later) | 02-architecture-decisions.md |
| 010 | Melos monorepo | 02-architecture-decisions.md |
| 011 | WebRTC + fallback transport, self-hosted Coturn STUN/TURN | 02-architecture-decisions.md |
| 012 | Observability and instrumentation | 02-architecture-decisions.md |
| 013 | Pluggable translation engine architecture | 02-architecture-decisions.md |
| 014 | UI localization and translation quality tiers | 02-architecture-decisions.md |

---

## 2. Component Architecture

### 2.1 Components

| Component | Package | Technology | Responsibility |
|---|---|---|---|
| Shared library | `packages/zip_core` | Dart | STT engine abstraction, audio capture, caption bus, encryption, storage, models, settings, BLE discovery, transport layer, auth wrapper, localization, entitlement checking |
| Personal app | `packages/zip_captions` | Flutter | Mobile and desktop UI for Alex and Sam personas. iOS, Android, macOS, Windows, Linux, web |
| Broadcast app | `packages/zip_broadcast` | Flutter | Desktop UI for Jordan persona. OBS integration, multi-output, bilingual display. macOS, Windows, Linux, web |
| Backend | `packages/zip_supabase` | Supabase (Postgres, GoTrue, Edge Functions, Realtime, Storage) | Auth, encrypted transcript storage, entitlements, broadcast session management, signaling, optional caption relay |

See `docs/04-technical-specification.md` Section 11 for detailed package responsibilities.

### 2.2 Platform Target Matrix

| Platform | Zip Captions | Zip Broadcast |
|----------|-------------|---------------|
| iOS | Primary | -- |
| Android | Primary | -- |
| macOS | Secondary | Primary |
| Windows | Secondary | Primary |
| Linux | Secondary | Primary |
| Web (PWA) | Fallback | Fallback |

See ADR-001 in `docs/02-architecture-decisions.md` for definitions of Primary/Secondary/Fallback.

### 2.3 Communication Paths

| Path | Protocol | Direction | Purpose |
|---|---|---|---|
| App --> Supabase Auth | HTTPS | Request/Response | OAuth login, JWT issuance |
| App --> Supabase Postgres | HTTPS (PostgREST) | Request/Response | Settings sync, entitlements, session metadata |
| App --> Supabase Storage | HTTPS | Request/Response | Encrypted transcript blob upload/download |
| App <--> Supabase Realtime | WSS | Bidirectional | WebRTC signaling, optional caption relay, presence |
| Broadcaster <--> Viewer | WebRTC Data Channel | Bidirectional | P2P caption streaming (primary remote transport) |
| Broadcaster <--> Viewer | WebRTC via Coturn TURN | Relayed | Caption streaming when P2P fails (automatic) |
| Broadcaster --> Viewer | Local Wi-Fi WebSocket | Unidirectional | Caption streaming on same LAN |
| Broadcaster --> Viewer | BLE GATT Notifications | Unidirectional | Caption streaming fallback (no network) |
| Broadcaster BLE Advertisement | BLE | Broadcast | Session discovery (scan, not connect) |
| App --> OBS | OBS WebSocket v5 | Unidirectional | Closed caption injection |
| Patreon --> Supabase Edge Function | HTTPS Webhook | Unidirectional | Payment events to entitlement grants |

### 2.4 Data Flow — Core Captioning

1. User taps "Start" in either app
2. Audio capture pipeline begins recording from selected input (microphone, line-in, system audio)
3. Audio is passed to the selected STT engine (platform-native by default)
4. STT engine emits `SttResult` objects (partial and final) to the caption bus
5. Caption bus distributes results to all subscribed output targets:
   - On-screen renderer (always)
   - Transcript recorder (when enabled)
   - Broadcast outputs (when broadcasting): WebRTC, Realtime relay, local WebSocket, BLE GATT
   - OBS WebSocket (when connected)
   - Browser source server (when active)
6. User taps "Stop" — audio capture stops, STT engine stops, final transcript is available for save/export

### 2.5 Data Flow — Broadcast Viewing

1. Viewer discovers session via BLE scan or enters stable broadcast URL
2. Transport negotiation selects best available path (see ADR-011)
3. Viewer receives `SttResult` stream over the negotiated transport
4. Caption bus on viewer's device distributes to local output targets (renderer, recorder)
5. If viewer enables translation, translation middleware transforms results before rendering

---

## 3. Security Architecture

See `docs/04-technical-specification.md` Section 8 for hard security rules.
See ADR-006 in `docs/02-architecture-decisions.md` for the zero-knowledge encryption design.

Key invariants:
- Encryption keys never leave the device (except via explicit user-initiated transfer)
- Server stores only encrypted blobs — no plaintext transcript data exists server-side
- Data in transit through any relay (TURN, Supabase Realtime) is never logged, stored, or inspected
- All Supabase tables use Row Level Security
- Devices without authentication (no PIN, no biometrics) cannot save transcripts

---

## 4. Repository Structure

```
zip-captions-monorepo/
  packages/
    zip_core/                  # Shared Dart library
      lib/src/                 # Implementation (never import from outside package)
      test/                    # Unit tests
      pubspec.yaml
      AGENTS.md                # Package-specific agent instructions
    zip_captions/              # Personal user app (Alex + Sam)
      lib/
      test/
      ios/ android/ macos/ windows/ linux/ web/
      pubspec.yaml
      AGENTS.md
    zip_broadcast/             # Broadcaster app (Jordan)
      lib/
      test/
      macos/ windows/ linux/ web/
      pubspec.yaml
      AGENTS.md
    zip_supabase/              # Backend: Edge Functions + migrations
      functions/
      migrations/
      seed.sql
      AGENTS.md
  docs/
    01-user-personas.md
    02-architecture-decisions.md
    03-roadmap.md
    04-technical-specification.md
    TDD.md
    TEST_SETUP.md
    STORY_TEMPLATE.md
  scripts/                     # Agent workflow scripts
  stories/                     # User stories by phase
  test-fixtures/               # Shared test data
  ai-dlc/                      # Agentic dev template (git submodule)
  .github/
    pull_request_template.md
    workflows/                 # CI/CD
  AGENTS.md                    # Root agent instructions
  ARCHITECTURE.md              # This file
  CONTRIBUTING.md              # Development workflow
  CLAUDE.md                    # Pointer to AGENTS.md
  GEMINI.md                    # Pointer to AGENTS.md
  melos.yaml                   # Monorepo configuration
  README.md
```

---

*This document is the authoritative index for system-level architecture. Detailed specifications are in the documents referenced in Section 1.2.*
