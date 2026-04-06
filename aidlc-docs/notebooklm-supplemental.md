# Zip Captions v2 — Supplemental Briefing for NotebookLM

This document provides structured reference material for generating a video explainer about Zip Captions v2, the AI-DLC development workflow, and what it means for potential contributors.

---

## Part A: Why v2 — What v1 Taught Us

### What v1 Got Right
- Proved the concept: real-time captions for deaf/HoH users work and people need them
- Built a community of users who depend on the tool
- Established design principles: accessibility is free, transcript data belongs to the user
- Shipped translations in 9 languages (Arabic, German, Spanish, French, Indonesian, Italian, Polish, Portuguese, Ukrainian)

### What Motivated the Rebuild

| Motivation | v1 Reality | v2 Approach |
|---|---|---|
| Cross-platform compatibility | Web-only app locked to browser capabilities; no native Bluetooth, no streaming software integration, no system audio capture | Native applications on iOS, Android, macOS, Windows, Linux, and web — each using the full power of the device |
| Device-first accuracy and performance | Browser speech API was inconsistent, unreliable, and unavailable offline on many platforms | Each platform's native speech recognition engine used directly — faster, more accurate, works offline |
| Privacy and security | Transcripts stored in browser using client-server shared key encryption — inherently not secure because browser storage is accessible to the serving application | Transcripts secured on-device behind proper authentication; never sent to a server unless the user opts into premium cross-device sync, in which case they are encrypted locally first with a key only the user holds |
| Reducing technical bottlenecks | Custom backend and specific technology choices concentrated knowledge in individuals who could become unavailable; evolving user needs created pressure that availability changes made difficult to meet | Architecture, conventions, and decisions documented in machine-readable files so any contributor (human or AI) can pick up where the last left off |
| Single-app limitations | Personal users and broadcasters crammed into one UI; app store compliance conflicts with premium features | Two purpose-built apps sharing a common core — each optimized for its audience and distribution model |

---

## Part B: v2 Architecture at a Glance

### Two Applications, One Shared Library

```
zip_captions (personal app)     zip_broadcast (professional app)
    iOS, Android, macOS,             macOS, Windows,
    Windows, Linux, web              Linux, web
         \                              /
          \                            /
           +--- zip_core (shared) ---+
                Dart library
                Speech-to-text engine abstraction
                Caption processing pipeline
                Zero-knowledge encryption
                Settings and configuration
                Bluetooth discovery
                Transport layer
                Localization (10 languages)
```

### Why Two Apps?

| Concern | Zip Captions | Zip Broadcast |
|---|---|---|
| Primary users | Deaf/HoH individuals, students | Streamers, educators, event captioners |
| Platforms | Phone + tablet + laptop | Desktop only |
| Distribution | App stores | Direct download (avoids app store gatekeepers) |
| Payment features | None (free forever) | Premium features via Patreon/Stripe |
| OBS integration | No | Yes |
| Broadcasting | Viewer only | Full broadcaster |

### Backend: Supabase (Self-Hosted)

Instead of a custom backend, v2 uses Supabase — an open-source platform that provides:
- **Authentication** (OAuth login — no custom auth code)
- **Database** (PostgreSQL with automatic API generation)
- **File storage** (for encrypted transcript blobs)
- **Real-time communication** (WebSocket channels for live caption relay)
- **Edge Functions** (serverless code for webhooks and processing)

This replaces thousands of lines of custom NestJS code with configuration and standard patterns. A new contributor does not need to understand a bespoke backend — they interact with a well-documented open-source platform.

### On-Device Security by Default

Transcripts are stored securely on the user's device behind proper authentication. They are never sent to a server unless the user opts in to the premium cross-device sync feature. When sync is enabled, transcripts are encrypted on-device using AES-256-GCM before leaving. The encryption key never leaves the device (except via explicit user-initiated transfer to the user's other devices). The server stores only encrypted blobs it cannot decrypt. This is not a policy ("we promise not to look") — it is architecture ("we cannot look").

### Speech Recognition Strategy

| Platform | Engine | Offline? |
|---|---|---|
| iOS / macOS | Apple Speech | Yes |
| Android | Google on-device STT | Yes |
| Windows / Linux / web | Whisper.cpp (open source) | Yes |
| Cloud fallback (premium) | Cloud STT providers | No |

v1 was locked to Web Speech API across all platforms. v2 uses a pluggable engine interface — the app automatically selects the best available engine for each platform, and new engines can be added without changing the rest of the system.

