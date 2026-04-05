# Unit of Work Story Map — Phase 1: Core Captioning

## Story-to-Unit Assignment

| Story | Title | Unit | Rationale |
|-------|-------|------|-----------|
| S-01 | STT Engine Interface and Registry | Unit 1: Core Abstractions | Defines foundational SttEngine contract, SttEngineRegistry, SttResult model |
| S-02 | Platform-Native STT Implementation | Unit 2: Platform STT + Audio | PlatformSttEngine wrapping speech_to_text, platform-specific behavior |
| S-03 | Caption Bus | Unit 1: Core Abstractions | CaptionBus, CaptionOutputTarget interface, CaptionOutputTargetRegistry |
| S-04 | Caption Rendering UI | Unit 3: Output Targets | OnScreenCaptionTarget implementation, caption display buffer |
| S-05 | Transcript Management | Unit 3: Output Targets | TranscriptRepository, TranscriptDatabase, TranscriptWriterTarget, FTS5, export |
| S-06 | Audio Capture | Unit 2: Platform STT + Audio | Microphone/system audio capture, permissions, multi-input management |
| S-07 | OBS WebSocket Integration | Unit 3: Output Targets | ObsWebSocketTarget, OBS v5 protocol, connection management |
| S-08 | Browser Source Output | Unit 3: Output Targets | BrowserSourceTarget, BrowserSourceServer, shelf HTTP, fixed two-line rendering |
| S-09 | Zip Captions App UI | Unit 5: Zip Captions App | All Zip Captions screens, navigation, app-level orchestration |
| S-10 | Zip Broadcast App UI | Unit 6: Zip Broadcast App | All Zip Broadcast screens, multi-input UI, OBS/browser source/overlay wiring |

## Prototype-to-Unit Assignment

| Prototype | Screen | Unit | Blocks |
|-----------|--------|------|--------|
| Proto-01 | Zip Captions — Home | Unit 4: UI Prototypes | Unit 5 |
| Proto-02 | Zip Captions — Recording | Unit 4: UI Prototypes | Unit 5 |
| Proto-03 | Zip Captions — Settings | Unit 4: UI Prototypes | Unit 5 |
| Proto-04 | Zip Captions — Session History | Unit 4: UI Prototypes | Unit 5 |
| Proto-05 | Zip Captions — Transcript Viewer | Unit 4: UI Prototypes | Unit 5 |
| Proto-06 | Zip Broadcast — Home | Unit 4: UI Prototypes | Unit 6 |
| Proto-07 | Zip Broadcast — Recording | Unit 4: UI Prototypes | Unit 6 |
| Proto-08 | Zip Broadcast — Settings | Unit 4: UI Prototypes | Unit 6 |
| Proto-09 | Zip Broadcast — Audio Config | Unit 4: UI Prototypes | Unit 6 |

## Milestone-to-Unit Assignment

| Milestone | Scenario | Unit | Composed From |
|-----------|----------|------|---------------|
| M-S1.1 | Alex — One-on-One Conversation | Unit 7: Integration | S-01, S-02, S-03, S-04, S-06, S-09 |
| M-S1.2 | Alex — Family Dinner | Unit 7: Integration | S-01, S-02, S-03, S-04, S-06, S-09 |
| M-S1.3 | Alex — Medical Appointment | Unit 7: Integration | S-01, S-02, S-03, S-04, S-05, S-06, S-09 |
| M-S2.1 | Jordan — Solo Streamer with OBS | Unit 7: Integration | S-01, S-02, S-03, S-04, S-06, S-07, S-08, S-10 |
| M-S2.2 | Jordan — Classroom | Unit 7: Integration | S-01, S-02, S-03, S-04, S-06, S-08, S-10 |
| M-S3.1 | Sam — Lecture Hall Self-Captioning | Unit 7: Integration | S-01, S-02, S-03, S-04, S-05, S-06, S-09 |

---

## Coverage Verification

### All Feature Stories Assigned

| Story | Assigned | Unit |
|-------|----------|------|
| S-01 | Yes | Unit 1 |
| S-02 | Yes | Unit 2 |
| S-03 | Yes | Unit 1 |
| S-04 | Yes | Unit 3 |
| S-05 | Yes | Unit 3 |
| S-06 | Yes | Unit 2 |
| S-07 | Yes | Unit 3 |
| S-08 | Yes | Unit 3 |
| S-09 | Yes | Unit 5 |
| S-10 | Yes | Unit 6 |

**Result**: 10/10 feature stories assigned. No gaps.

### All Prototype Stories Assigned

**Result**: 9/9 prototype stories assigned to Unit 4. No gaps.

### All Milestones Assigned

**Result**: 6/6 milestones assigned to Unit 7. No gaps.

### All Spikes Assigned

| Spike | Assigned | Status |
|-------|----------|--------|
| Spike 1.1 | Yes | Pre-construction |
| Spike 1.2 | Yes | Pre-construction (parallel with Unit 1) |
| Spike 1.3 | Yes | Pre-construction |

**Result**: 3/3 spikes assigned. No gaps.

---

## Unit Size Assessment

| Unit | Stories | Components | Construction Stages | Relative Size |
|------|---------|-----------|-------------------|--------------|
| Spike 1.1 | — | — | Research | Small |
| Spike 1.2 | — | — | Research | Small |
| Spike 1.3 | — | — | Research + PoC | Small-Medium |
| Unit 1 | S-01, S-03 | 19 (new + modified) | FD, NFR-R, NFR-D, CG | Large |
| Unit 2 | S-02, S-06 | 5 | FD, NFR-R, NFR-D, CG | Large |
| Unit 3 | S-04, S-05, S-07, S-08 | 12 | FD, NFR-R, NFR-D, ID, CG | Large |
| Unit 4 | Proto-01..09 | 9 HTML files | CG | Medium |
| Unit 5 | S-09 | 7 | FD, NFR-R, NFR-D, CG | Medium-Large |
| Unit 6 | S-10 | 5 + orchestration | FD, NFR-R, NFR-D, ID, CG | Large |
| Unit 7 | M-S1.1..M-S3.1 | — | B&T, Doc Refinement | Medium |

**Note**: Unit 1 is the largest because it includes the DisplaySettings rename (touching all packages), all core abstractions, and multiple service classes. Unit 3 has the most stories (4) but they are all output target implementations following the same CaptionOutputTarget pattern. Unit 6 is complex due to multi-input orchestration and caption overlay.
