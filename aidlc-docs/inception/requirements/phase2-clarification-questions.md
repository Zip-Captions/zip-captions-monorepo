# Phase 2 — Broadcasting & Transport: Clarification Questions

Your answers to `phase2-requirement-verification-questions.md` resolved most of the Phase 2 scope. Q1 (A), Q5 (A), Q7 (A), Q10 (C, 100-200 viewer target), Q11 (A) and Q12 (A) are accepted as-is. The answers below interact with each other or with ADR-011 in ways that need a decision before `phase2-requirements.md` can be written.

Fill in the letter choice after each `[Answer]:` tag. If none of the options match, choose X and describe your preference.

---

## Contradiction 1: Pulled-forward auth (Q2:B) vs. deferred persistence (Q9:B)

Q9 option B deferred Postgres persistence and RLS "to Phase 3 when auth exists". With Q2:B, auth now exists in Phase 2, so that reason no longer applies. Separately, ADR-011 makes the broadcast ID **permanent and reusable across sessions** (`zipcaptions.app/b/{broadcast_id}`) and specifies a Supabase table mapping `broadcast_id -> current_session_id -> signaling channel`. A permanent ID cannot live only in ephemeral Realtime presence state: it would be lost whenever the channel empties or the server restarts.

### Clarification Question 1
Where should broadcast identity and session state live in Phase 2?

A) **Hybrid.** Persist only the permanent `broadcast_id` registry (one row per authenticated broadcaster, RLS keyed to `auth.uid()`) in Postgres. Active-session state (live or not, current session ID, viewer presence) stays ephemeral in Supabase Realtime presence/channel state, which keeps the Q9 intent for session records. **(Recommended)**
B) **No new tables.** Store the broadcast ID in the GoTrue user record (`app_metadata`). Public URL resolution (`broadcast_id -> broadcaster`) then needs an Edge Function using the service role, since anonymous viewers cannot query `auth.users`.
C) **Full persistence.** Persist both the broadcast-ID registry and per-session records in Postgres with RLS (reverts Q9 to option A).
X) Other (please describe after [Answer]: tag below)

[Answer]:A

---

## Ambiguity 1: What "minimal authentication" means (Q2:B)

Q2:B requires a broadcaster to sign in before broadcasting, with full OAuth and account merging left in Phase 3. The roadmap's Phase 3 auth is "OAuth login with arbitrary providers (Google, Microsoft, Apple at minimum)". The Phase 2 subset needs a definition. **OAuth flows are security-critical under AGENTS.md: the approach needs your review before any implementation.**

### Clarification Question 2
Which sign-in mechanism does Phase 2 ship?

A) **Supabase GoTrue with the provider-agnostic OAuth architecture from the Phase 3 spec, enabling one or two providers** (for example Google and GitHub). Phase 3 adds the remaining providers, account merging, account deletion and profile. This avoids building a throwaway mechanism. **(Recommended)**
B) **Email magic link / OTP only** through GoTrue. No OAuth in Phase 2; OAuth arrives in Phase 3 and links to the existing email accounts.
C) **Full Phase 3 authentication scope pulled into Phase 2** (all providers, account merging, deletion, profile). Phase 3 keeps only encryption and sync.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Clarification Question 3
Which Zip Broadcast features require sign-in? The Phase 3 principle is "sign-in is optional; all core features work without an account".

A) **Only remote broadcasting** (stable URL, WebRTC viewers) requires sign-in. Local captioning and the local outputs (OBS, browser source, external display) keep working without an account, as they do today. **(Recommended)**
B) **All of Zip Broadcast** requires sign-in.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Ambiguity 2: What optional viewer sign-in does in Phase 2 (Q8:B)

Q8:B allows viewers to sign in optionally "to enable future per-viewer features". No per-viewer feature exists in Phase 2, so the question is how much of that work lands now. Showing a viewer's identity to the broadcaster would also be a new privacy surface.

### Clarification Question 4
What does optional viewer sign-in include in Phase 2?

A) **Protocol-ready only.** The join protocol and viewer model carry an optional, nullable viewer identity. The sign-in UI in Zip Captions arrives in Phase 3 with the rest of the account features. Phase 2 viewers are effectively anonymous. **(Recommended)**
B) **Sign-in UI in Zip Captions now.** It reuses the Phase 2 auth module. A signed-in viewer's identity is sent on join but **not shown** to the broadcaster.
C) **Sign-in UI now, and the broadcaster's dashboard shows signed-in viewers' display names.** Anonymous viewers appear as "Anonymous".
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Contradiction 2: Unencrypted relay deferred (Q3:C) vs. local Wi-Fi WebSocket included (Q4:B)

