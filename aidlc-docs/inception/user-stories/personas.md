# Phase 1 Personas Reference

Personas are defined in `docs/01-user-personas.md` (the source of truth). This file maps Phase 1 story coverage to each persona.

## Alex (Personal User)
**Phase 1 scenarios:** S1.1 (one-on-one), S1.2 (family dinner), S1.3 (medical appointment)
**Phase 1 stories:** S-01, S-02, S-03, S-04, S-05, S-06, S-09
**Prototypes:** Proto-01 through Proto-05
**Milestones:** M-S1.1, M-S1.2, M-S1.3

Alex is the primary personal user. Phase 1 delivers the complete self-captioning experience: start with a single tap, see live captions, save transcripts. All Phase 1 features for Alex are free.

## Jordan (Broadcaster)
**Phase 1 scenarios:** S2.1 (solo streamer with OBS), S2.2 (classroom)
**Phase 1 stories:** S-01, S-02, S-03, S-04, S-06, S-07, S-08, S-10
**Prototypes:** Proto-06 through Proto-09
**Milestones:** M-S2.1, M-S2.2

Jordan uses Zip Broadcast for local captioning with OBS integration and browser source output. Phase 1 does not include remote viewers (Phase 2) or BLE session advertising (Phase 5). All Phase 1 features for Jordan are free.

## Sam (Student/Attendee)
**Phase 1 scenarios:** S3.1 (lecture hall self-captioning)
**Phase 1 stories:** S-01, S-02, S-03, S-04, S-05, S-06, S-09
**Prototypes:** Proto-01 through Proto-05 (shares Zip Captions UI with Alex)
**Milestones:** M-S3.1

Sam uses Zip Captions for self-captioning in Phase 1. S3.2 (discovering local broadcast sessions) is deferred to Phase 5 (BLE). Searchable transcript history (S-05) is built in Phase 1 but the entitlement gate for Sam is Phase 4.

## Deferred Persona Scenarios
| Scenario | Deferred To | Reason |
|----------|-------------|--------|
| S1.4 (providing captions for someone else) | Phase 1+ | Kiosk mode is a refinement, not core |
| S1.5 (cross-language conversation) | Phase 8 | Translation |
| S2.3 (conference/auditorium) | Phase 2+ | Deployment mode, profiles |
| S2.4 (remote setup/delegation) | Phase 2+ | Remote monitoring, premium |
| S2.5 (remote captioning machine) | Parked | Complex networking |
| S2.6 (bilingual broadcast) | Phase 8 | Translation |
| S3.2 (local broadcast discovery) | Phase 5 | BLE |
| S3.3 (remote meeting) | Phase 1 (partial via S-06 system audio) | System audio capture covers this |
| S3.4 (viewer-side translation) | Phase 8 | Translation |
| S3.5 (caption overlay) | Parked | Premium, desktop overlay |
