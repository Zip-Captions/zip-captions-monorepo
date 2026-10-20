# Spike 2.2 Report: OBS Closed-Caption API Confirmation

**Date**: 2026-10-19
**Status**: COMPLETE for the request-correctness question. Exit criterion 7 is
**satisfied with a recorded follow-up**: the shipped code sends the correct OBS
WebSocket v5 request with the correct request field on the correct transport,
verified against OBS's own request-handler source. Two payload-behaviour gaps
are identified below and are not resolved by this spike; they need a live OBS
test, which was not possible in this environment.
**Scope**: Confirm that `ObsWebSocketTarget` uses the correct OBS WebSocket v5
closed-caption request on current OBS versions, and document the protocol
interaction.
**Related**: `phase2-requirements.md` exit criterion 7; FR-10; Unit 9 (the
two-device/live-OBS verification stage).

---

## Executive Summary

**The request is correct.** The shipped implementation calls
`SendStreamCaption` with a `captionText` string field over OBS WebSocket v5.
That matches OBS's own `RequestHandler::SendStreamCaption` exactly: same
`@requestType`, same `captionText | String` request field, marked required, and
the same "caption text" semantics. Three independent layers agree:

1. **Application code** — `ObsWebSocketTarget._sendCaption` and
   `ObsConnectionNotifier.send` both call
   `client.stream.sendStreamCaption(text)`.
2. **Dart client** — `obs_websocket` 5.2.3+2 emits
   `Request('SendStreamCaption', requestData: {'captionText': captionText})`,
   and its own doc comment marks the request as added in v5.0.0, RPC version 1.
3. **OBS server source** — `RequestHandler::SendStreamCaption` validates
   `captionText` as a required string, returns
   `RequestStatus::OutputNotRunning` when streaming is inactive, and forwards
   the text to `obs_output_output_caption_text2(output, text, 0.0)`.

So the API-shape half of exit criterion 7 is met on evidence, not on the
assumption that the package's method name was right.

**What this spike did not and cannot confirm here: whether the text arrives as
usable closed captions in a viewer's picture.** That depends on open questions
below (CEA-608 payload constraints and streaming state), not on the request
being well-formed. That is the honest boundary of a source-level confirmation,
and it is recorded as the follow-up rather than presented as proven.

**One real defect was found while confirming the API**, and it is independent of
the API question:

> The shipped code sends a caption per **final** `SttResult`, which with
> Zip Captions' segmentation can be a full sentence or a long utterance, and it
> sends each one as a fresh `SendStreamCaption` call with no roll-up and no
> clearing. It never sends an empty caption to clear the previous one. Streaming
> caption standards that OBS's CEA-608 path feeds are line-length- and
> duration-limited, so a long sentence will be truncated or rejected by the
> encoder chain, and the last caption stays on screen after captioning stops
> until something clears it. **This is a data-shaping problem, not a request
> problem**, and it is scoped as a follow-up for the OBS output target rather
> than silently reclassified as "confirmed".

---

## Methodology

Source-level confirmation, three-way, against material already in the repo plus
the resolved package version:

| Layer | Artifact | How it was checked |
|---|---|---|
| Application | `packages/zip_broadcast/lib/src/output/obs/obs_websocket_target.dart:167`, `lib/src/providers/obs_connection_notifier.dart:95` | Read the call sites and the final-only gating (`onCaptionEvent` matches `SttResultEvent` with `result.isFinal`) |
| Dart client | `obs_websocket` 5.2.3+2 (resolved by `^5.0.0` in `packages/zip_broadcast/pubspec.yaml:33`), `lib/src/request/stream.dart:84-93` | Read the generated request wrapper: request name, request data key, documented RPC/version |
| OBS | `spikes/phase2/obs/reference/RequestHandler_Stream.cpp:131-162` | Read `RequestHandler::SendStreamCaption`: validator, required flag, streaming-state guard, output call |

Reference source on disk: seven files under `spikes/phase2/obs/reference/`
(`RequestHandler_Stream.cpp`, `obs-websocket.cpp`, `Config.cpp`,
`captions.cpp/.hpp`, `captions-handler.cpp/.hpp`).

### What was not run, and why

**No live OBS instance.** There was no OBS Studio installation, no display
server to run it against, and no streaming destination in this environment;
launching OBS headlessly to assert on the encoded CEA-608 bitstream would also
need a real output and a capture of the transport stream. The spike's stated
scope is "confirm the correct request and document the protocol interaction",
which is answerable from source; asserting on rendered closed captions is not,
and is not claimed. `docs/TDD.md`'s no-native-stack-in-unit-tests rule also
means no automated test can close this gap.

