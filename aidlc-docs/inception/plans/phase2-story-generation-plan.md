# Story Generation Plan — Phase 2: Broadcasting & Transport

## Plan Overview

Phase 2 uses the existing personas in `docs/01-user-personas.md`: Jordan (broadcaster) and Sam (viewer). Alex appears only as a regression concern, since local features must still work signed out. This plan converts `phase2-requirements.md` (FR-1 through FR-10) into user stories with acceptance criteria.

Story IDs continue from Phase 1 (S-11 onward, Proto-10 onward), so every ID is unique across the project. Output files use a `phase2-` prefix so the Phase 1 artifacts stay untouched.

Fill in the letter choice after each `[Answer]:` tag. If none of the options match, choose X and describe your preference.

## Questions

### Question 1 — Carry forward Phase 1 conventions
In Phase 1 you chose: feature-based organization (Q1:B), coarse granularity with one story per FR group (Q2:A), scenario milestones plus capability stories (Q3:C), Given/When/Then for every story (Q4:A), spikes as dependencies rather than stories (Q5:A), and one prototype story per screen that blocks implementation (Q6:A). Should Phase 2 use the same conventions?

A) **Yes, carry all six forward unchanged.** Phase 2 produces roughly 9 feature stories (FR-10 OBS is spike-only, not a story), a few enablers, prototypes and milestones. **(Recommended)**
B) Carry forward everything except granularity. Split the two largest groups, FR-6 (broadcaster session) and FR-7 (viewer), into 2-3 stories each.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 2 — Viewer persona scenario gap
The persona doc has no scenario for Sam joining a **remote broadcast through a link**. S3.2 is BLE local discovery (Phase 5), and S3.1 and S3.3 are self-captioning. The only remote-viewer journey is inside Jordan S2.2 ("available to remote students on their own devices"). How should Sam's Phase 2 journey be covered?

A) **Add a new scenario, S3.6 "Joining a Remote Broadcast by Link"** (Sam opens a shared link on phone or browser, reads live captions with their own display settings, and rides out a network drop). It gets its own milestone, and `docs/01-user-personas.md` is updated at Documentation Refinement. **(Recommended)**
B) No new scenario. Sam's viewer journey is covered only through the Jordan S2.2 and S2.3 milestones.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 3 — Scenario integration milestones
Which scenario milestones should Phase 2 include? Phase 1 delivered M-S2.2 (Classroom) only partially, without remote students or a second monitor.

A) **M-S2.2 Classroom completed** (second-monitor external display plus remote students joining by URL), **M-S2.3 Auditorium, Phase 2 slice** (projector external display plus audience joining by URL; profiles, line-in and bilingual display stay out of scope), and **M-S3.6** if Q2 is A. **(Recommended)**
B) M-S2.2 completed, plus M-S3.6 if Q2 is A. No S2.3 milestone until its other requirements (profiles, projection formatting) are scheduled.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 4 — UI prototype scope
The new screens are: Zip Broadcast sign-in, broadcast setup, live broadcast dashboard, and external-display controls; Zip Captions join screen and live viewer states (connecting, live, reconnecting, not broadcasting, ended, full, cannot connect). Which prototypes should gate implementation?

A) **One prototype per new screen (6 prototypes: Proto-10 to Proto-15)**, the Phase 1 precedent. The viewer-states prototype shows all 7 states on one screen. **(Recommended)**
B) Prototypes only for the two complex screens (live broadcast dashboard and viewer states). The simpler screens use the Phase 1 design system directly.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 5 — Security-critical approach reviews
AGENTS.md requires your approval of the approach **before implementation** for three Phase 2 areas: the OAuth flow (FR-1.7), RLS policies (NFR-3.4), and server-side log configuration for Coturn and Realtime (NFR-3.1). How should these gates appear in the stories?

A) **Separate review stories (SR-01 to SR-03)** that block their implementation stories, in the same way prototypes block UI. This makes the gates visible in sequencing and unit planning. **(Recommended)**
B) A mandatory first acceptance criterion inside each affected story ("Given the approach has been approved by a human reviewer...").
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 6 — Infrastructure enabler stories
Coturn deployment and the Supabase migration (broadcast-ID registry, RLS, Realtime channel authorization) have no user-facing value on their own, but the exit criteria depend on them. How should they be represented?

A) **Enabler stories** with Given/When/Then criteria, in the same way Phase 1 treated the caption bus and STT registry (for example "Coturn STUN/TURN service" and "Broadcast identity backend"). **(Recommended)**
B) Not stories. They are handled inside the Infrastructure Design and Code Generation of the units that need them.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 7 — Failure-path and security acceptance criteria
Phase 2 has many failure paths: not broadcasting, full, ended, cannot connect, broadcaster disappears, malformed signaling, and enumeration attempts. Where should they be specified?

A) **Inside each story.** Every story includes its error, edge-case and security criteria next to the success path, so a story is complete only when its failure paths pass. **(Recommended)**
B) Success-path criteria in each story, plus one separate "Phase 2 hardening" story that gathers the failure-path and security criteria.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Generation Steps

After the questions are answered and the plan is approved, execute these steps:

- [x] Step 1: Confirm persona coverage: Jordan and Sam scenario mapping; draft S3.6 text if Q2 is A (it is recorded for Documentation Refinement and does not modify `docs/`) — S3.6 drafted in phase2-personas.md
- [x] Step 2: Generate the story structure per the approved conventions (Q1) — feature-based, coarse, G/W/T
- [x] Step 3: Generate enabler stories per Q6 (Coturn, broadcast identity backend, signaling, WebRTC transport) — S-11 to S-14
- [x] Step 4: Generate the broadcaster authentication story (FR-1) — S-15
- [x] Step 5: Generate Zip Broadcast feature stories (FR-5 output target, FR-6 session management, FR-8 capacity, FR-9 external display) — S-16, S-17, S-18, S-20 (S-20 completes the Phase 1 CaptionOverlayTarget)
- [x] Step 6: Generate Zip Captions viewer stories (FR-7, including the `/b/{id}` web route) — S-19
- [x] Step 7: Generate security review stories per Q5 — SR-01 to SR-03
- [x] Step 8: Generate prototype stories per Q4 — Proto-10 to Proto-15
- [x] Step 9: Generate scenario milestones per Q2 and Q3, including the signed-out local-features regression check (exit criterion 9) — M-S2.2, M-S2.3, M-S3.6, M-REG-01
- [x] Step 10: Write Given/When/Then acceptance criteria for all stories, with failure paths placed per Q7
- [x] Step 11: Record spike dependencies (2.1, 2.2, 2.3) and TBD values on the affected stories
- [x] Step 12: Build the traceability matrix (story to FR, NFR, persona and exit criterion)
- [x] Step 13: Identify story dependencies and sequencing
- [x] Step 14: Write `user-stories/phase2-stories.md` and `user-stories/phase2-personas.md`
- [x] Step 15: Verify INVEST compliance for all stories
