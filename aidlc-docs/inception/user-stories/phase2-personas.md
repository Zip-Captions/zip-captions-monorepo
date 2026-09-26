# Phase 2 Personas Reference

Personas are defined in `docs/01-user-personas.md` (the source of truth). This file maps Phase 2 story coverage to each persona and drafts one new scenario, S3.6, to be applied to the persona doc at Documentation Refinement (plan Q2:A).

## Jordan (Broadcaster)
**Phase 2 scenarios:** S2.2 (classroom, completed), S2.3 (auditorium, Phase 2 slice)
**Phase 2 stories:** S-11, S-12, S-13, S-14, S-15, S-16, S-17, S-18, S-20
**Prototypes:** Proto-10, Proto-11, Proto-12, Proto-13
**Milestones:** M-S2.2, M-S2.3, M-REG-01

Phase 2 gives Jordan live remote broadcasting through a permanent link, which requires sign-in. It also adds a second-screen or projector caption display, which does not. S2.1 (OBS) is unchanged apart from the Spike 2.2 confirmation. S2.4 (remote setup and delegation), S2.5 (remote captioning machine) and S2.6 (bilingual display) remain out of scope.

## Sam (Student / Attendee)
**Phase 2 scenarios:** S3.6 (new, below); the viewer side of S2.2 and S2.3
**Phase 2 stories:** S-11, S-13, S-14, S-16, S-18, S-19
**Prototypes:** Proto-14, Proto-15
**Milestones:** M-S3.6, M-S2.2, M-S2.3

Sam joins broadcasts anonymously by link or ID and reads them in their own display settings. S3.2 (BLE local discovery with no internet) remains Phase 5.

## Alex (Personal User)
**Phase 2 scenarios:** none new
**Phase 2 stories:** S-15 (signed-out regression only)
**Milestones:** M-REG-01

Phase 2 must not change Alex's experience. Everything from Phase 1 keeps working without an account.

---

## Draft Scenario S3.6 — Joining a Remote Broadcast by Link

*For addition to `docs/01-user-personas.md` under Persona 3 at Documentation Refinement (requires per-change approval).*

#### S3.6 — Joining a Remote Broadcast by Link
Sam's instructor (or a streamer, or an event organizer) is captioning with Zip Broadcast and shares a link such as `zipcaptions.app/b/k7m9x2` through the course page, a chat message or a stream description. Sam opens it in a browser on a laptop, or pastes it into Zip Captions on a phone, and live captions start immediately, with no account and no join code. Captions use Sam's own text size, font, contrast and flow direction. If Sam's phone switches from Wi-Fi to cellular, the captions pause briefly and then resume on their own. If Sam opens the link before the session starts, the app says the broadcaster is not live yet rather than showing an error.

**Key requirements:**
- Join by link or by typing a short broadcast ID; the same link works for every session by that broadcaster
- No account, no sign-in, no join code
- Viewer-controlled text customization
- Automatic reconnection after network changes
- Clear states: not live yet, live, reconnecting, ended, full, cannot connect (with reason)
- Works in a browser as well as in the native app
