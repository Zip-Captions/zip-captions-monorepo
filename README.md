# Zip Captions v2

Free, open-source real-time speech-to-text captioning for deaf and hard-of-hearing users and broadcasters. Runs natively on iOS, Android, macOS, Windows, Linux, and web. Transcript data belongs exclusively to the user — the server is architecturally incapable of accessing caption content.

---

## Applications

### Zip Captions

Personal captioning app for deaf and hard-of-hearing users and students. Captures speech from a microphone, line-in, or system audio and renders captions in real time. Supports on-device transcript saving, optional encrypted sync, and local broadcast viewing.

Platforms: iOS, Android, macOS, Windows, Linux, web (PWA fallback)

### Zip Broadcast

Professional captioning app for broadcasters, streamers, and educators. Outputs captions to OBS Studio, browser sources, WebRTC peers, local Wi-Fi, BLE, and Supabase Realtime simultaneously. Premium features distributed outside app stores.

Platforms: macOS, Windows, Linux, web (PWA fallback)

---

## Repository Structure

This is a [Melos](https://melos.invertase.dev)-managed Dart/Flutter monorepo.

```
packages/
  zip_core/        Shared Dart library — STT engine abstraction, audio capture,
                   caption bus, zero-knowledge encryption, BLE discovery,
                   transport layer, models, and settings
  zip_captions/    Flutter app — personal user and student personas
  zip_broadcast/   Flutter app — broadcaster and professional persona
  zip_supabase/    Supabase backend — Edge Functions (TypeScript/Deno),
                   Postgres migrations, and RLS policies
```

---

## Design Principles

**Accessibility is always free.** Any feature that enables a person to understand spoken language through text never requires payment, an account, or network connectivity.

**Transcript data belongs to the user.** Zero-knowledge AES-256-GCM encryption. The server stores only encrypted blobs. Not even project maintainers can access transcript content.

**No Google dependency.** ICE infrastructure is self-hosted via Coturn. No reliance on Google STUN servers or any third-party ICE provider.

**Platform independence.** No app store dependency for premium features. Core accessibility is never at risk due to platform gatekeeper disputes.

**Feature parity before new features.** v1 capabilities are fully replicated before new functionality is added.

---

## Development

This project uses the [AI-DLC](https://github.com/awslabs/aidlc-workflows) agentic development workflow. Features are derived directly from the project's roadmap and user persona documents through a structured inception process before any code is written.

To get started with a feature:

```
Using AI-DLC, determine the next feature to build for Zip Captions
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development workflow, branching strategy, and code review process.

See [AGENTS.md](AGENTS.md) for agent-specific instructions, constraints, and autonomy boundaries.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the system architecture, component map, and communication paths.

---

## License

[GPL-3.0](LICENSE)