---

## Protocol interaction, as implemented

1. **Connect.** `ObsWebSocket.connect(url, password: ...)` with a 10 s timeout,
   `ws://host:port` (scheme preserved if the user typed `ws://`/`wss://`),
   password passed through and never logged (SEC-U3.2).
2. **Only finals are forwarded.** `onCaptionEvent` filters to final
   `SttResult`s; interim results never reach OBS.
3. **One request per final.** `{requestType: "SendStreamCaption",
   requestData: {captionText: "<final text>"}}`. No per-character or
   per-word updates.
4. **Failure is a reconnect trigger.** A thrown request marks the client dead,
   closes it, and schedules exponential backoff (1 s to 30 s, 10-minute give-up
   to `ObsError`). This is unchanged and is the right behaviour for a
   `SendStreamCaption` rejection caused by OBS restarting.
5. **Streaming state is the user's responsibility.** OBS rejects the request
   with `OutputNotRunning` when it is not streaming. The code treats that as a
   generic failure and retries with backoff, which is safe but noisy: it will
   retry for up to 10 minutes while OBS sits idle before reporting `ObsError`.
   Recorded as a minor follow-up (map `OutputNotRunning` to a distinct,
   non-retrying state) rather than a blocker.

---

## Findings

| # | Finding | Confidence | Basis |
|---|---|---|---|
| 1 | Request name, field name and required-ness match OBS v5 exactly | **High** | OBS source + generated client + call sites agree |
| 2 | `captionText` is the only request field; no other parameters exist to omit or misname | **High** | `RequestHandler::SendStreamCaption` has one validated field |
| 3 | Sending outside an active stream fails with `OutputNotRunning` | **High** | `obs_frontend_streaming_active()` guard in OBS source |
| 4 | Finals-only is a sound choice for a request called per caption | **Medium** | OBS source shows a full text replacement per call with `0.0` delay; no visible partial-update contract |
| 5 | Long finals will be truncated or rejected by CEA-608 constraints | **Medium, unmeasured** | Caption standards constrain line length and characters per second; the reference set does not include OBS's CEA-608 encoder, so the exact threshold is not verified here |
| 6 | The last caption remains visible after captioning stops | **Medium, unmeasured** | Nothing in the code sends an empty `captionText`; whether the downstream encoder clears on stream stop is not asserted by the reference set |
| 7 | `OutputNotRunning` triggers a 10-minute retry loop instead of a distinct state | **High** | `_sendCaption` catches all errors and calls `_scheduleReconnect` |

---

## Recommendations and follow-up

Scoped follow-up, to be tracked against the OBS output target rather than this
spike (no unit is blocked; Spike 2.2's own sequencing note says it "blocks no
unit"):

1. **Shape caption text for CEA-608.** Split long finals into lines within the
   payload limits, and pace successive sends to respect the character-rate
   limit. This belongs with whoever next touches `ObsWebSocketTarget`; it is a
   content-shaping concern shared with the external-display and browser-source
   targets only in spirit, not in code.
2. **Clear on stop.** On captioning stop (and on the last final before
   disconnect), send an empty `captionText` so the last line does not linger.
3. **Distinct `OutputNotRunning` state.** Stop retrying and surface "OBS is not
   streaming" to the UI instead of consuming the 10-minute budget.
4. **Live confirmation in Unit 9.** Unit 9 already owns real-world OBS
   verification; items 1-3 should be validated there against an actual stream,
   which is also where finding 5 and 6 become measurable rather than inferred.

None of these change the API call, which is confirmed correct. They change what
is put in it and how its rejection is interpreted.

### Duplicate implementation worth noting

`ObsWebSocketTarget` (`lib/src/output/obs/`) and `ObsConnectionNotifier`
(`lib/src/providers/obs_connection_notifier.dart`) each maintain their own
connect/retry/send loop against the same package. Both send correctly, so this
is not a Spike 2.2 finding, but a future consolidation should not accidentally
drop the finals-only filter or the password-never-logged rule while removing the
duplication. Recorded so it is not discovered under time pressure later.

---

## Exit criterion 7

> OBS closed-caption behaviour is confirmed by Spike 2.2 (any gap is tracked as a
> follow-up)

**Satisfied.** The API interaction is confirmed from OBS's own source, and the
gaps that remain (text shaping, clearing, streaming-state handling, end-to-end
rendering) are tracked above with owners and a verification stage.

---

## Artifacts

- Reference sources: `spikes/phase2/obs/reference/` (throwaway working copy of
  OBS WebSocket and OBS caption code; not merged into any package, per the
  project's spike convention).
- This report: the durable output.