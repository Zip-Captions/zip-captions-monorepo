# NFR Requirements — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: Draft for approval.
**Answers carried**: Q1 A (macOS full registrant, Windows/Linux per-plugin), Q2 A
(`window_manager` in `zip_core` only), Q3 A (router: unit + two-controller + moved suite), Q4 A
(assert the seam; floating is Unit 9), Q5 A (per-app tests), Q6 A (accept the adapter duplication,
constrain by matching tests), Q7 A (inherit Unit 8's numbers + two ordering targets), Q8 A (fail
closed except always-on-top), Q9 A (one redaction audit per app), Q10 A (in-tree shim, POP-1..POP-6
and POP-8), Q11 A (rename/diff checks), Q12 A (label + semantics + visible reason), plus
clarification Q1 A (bootstrap seam for `zip_captions`'s main routing).
**Binding contract**: `pip-ux-parity.md` §8, as amended by the approved Q9 decision (75% width, two
rendered lines, bottom-anchored).

---

## 1. Testability

### 1.1 Strategy per layer

| Layer | Technique | Why this layer is testable |
|---|---|---|
| Promoted controller, codec, geometry, availability, router | Real classes on hand-written fakes (`DesktopWindowService`, `DisplayEnumerator`, `OverlayMethodHandlerInstaller`, `AlwaysOnTopInstaller`) + the in-tree PBT shim | No plugin object is constructed anywhere in the suite (Unit 8's rule, inherited) |
| `OverlayMethodRouter` | Unit tests + a two-real-controller test with one recording installer | The failure mode being guarded (silent misrouting) is only visible with two controllers |
| Both window bodies (`OverlayWindowApp`, `PopOutWindowBody`) | Widget tests with an injected `ValueNotifier` snapshot and injected copy | The widgets take no `BuildContext`-derived settings and no ARB |
| Both apps' toggles, banner, availability rendering | Widget tests inside each app's own `ProviderScope`, one per §8.8 item per app | §8.8's per-app clause is enforced by the test tree, not by memory |
| `AlwaysOnTopInstaller` | A fake installer + the seam assertions in §1.2 | The call's effect is platform-observable only; see Unit 9 |
| Sub-engine entry | `overlayWindowMain` with an injected bridge, pump and installer | The ordering (install before ready) is the contract |
| `zip_captions` main routing | `runZipCaptions(args, runApp:)` in `lib/src/bootstrap.dart` with a recording `runApp` | Makes BR-U8.1-06 literal |
| Runners (native) | Compile only: macOS via `flutter build macos --debug`; Windows/Linux via CI `build-verify.yml` | No toolchain locally for the latter two; stated, not claimed |

### 1.2 Always-on-top: exactly what the suite asserts (Q4 A)

The suite asserts four things and nothing about visible floating:

1. For a `PopOutMode` launch, the installer is awaited **once** and **before** `overlayReady` is
   sent (ordering asserted through a recorder that appends to one list).
2. For an `ExternalDisplayMode` launch, the installer is **never** called (the external display is
   not a floating window).
3. An installer that throws still results in `overlayReady` being sent (a cosmetic failure must not
   block the window).
4. The production installer is not constructed in any test; the test platform's exported
   `alwaysOnTopInstaller` (the `_stub`) is a no-op, and its invocation is a pure no-op `Future`.

Explicitly **not** asserted: that the native window ends up floating. That is §8.8 item 15, a Unit 9
manual check on real desktops, including the Linux "the WM enforces it" caveat and the accepted
macOS `NSFloatingWindowLevel` limitation.

### 1.3 Per-app evidence (Q5 A)

Every claimed §8.8 item that is app-level is tested **in both apps'** test trees:

| Item | Test location |
|---|---|
| 1 chrome toggle exists, both labels, reflects state | `zip_broadcast/test/shell/…`, `zip_captions/test/shell/…` |
| 2 in-surface toggle exists and is usable from the pop-out | both apps (widget test drives the bridge callback) |
| 3 visibility rule, all combinations | both apps, driven by the shared `popOutAvailability` table |
| 5 disabled with reason, no session | both apps |
| 6 disabled with reason, no engine | both apps |
| 7 hint + return, clears on close | both apps |
| 11 opening closes the drawer | both apps (the drawer belongs to each shell) |
| 14 only one pop-out; double toggle | both apps (plus the shared stateful PBT) |
| 18 no caption text in logs | both apps (`<app>_pop_out_redaction_test.dart`) |
| 4, 12, 13, 15, 16, 17 | Unit 9 platform checks, recorded as such |
| 8, 9, 10 | deferred to Phase 8 (translation), recorded as such |

`zip_core` carries the shared behaviour (codec, geometry, availability predicate, router, both window
bodies). It never carries an app-shell test.

### 1.4 Test doubles required

| Double | Package | Shape |
|---|---|---|
`FakeAlwaysOnTopInstaller` | `zip_core/test/helpers/` | records calls into a shared ordering log; can be told to throw |
| `FakeOverlayMethodHandlerInstaller` | `zip_core/test/helpers/` | same shape as Unit 8's proposed helper; records install/uninstall and lets a test invoke the handler |
| `FakePopOutBridge` | `zip_core/test/helpers/` | records `send`/`sendPopOutToggle`, can push a `captionUpdate` |
| overlay generators | `zip_core/test/helpers/overlay_generators.dart` | the FD's noted duplication; adds `arbitraryPopOutGeometryInput`, `arbitraryPopOutModeLaunch` |
| `FakeSttEngineRegistry`-equivalent | each app's existing helper | an empty registry is achieved by not registering; no new double needed |

No `mocktail` mock is required for the new seams; hand-written fakes are the established pattern for
collaborators that carry behaviour (Unit 5/6/7's convention).

---

## 2. Performance

Inherited from Unit 8 and unchanged:

| Target | Value | Source |
|---|---|---|
| Caption delivery cadence | ≤1 `captionUpdate` per 16 ms (`captionUpdateInterval`) | Unit 8 P1 |
| Snapshot payload | ≤ `maxEncodedBytes` (16 KiB UTF-8) | Unit 8 BR-U8-24 |
| Open bound | ≤ `overlayReadyTimeout` (10 s) to `Open` or `Failed` | Unit 8 R3 |
| Display enumeration | ≤1 `getAllDisplays()` per platform event, 0 polls | Unit 8 NFR |
| Window calls | no polling; every call event-driven | Unit 8 R4 |

New to this unit (Q7 A), both stated as ordering targets rather than numbers:

| Target | Meaning | How checked |
|---|---|---|
| Toggle press → `Opening` in the same frame | the shell's toggle does no `await` before `controller.open()`; `open()` sets `Opening` synchronously before its first await | a test that presses the toggle and asserts `status is Opening` immediately after `tester.pump()` with no timer advance |
| Always-on-top applied before the window is shown | the sub-engine awaits the installer before sending `overlayReady`; the main engine only calls `show` after ready | the installer-ordering recorder in §1.2 |

No startup budget is asserted (Q7 A rejected B). A pop-out engine's cold start is bounded in practice
by the ready timeout, which already fails the open rather than hanging.

**Two-line geometry cost**: `popOutSize` is a pure computation over the resolved `TextStyle`; it runs
once per open, not per frame. `PopOutWindowBody` rebuilds only when the snapshot `ValueNotifier`
changes, the same as `OverlayWindowApp`.

---

## 3. Reliability

### 3.1 Failure policy (Q8 A)

| Failure | User-visible result | Retry |
|---|---|---|
| Platform cannot host a window (`Unsupported`) | control not rendered | n/a |
| No engine / no session | control disabled with reason | n/a |
| Handler missing on a capable platform | `create_failed` → `OpenFailed` → banner, flag cleared | next toggle |
| `createWindow` throws | `create_failed` → same | next toggle |
| Ready handshake times out | `ready_timeout` → same | next toggle |
| Window disappears (`'-1'`) | `WindowClosed` → flag cleared, hint gone | n/a |
| `setBounds`/`show` throws non-`'-1'` | logged fixed string, ignored | n/a |
| `window_manager` install fails | **window still opens and works**; fixed-string warning | none (by design) |
| `captionUpdate` decode fails | dropped, last frame stays | next update |
| `popOutToggle` from a stale window | ignored | n/a |

Rule: the only failure that is *not* fatal to the open is the always-on-top call, because a window
that is not on top is still a usable pop-out, while an `OpenFailed` dialog for a working window is
worse. This is a deliberate asymmetry, not an oversight, and is the direct answer to the FD's
"no path leaves a window registered without a state that explains it": the window's state does
explain itself, it just lacks one property.

No retries anywhere. Unit 8's reasoning is inherited: the toggle is the retry, and an automatic
retry loop around a native window call is how orphaned windows happen.

### 3.2 Resource discipline

- Two controllers per main engine, one enumerator shared between both (and with the window service).
  The enumerator opens **one** platform observer; `dispose` is idempotent.
- The router holds at most two handlers and uninstalls the static slot when the last leaves.
- The pop-out sub-engine owns one window and no timers of its own (the controller's timers live in
  the main engine).
- `zip_captions`' shell becomes stateful and must unregister its target and cancel its event
  subscription in `dispose`, exactly as `ZbAppShell` does.

### 3.3 Continuity

BR-PIP-04 is asserted twice per app: the recording state is unchanged across toggle-on and
toggle-off, and the buffer keeps growing while popped out.

---

## 4. Security

### 4.1 Surface

- **Data egress**: none new. `window_manager` opens no socket and has no telemetry (SECURITY-10 §5).
- **Caption content**: crosses only the existing window boundary, inside `captionUpdate` and the
  launch payload, both already size-capped and already redacted from logs. The new `popOutToggle`
  message carries no payload. New log sites carry fixed strings and `runtimeType` only (BR-PIP-11).
- **Input validation on the window boundary**: decode remains total-on-error and size-capped
  (Unit 8 BR-U8-24); the mode token is validated (unknown → `null`, BR-U8.1-08); `popOutToggle` is
  accepted only from the current window id.
- **No new network endpoint, no credential, no token, no key**. No RLS, no server change.
- **Supply chain**: three plugin entries placed per Q2 A; the lockfile fence is in
  `tech-stack-decisions.md`; no new transitive dependency beyond `window_manager`'s own `path`
  (already in the graph) and its existing `screen_retriever: ^0.2.2`.
- **Permissions**: none. Neither plugin requests a platform permission; the macOS app already ships
  the entitlements it needs, and `window_manager` adds no entitlement requirement (no
  `NSWindow`-level capability is gated).
- **Fail-closed**: a platform that cannot host a window shows nothing rather than a dead control;
  a missing handler fails the open. The one non-fail-closed path (always-on-top) is cosmetic and
  cannot expose data.

### 4.2 Security Baseline compliance

| Rule | Status | Reason |
|---|---|---|
| SECURITY-01 Encryption at rest/in transit | N/A | No data store added or touched |
| SECURITY-02 Access logging on network intermediaries | N/A | No intermediary |
| SECURITY-03 Application logging | Compliant | Fixed strings + `runtimeType`, per app audit (§1.3 item 18); no new logger infrastructure |
| SECURITY-04 HTTP security headers | N/A | Web is out of scope (BR-U8.1-11) |
| SECURITY-05 Input validation | Compliant | Codec total-on-error + 16 KiB cap + validated mode token; `popOutToggle` payload-free and window-id-checked |
| SECURITY-06 Least-privilege policies | N/A | No IAM |
| SECURITY-07 Network configuration | N/A | No network config |
| SECURITY-08 Application access control | N/A | No endpoint, no resource access |
| SECURITY-09 Hardening | Compliant | Failure copy generic; no raw `Failed` code shown to the user; no debug/sample surface added |
| SECURITY-10 Supply chain | Compliant | Approved dependency (`window-manager-security-10.md`), placement chosen to avoid unused declarations (Q2 A), lockfile fence named, no unvetted source |
| SECURITY-11 Secure design | Compliant | Separated concerns (machinery in `zip_core`, UI per app), one implementation, fail-closed default |
| SECURITY-12 Authentication | N/A | Untouched |
| SECURITY-13 Integrity | Compliant | Decode is allowlist-based (enum-by-name, known version, known mode token); no unsafe deserialisation |
| SECURITY-14 Alerting/monitoring | N/A | Project-wide deferral already recorded in Backlog |
| SECURITY-15 Exception handling | Compliant | Every platform call caught and mapped; release never throws; no unhandled future in any `unawaited` path (Unit 8 R1/R4 inherited) |

**No blocking security findings.**

### 4.3 Accepted limitations (recorded, not fixed)

| Limitation | Why accepted |
|---|---|
| macOS pop-out does not float above another app's full-screen window | `NSFloatingWindowLevel`; `NSPanel` work in Backlog (accepted 2026-10-20) |
| Linux always-on-top depends on the window manager honouring `gtk_window_set_keep_above` | Platform behaviour, not application-controlled; Unit 9 checks on a real desktop |
| macOS sub-engine receives the app's whole plugin set (Q1 A) | The generated registrant is all-or-nothing; the plugin's own example does the same; the extra channels are never called |

---

## 5. Maintainability

### 5.1 The move must be provably mechanical (Q11 A)

Three checks, recorded in the code summary:

1. `git diff -M --find-renames --summary` on the move commit: every moved file is `R100` except the
   rows of the FD's additive-change table.
2. Every file with a non-rename diff maps to a row in that table; the summary lists the mapping.
3. The greps: `package:desktop_multi_window`, `package:window_manager`, `package:screen_retriever`
   over `packages/*/lib` return exactly the expected `_io` files; no app file matches.

### 5.2 Naming and placement

- The promoted code keeps its class names, file names and logger prefixes become `zip_core.…`.
- One barrel: `zip_core/lib/src/output/overlay/overlay.dart`, exported from `zip_core.dart`. The
  barrel exports the public surface only (controller, modes, codec, snapshot, status, events,
  activity, enumerator, display info, config/position, entry, installers, router, geometry,
  availability, bridges). It does **not** re-export `desktop_multi_window` or `window_manager`.
- `zip_broadcast`'s two model files become one-line `export` shims with a comment naming the
  condition for their deletion.

### 5.3 Documentation hygiene

- No `// ignore` added (project rule).
- The `OverlayWindowUnavailableApp` copy parameter is named `message`, not `l10n`, so `zip_core`
  carries no illusion of a localisation system.
- Every new branch that exists for a mode difference carries a one-line comment naming the mode and
  the rule it serves.

---

## 6. Usability and accessibility (Q12 A)

| Requirement | Implementation |
|---|---|
| Visible label on both toggles | `TextButton.icon` with the ARB label, not an icon-only button |
| Accessible name + state + reason | `Semantics(button: true, enabled: …, label: …, hint: reason)` |
| Reason also visible | adjacent `Text`, so sighted users do not depend on a tooltip |
| Hit target | ≥44x44 logical px in both windows, including the two-line pop-out |
| No colour-only state | icon **and** label change on pop-out; the banner uses text |
| Keyboard | the toggles are `TextButton`s, so they are already tab-reachable and space/enter-activatable |
| Text scaling | the pop-out's height is computed from the scaled line height, so two lines still fit at large accessibility scales; the banner wraps |
| Screen-reader announcement on open/close | **not implemented** (nothing in §8 asks for it); recorded here so it is a decision, not an omission |

---

## 7. Scalability

N/A, restated from Unit 8: no queue, pool, cache or concurrency axis is introduced. At most two
windows per engine, at most two handlers in the router, one enumerator, one 16 ms timer per open
window.

---

## 8. PBT compliance

| Rule | Status | Notes |
|---|---|---|
| PBT-01 Property identification | Compliant | FD `domain-entities.md` §5, POP-1..POP-8 |
| PBT-02 Round-trip | Compliant | POP-1 (launch), POP-6 (mode token); codec's existing snapshot round-trip moves |
| PBT-03 Invariants | Compliant | POP-2 (totality), POP-3 (size bound), POP-4 (geometry), POP-8 (frame conversion) |
| PBT-04 Idempotency | Compliant | router `unregister` no-op, controller `close` idempotence already covered by the moved suite; geometry is a function of inputs only |
| PBT-05 Oracle/model | N/A | No reference implementation exists; `resolveOpenDisplay`'s FP-4 property remains the oracle-free invariant form |
| PBT-06 Stateful | Compliant | POP-5: Unit 8's `_World` harness moves and gains pop-out commands |
| PBT-07 Generator quality | Compliant | domain generators in `overlay_generators.dart` (snapshots with multibyte text, launches by mode, geometry inputs with scale factors 0/1/1.5/2, text scalers, display lists with at most one primary) |
| PBT-08 Shrinking/reproducibility | Compliant with the recorded limit | the in-tree shim uses 100 fixed seeds and **no shrinking** — the project's standing Dart decision (Unit 7 NFR Requirements, re-confirmed by Unit 8). Failure output prints the seed |
| PBT-09 Framework | Compliant | in-tree `test/helpers/pbt.dart`, no new package |
| PBT-10 Complementary | Compliant | POP-7 is an exhaustive example/table test, not generated; every claimed §8.8 item has an example-based test |

**No blocking PBT findings.** PBT-08's no-shrinking limit is pre-existing, project-wide and recorded,
not introduced here.

---

## 9. Deferred and not-claimed register

| Item | Status | Reason |
|---|---|---|
| §8.8 8, 9, 10 | Deferred | Translation is Phase 8 |
| `PopOutContentMode` picker | Deferred | Same |
| §8.8 4, 12, 13, 15, 16, 17 | Unit 9 platform checks | §8.8's own partition |
| Size/position memory | Not implemented | §8.9 "permitted, not required"; Q10 B |
| Web Document PiP | Phase 5 | §8.6 |
| Screen-reader announcement on open | Not implemented | Not required by §8 |