Q3:C gates the Supabase relay on Phase 3 because its payloads would not be end-to-end encrypted. A local Wi-Fi WebSocket server has the same exposure: a plain `ws://` server on conference or classroom Wi-Fi lets anyone on that network read the captions. With the Security Baseline enabled (Q11:A), encryption in transit is required.

There are two further considerations:
- In Phase 2, viewers find the broadcast through the stable URL, which already needs internet plus Supabase signaling. On the same network, WebRTC ICE already picks a **direct LAN path** (host candidates, DTLS-encrypted, no TURN). This is roadmap exit criterion "WebRTC P2P connection works between two devices on the same network". A local WebSocket's unique value is **no-internet** delivery, which depends on BLE discovery (ADR-007, Phase 5).
- Platform limits: Zip Broadcast **web** cannot host a WebSocket server, and a browser viewer on an HTTPS page cannot connect to `ws://` or to a self-signed `wss://` server.

### Clarification Question 5
How should the local Wi-Fi WebSocket transport be handled?

A) **Defer it to Phase 5** alongside BLE discovery. Phase 2 same-network delivery uses WebRTC host candidates, which are encrypted and already required by the exit criteria. **(Recommended)**
B) **Keep it in Phase 2 with TLS (`wss://`).** The broadcaster generates a per-session self-signed certificate and pins its fingerprint to viewers over the authenticated signaling channel. This is a security-critical design needing approval. It works for native viewers only (desktop broadcaster to native Zip Captions); web is excluded on both sides.
C) **Keep it in Phase 2 as plain `ws://`**, with a broadcaster warning like the relay warning. Native only, as in B.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Ambiguity 3: Where the deferred relay work lands (Q3:C)

Q3:C removes from Phase 2 the opt-in Supabase Realtime relay, the "Allow server relay" toggle, its warning text, mid-broadcast toggling, and payload E2E encryption. The roadmap's Phase 2 exit criterion "Supabase Realtime relay works when opted in and WebRTC fails entirely" is also affected.

### Clarification Question 6
How should the relay be tracked?

A) **Move the relay deliverables and exit criterion to Phase 3**, after its encryption work. Phase 2 closes without them. Phase 2 still uses Realtime for signaling and presence only (it never carries caption payloads). The roadmap change is recorded at Documentation Refinement. **(Recommended)**
B) **Keep the relay as a late Phase 2 unit blocked on Phase 3 encryption.** Phase 2 stays open until it ships.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Ambiguity 4: Viewer scale target and what Spike 2.1 must measure (Q10 with Q3:C)

With the relay deferred, Realtime carries only signaling and presence, so Spike 2.1 as written ("how many concurrent connections can self-hosted Realtime handle") no longer tests the path that limits the 100-200 viewer target. That path is the **broadcaster's fan-out**: one Zip Broadcast instance holding 100-200 simultaneous WebRTC peer connections, some relayed through Coturn.

### Clarification Question 7
How should Spike 2.1 be scoped, and what happens if a broadcast reaches capacity?

A) **Re-scope Spike 2.1** to measure (1) broadcaster fan-out, meaning CPU, memory and latency with N data channels on desktop and web, and (2) Realtime signaling and presence load at 200 joining viewers. Spike 2.3 adds TURN load at that scale. A broadcast that reaches its measured cap refuses further viewers with a clear "broadcast is full" message, and the broadcaster sees the cap on the dashboard. **(Recommended)**
B) Re-scope Spike 2.1 as in A, but **do not enforce a cap**: extra viewers are attempted and fail or degrade naturally, and the broadcaster only sees a warning.
C) **Keep Spike 2.1 as written.** Fan-out capacity is handled later in NFR Design.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Ambiguity 5: External display platform scope (Q6:B)

Q6:B includes external or second-screen output "on platforms that support it". ADR-008 places it as a broadcaster output (auditorium mode), which suggests Zip Broadcast (macOS, Windows, Linux, web). A second native window in Flutter desktop probably needs a new dependency (a multi-window plugin), and new dependencies need your approval under AGENTS.md.

### Clarification Question 8
Which platforms get external-display output in Phase 2?

A) **Zip Broadcast desktop only** (macOS, Windows, Linux). A borderless caption window is placed on a user-chosen display. Web is excluded. **(Recommended)**
B) **Zip Broadcast desktop and web.** Web opens a pop-out caption window that the user drags to the second screen.
C) **Zip Broadcast (desktop and web) and Zip Captions mobile.** Mobile adds HDMI, AirPlay or Cast mirroring of the caption view.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---