---

## Part C: The AI-DLC Workflow Explained for Non-Developers

### What is AI-DLC?

AI-DLC (Agentic Development Lifecycle) is a structured process that AI coding agents follow when working on this project. It ensures that every feature goes through requirements analysis, design review, test creation, and implementation — in that order — with human approval at every decision point.

### The Workflow in Plain Language

```
Phase 1: INCEPTION — "What are we building and why?"
  Step 1: Someone describes what they want (plain language)
  Step 2: AI reads the project's docs, architecture, and user personas
  Step 3: AI asks clarifying questions (the human answers)
  Step 4: AI drafts requirements and design documents
  Step 5: Human reviews and approves the design

Phase 2: CONSTRUCTION — "How do we build it?"
  Step 6: AI writes a detailed implementation plan
  Step 7: Human approves the plan
  Step 8: AI writes tests first (what should the feature do?)
  Step 9: AI writes code to make the tests pass
  Step 10: AI opens a pull request (proposed change)

Phase 3: REVIEW — "Is this right?"
  Step 11: Human reviews the change
  Step 12: Human merges (or requests revisions)
```

### Why This Matters

**The knowledge is in the documents, not in people's heads.**

This project has:
- 14 Architecture Decision Records explaining WHY each technical choice was made
- 3 detailed user personas with 17 usage scenarios
- A 9-phase roadmap with dependencies mapped
- A technical specification covering code style, testing, security, and conventions
- Per-package agent instruction files explaining boundaries and constraints

When an AI agent starts working on a feature, it reads ALL of these documents. It does not need to "learn the codebase" over months of experience — the codebase's intent, constraints, and patterns are explicitly documented and machine-readable.

**The approval gates prevent mistakes.**

The AI cannot merge code. It cannot skip the design phase. It cannot ignore the security rules. At every transition — from intent to design, from design to plan, from plan to code, from code to merge — a human must approve. The AI does the heavy lifting; the human makes the decisions.

**The audit trail is complete.**

Every user input and AI response during the workflow is logged with timestamps. Every design decision, every clarification question, every approval — all recorded. If someone wants to understand why a feature works the way it does, they can trace it back through the inception documents to the original intent.

### What an AI Agent Actually Reads

When an AI agent starts working on this project, it reads:
1. `AGENTS.md` — project rules, constraints, security requirements, what it can and cannot do
2. `ARCHITECTURE.md` — system design, component relationships
3. `CONTRIBUTING.md` — development workflow, branching strategy, review process
4. `docs/01-user-personas.md` — who the users are and what they need
5. `docs/02-architecture-decisions.md` — 14 ADRs explaining technical choices
6. `docs/03-roadmap.md` — 9-phase plan with dependencies
7. `docs/04-technical-specification.md` — coding standards, patterns, rules
8. `docs/RIVERPOD_CONVENTIONS.md` — state management patterns
9. `docs/TDD.md` — test-driven development process
10. Package-specific `AGENTS.md` files — per-component constraints

This is roughly 15,000+ words of structured guidance. A human developer would need weeks to internalize all of this. An AI agent reads it in seconds and follows it systematically.

---

## Part D: The Contribution Path — Before and After

### Contributing to v1

```
1. Learn the specific web framework (weeks to months)
2. Learn the state management pattern (days to weeks)
3. Learn the custom backend (days to weeks)
4. Learn the project's conventions (trial and error)
5. Find the right files to change (exploration)
6. Write the code (hoping it matches conventions)
7. Figure out what tests to write (if any existed)
8. Submit a pull request
9. Get feedback, revise, resubmit
```

**Barrier:** High. Required significant development experience in the project's specific technology choices. Most community members could file bug reports but not fix them.

### Contributing to v2 with AI-DLC

```
1. Describe what you want in plain language
2. Answer clarifying questions from the AI (conversational)
3. Review the design document (written in human-readable language)
4. Approve the design
5. The AI writes the code and tests
6. A maintainer reviews and merges
```

**Barrier:** Low for feature requests and design collaboration. You need judgment about what users need — not coding skill. The AI handles steps that previously required deep technical knowledge.

**For people who DO code:** AI-DLC is equally useful. It handles the "understand the codebase" overhead, follows conventions automatically, and produces tested code. A developer can focus on the interesting parts — architecture decisions, edge cases, performance — rather than boilerplate and pattern-matching.

---

## Part E: Getting Started — A Few Easy Steps

