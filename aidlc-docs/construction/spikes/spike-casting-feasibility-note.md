# Spike Note: Casting to Remote Display Devices

**Date**: 2026-10-19
**Status**: COMPLETE. Constraint recorded. No spike code; documentation research only.
**Scope**: Feasibility of casting captions from Zip Captions or Zip Broadcast to a remote, cast-enabled display (for example a Google TV device or Chromecast). Sender direction only; receiver functionality is explicitly out of scope.
**Context**: Recorded while Unit 8 is blocked on the merge of the Unit 7 PR. This note exists so that casting feature requests are answered from a recorded constraint rather than re-investigated each time.

---

## Executive Summary

**Casting captions to a remote cast-enabled display is not feasible in Phase 2 and requires new architecture, not a package addition.**

Three independent constraints each block it:

1. **Platform gap.** The Google Cast Sender SDK supports Android, iOS, and web senders only. It does not support macOS, Windows, or Linux. Zip Broadcast is desktop-only (macOS, Windows, Linux, web). The two mobile platforms that Cast supports are not targets of either app in the current scope.
2. **Payload mismatch.** The Cast Sender API loads a *media URL plus MIME type* (`CastSession.loadMedia(LoadRequest(MediaInfo(contentId, contentType)))`). Captions are live generated text, not a media stream with an addressable URL. There is no field in the Sender API for pushing a rendered window or an arbitrary live text stream.
3. **Receiver requirement.** Casting arbitrary live content needs a registered Web Receiver to render it, hosted and reachable, with the caption data delivered to it over a second network path (custom channel messages or `customData`). That is new server infrastructure and a new realtime data path, and it is receiver-side work even though the motivation is sender-side.

Miracast has no Flutter package and is not part of the Cast SDK at all; it is OS-level screen mirroring with no application-level API surface usable here.

**The supported path for the auditorium and external-display use case remains the local one**: the broadcaster attaches the overlay window to a display that the operating system already sees — a projector, a TV, or a display that the user has already mirrored to with the OS's own casting feature. `screen_retriever` enumerates those displays and reports when they are attached or removed. The application never speaks a casting protocol; the OS and the user's existing tooling handle transport.

---

## Findings

### Google Cast Sender: what is available

From the indexed `google-cast`, `google-cast-web-sender`, and `google-cast-web-sender-api` documentation:

| Capability | API |
|---|---|
| Device discovery and cast button | `CastContext.getInstance().setOptions({receiverApplicationId, autoJoinPolicy})` |
| Start or join a session | `requestSession` / `requestSessionById` |
| Load content | `CastSession.loadMedia(LoadRequest(MediaInfo(contentId, contentType)))` |
| Playback control | `RemotePlayer` / `RemotePlayerController` (play, pause, stop, seek, volume) |
| Status events | `RemotePlayerEventType` change callbacks |
| Ancillary data | `customData` field on several message types |

Sender platforms supported: **Android, iOS, Web**. Sender platforms listed as unsupported: macOS, Windows, Linux.

What the Sender API cannot do: cast a screen, cast a window, or stream arbitrary rendered content. The content model is a URL that the receiver device fetches independently. Chrome's own tab-casting and the OS-level Cast/Miracast screen-mirroring features are not part of the Cast Sender SDK and are not callable from an application.

### Google Cast Receiver: what it would take

The documentation describes an end-to-end scenario requiring a registered Web Receiver, and a Default Media Receiver scenario limited to "learning and very limited playback scenarios" that is "not practical for receivers that require custom business logic." Captions require the former:

- A hosted receiver page that renders caption text
- Registration with Google
- A custom namespace for caption delivery, or `customData` piggybacked on media messages
- A network path from the broadcaster's device to that receiver page, independent of the caption bus

### Miracast

No Flutter package exists. The capability is exposed at the OS level (`MiracastReceiver` via WinRT on Windows, `wpa_supplicant` and related networking on Linux) and generally is not available to sandboxed applications. It is a screen-mirroring feature, not an application output target.

### Media stream alternative

The one technically coherent version of "cast our captions" is: generate an HLS or DASH stream on the broadcaster's device or on the local network, embed the captions in it, and load that stream's URL with the Default Media Receiver. This is not a library addition. It requires a media segmenter, a local HTTP server, caption multiplexing, and stream lifecycle management, and the result would be a Cast-compatible video stream of a caption overlay rather than a caption output target. This is a separate product feature, not an implementation detail of the existing overlay target.

---

## Consequences

- Casting must not be described as a small follow-up to the existing multi-output work. It is a distinct feature with a platform prerequisite (a supported sender platform), an infrastructure prerequisite (a hosted receiver and a second delivery path), or a media pipeline prerequisite (an HLS/DASH segmenter).
- Requests for "cast to the TV" in a venue should be answered with the local-display path: attach the overlay to a display the OS already sees, or mirror to the venue device using its own tooling, then select that display as the overlay target.
- The web broadcaster build is the only current target that overlaps a supported Cast Sender platform. Any future casting work would most plausibly start there, and would still require the receiver infrastructure.
- No dependency is added. No approved-dependency-list change results from this note.

---

## Recommendations

1. **Record the local-display path as the supported answer.** Unit 8's display enumeration via `screen_retriever` (approved for the dependency list on 2026-10-19) is the mechanism by which a broadcaster targets a venue display. It works when the display is already visible to the OS, which includes the case where the user mirrored to a TV with the OS's own casting feature.
2. **Do not schedule casting into Phase 2.** It has no overlap with the Phase 2 deliverables and no dependency is met.
3. **If casting becomes a requirement, scope it as its own feature with its own spike.** The spike should choose between (a) a web-sender-plus-hosted-receiver design for the web broadcaster and (b) an HLS/DASH caption stream design. Both need an infrastructure decision before any code.
4. **Keep the constraint visible to future requirement-gathering.** This note is the reference for casting requests. Re-investigate only if the Cast Sender SDK adds desktop sender support, or if a maintained Flutter Cast sender package appears that covers the target platforms.

---

## Artifacts

- This note: the only durable output. No spike code, no harness, no branch.