If someone watching the video is curious and has access to an AI coding tool, the path from "interested" to "contributing" is short:

1. **Get a copy of the project.** Download the project's source code to your computer.
2. **Open it with your AI assistant.** Point your AI coding tool at the project folder.
3. **Describe what you want to build.** Tell the AI what feature or improvement you have in mind, in plain language. The project's documentation will guide the AI through the structured workflow automatically.
4. **Have a conversation.** The AI will ask you clarifying questions about your idea. Answer them. Together, you will produce a design that fits the project.
5. **Let the AI build it.** Once you approve the design, the AI writes the code and tests following the project's standards.
6. **Submit it for review.** A maintainer reviews the result and merges it if it meets the project's quality bar.

That is it. No special training. No need to learn a programming language. Just an idea, an AI tool, and a willingness to answer a few questions about what you want.

---

## Part F: Design Principles That Carry Forward

These principles were established in v1 and are non-negotiable in v2:

1. **Accessibility is always free.** Any feature that enables a person to understand spoken language through text never requires payment, an account, or network connectivity.

2. **Transcript data belongs to the user.** Transcripts stay on-device by default. If the user opts into cross-device sync, zero-knowledge encryption ensures the server stores only encrypted blobs it cannot read. Not even project maintainers can access transcript content.

3. **No dependency on any single platform or provider.** Communication infrastructure is self-hosted. No reliance on third-party services that could be discontinued or restricted.

4. **Platform independence.** No app store dependency for premium features. Core accessibility is never at risk due to platform gatekeeper disputes.

5. **Feature parity before new features.** v1 capabilities are fully replicated before new functionality is added.

---

## Part G: Current Status (as of March 2026)

### Phase 0: Foundation (In Progress)

| Unit | Status | What It Is |
|---|---|---|
| 1. Monorepo Scaffold | Done, merged | Project structure, package layout, build system |
| 2. zip_core Library | Done, 81 tests passing | Shared logic: settings, themes, localization, state management |
| 3. App Shells | Done, 6 tests passing | Basic app skeletons for Zip Captions and Zip Broadcast |
| 4. Supabase Local Dev | In progress | Local backend development environment |
| 5. CI/CD Pipeline | Upcoming | Automated testing and deployment |
| 6. Spike 0.1 | Upcoming | End-to-end proof that all pieces connect |

### What Comes Next (Phases 1–8)

| Phase | Name | What It Delivers |
|---|---|---|
| 1 | Core Captioning | Real-time speech-to-text on all platforms. The core product. |
| 2 | Broadcasting & Transport | WebRTC streaming, OBS integration, remote viewing |
| 3 | Auth, Encryption & Sync | User accounts, zero-knowledge encryption, cross-device sync |
| 4 | Entitlements & Payment | Patreon integration, premium feature gates |
| 5 | BLE Local Discovery | Bluetooth-based local session discovery (no internet needed) |
| 6 | Release & v1 Deprecation | App store submissions, production deployment, v1 sunset |
| 7 | Observability & Polish | Monitoring, telemetry, performance optimization |
| 8 | Translation | Real-time translation between languages |

### Key Numbers
- **81** unit tests passing in zip_core
- **6** widget tests passing across app shells
- **14** architecture decision records documented
- **3** user personas with **17** usage scenarios
- **10** languages in the localization scaffold
- **9** phases on the roadmap
- **GPL-3.0** open-source license

---

## Part H: Key Quotes and Framings for the Video

> "v1 proved that real-time captions change lives. v2 is about making sure the community that depends on this tool can also help build it."

> "The people who understand the problem best — the people who use captions every day — were locked out of the process of solving it. v2 changes that."

> "The AI doesn't decide what to build. People decide what to build. The AI handles the part that used to require years of codebase familiarity."

> "You don't need to be a developer to contribute. You need to understand what users need. The AI-DLC workflow turns that understanding into working, tested code."

> "Your transcripts stay on your device. If you choose to sync them, they are encrypted before they leave — with a key only you hold. We did not just promise not to read them. We made it so we cannot."

> "We wrote down everything the next person — or AI — would need to know. That is how you stop any one individual from becoming a bottleneck."

> "AI-DLC is not 'AI writes the code and we hope for the best.' It is a structured process with human approval at every gate. The AI proposes. The human decides."

> "Clone the project, open it with an AI coding tool, and describe what you want. The documentation handles the rest."

> "Zip Captions is not just software. It is an accessibility solution that belongs to its community."
