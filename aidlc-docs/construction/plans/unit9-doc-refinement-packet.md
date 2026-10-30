# Unit 9 Documentation Refinement — Group 1 Review Packet

Status: **AWAITING APPROVAL.** Nothing in this packet has been applied. Every
change below is a proposal with a diff, per D8 (grouped approval, one group per
turn, diff per file).

D8 groups: (1) wrong and load-bearing, (2) stale but harmless, (3) contract and
history. This packet is group 1 only.

Each finding states **what is wrong**, **how I know** (evidence, with file and
line), **what breaks if it stays**, and **the proposed change**. Where I am not
confident, the finding says so and asks rather than asserts.

---

## G1-1. `AGENTS.md` mandates git worktrees; the owner has forbidden them

**Wrong.** `AGENTS.md:202-233` requires every unit of work to be developed in a
git worktree, including the workflow steps "Create a worktree for the approved
unit" and "clean up the worktree".

**Evidence.** The owner's standing instruction for this session is "no git
worktrees, one branch at a time". Unit 9 has been built on a single branch
(`feature/phase2-integration-milestones`) in the main checkout, as instructed.
`git worktree list` shows only the main checkout plus a stale
`.claude/worktrees/unit10-fixes` directory from an unrelated earlier session.

**Why this is load-bearing.** This is the file every agent reads first. An agent
that follows it will create a worktree, and the owner will have to undo that.
The instruction has already been contradicted once (this session), so the file
is currently teaching the wrong behaviour.

**Proposed change.** Replace the worktree section with the actual practice:
one branch, one unit, PR opened before starting the next unit. Keep the
motivation (isolation from other in-progress work) and say plainly that a
worktree is one way to get it, not a requirement.

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -199,37 +199,32 @@
-### Git Worktrees
-
-Each unit of work is developed in an isolated git worktree so construction does not interfere with the main workspace or other in-progress units.
-
-```bash
-# After inception approval, create a worktree for the unit:
-git worktree add ../zip-captions-<feature-name> -b feature/<feature-name>
-
-# Work in the worktree — all melos commands work normally there
-cd ../zip-captions-<feature-name>
-
-# After PR is merged, clean up:
-git worktree remove ../zip-captions-<feature-name>
-git branch -d feature/<feature-name>
-
-# List active worktrees:
-git worktree list
-```
+### Branching
+
+One unit of work, one branch, from `develop`:
+
+```bash
+git checkout develop && git pull
+git checkout -b feature/<feature-name>
+```
+
+Work happens in the main checkout. Do not create git worktrees: one branch at
+a time keeps the working tree, the test stack, and the local Supabase volumes
+unambiguous, and a worktree adds a second copy of all three. If a second unit
+must start before the first PR merges, that is a signal to finish the first one
+rather than to parallelise.
+
+Commit only immediately before opening a PR or switching branches. Never push or
+open a PR without asking.
@@ -222,9 +217,9 @@
-3. Create a worktree for the approved unit: `git worktree add ../zip-captions-<name> -b feature/<name>`
-4. In the worktree, run AI-DLC Construction Phase — review and approve the code generation plan (Part 1)
+3. Create a branch for the approved unit: `git checkout -b feature/<name>`
+4. Run AI-DLC Construction Phase — review and approve the code generation plan (Part 1)
@@ -230,4 +225,4 @@
-11. After PR merges, clean up the worktree
+11. After the PR merges, delete the branch
@@ -234,4 +229,4 @@
-- One unit of work per worktree, one worktree per PR — open the PR before starting the next unit
+- One unit of work per branch, one branch per PR — open the PR before starting the next unit
```

---

## G1-2. Web target — WITHDRAWN, not a defect

Recorded here rather than deleted so the packet's history is honest: I drafted a
finding claiming the web target was a doc/reality contradiction. The owner
rejected that framing (2026-10-30T04:12Z): "web is a future target, ADRs will
eventually be fulfilled once full build has been delivered, but that's beyond
the scope of unit 9."

So ADR-001's Fallback column is the *plan*, and the absent `web/` directory is
the expected state at this stage, not an omission. **No change is proposed.**
The only residue is a factual note for group 2 if it is ever useful — "as of
Phase 2 neither package has a `web/` directory" — and even that must not be
written as a gap, a fix, or a backlog item.

What survives as a Unit 9 fact: D6's Chrome leg is browser-to-desktop and needs
no web build. That was already true; it simply no longer reads as a workaround
for something missing.

---

## G1-3. `zip_broadcast` ships `android/` and `ios/` directories it says it must not have

**Wrong.** `packages/zip_broadcast/AGENTS.md:73` says "No iOS or Android build
targets — this app is desktop and web only", and line 80 lists "Add iOS or
Android platform directories or build targets" under **Do Not**. ADR-001:25
says "No mobile build". Both directories exist.

**Evidence.** `ls packages/zip_broadcast` shows `android/` and `ios/`.
`git log --oneline -3 -- packages/zip_broadcast/android packages/zip_broadcast/ios`
shows them present at Phase 0 (`6421daa`, "platform scaffolding and
build-verify") and modified in Phase 1 (`b3be5d2`). They are tracked files, not
local litter.

**Why it matters.** Harmless today - `build-verify.yml` never builds them, so
nothing fails. But they are live, tracked, buildable mobile targets in a package
whose own rules forbid them. The cost is paid by whoever next runs
`flutter build apk` in that package and gets a plausible-looking artefact for a
platform the product does not ship on, or by a future agent that reads a
directory listing instead of AGENTS.md.

**Proposed change.** Two options; I recommend (a) and will not act without a
choice.

- **(a) Delete the directories** (one commit, easily reverted). Removes the
  contradiction. Requires confirming no CI or tooling path touches them -
  `build-verify.yml` does not, which I checked.
- **(b) Keep them and amend the doc** to say mobile targets exist but are not
  built or shipped. Honest, but it reverses an explicit architectural rule to
  describe an accident.

Not acting on either tonight: deleting platform directories is a structural
change, and the owner said no structural surprises.

---

## G1-4. ADR-011's connection-status vocabulary predates the implementation

**Wrong.** ADR-011:703 says "The transport layer must expose connection status
to the UI (P2P connected, TURN relayed, server relayed, BLE, disconnected)".

**Evidence.** The shipped set is `ConnectionType { p2pDirect, turnRelayed,
connecting, disconnected }`
(`packages/zip_core/lib/src/models/connection_status.dart:7-19`). There is no
`serverRelayed` and no `BLE` member. `connecting` is not in ADR-011's list at
all.

**Why this is load-bearing.** Unit 9's D4 work exists precisely because the
implementation previously reported `p2pDirect` without checking. The ADR is the
document a future implementer would consult to decide which states are legal,
and it describes five states that partly do not exist and omits one that does.
Anyone reconciling the two has to guess which is authoritative.

**Proposed change.** Make ADR-011's sentence match the shipped enum, and record
why the omitted states are omitted - they are deferred, not forgotten, and the
reason matters more than the list.

```diff
--- a/docs/02-architecture-decisions.md
+++ b/docs/02-architecture-decisions.md
@@ -700,7 +700,12 @@
-- The transport layer must expose connection status to the UI (P2P connected, TURN relayed, server relayed, BLE, disconnected)
+- The transport layer must expose connection status to the UI. As shipped in
+  Phase 2 this is `ConnectionType { p2pDirect, turnRelayed, connecting,
+  disconnected }` (`connection_status.dart`), with the route determined from the
+  selected ICE candidate pair rather than assumed. Two states named here in
+  earlier drafts — `serverRelayed` and `BLE` — are not implemented: the
+  Supabase Realtime caption relay and the BLE transport are later-phase work
+  (ADR-007, ADR-011 Realtime fallback). Add them to the enum when they exist,
+  not before; a status the UI can render but the transport cannot produce is a
+  lie to the viewer.
```

---

## G1-5. There is no written record of what Phase 2 actually verified

**Wrong.** `aidlc-docs/construction/build-and-test/` holds five files
(`build-and-test-summary.md`, `build-instructions.md`, `e2e-test-instructions.md`,
`integration-test-instructions.md`, `unit-test-instructions.md`). They describe
Phase 1. Nothing in the repository records what Phase 2's integration milestones
proved, what they could not prove, or what was deliberately deferred.

**Evidence.** Unit 9's own findings exist only in
`aidlc-docs/overnight-ledger.md`, which is gitignored (`.gitignore:84`), and in
this session's audit log. Both are working documents. When this branch is
merged, the evidence for "the anonymous viewer claim was proved on macOS + a
browser, and the swarm claim was deferred" goes with them.

**Why this is the single most important item in this group.** Every other
finding here is a doc being wrong. This one is the absence of the doc that
would have prevented the others: EC5, M3, B5, the Coturn log defect, the web
gap, and the version skew all live nowhere that survives the branch.

**Proposed change.** New file
`aidlc-docs/construction/build-and-test/phase2-build-and-test.md`, written
from the ledger, structured as: what was verified (with the command and the
observed result), what was verified by inspection only, what is blocked and on
whom, what was deferred with the reason, and the known defects found but not
fixed. Content is drafted below and needs no further research - it is a
transcription of evidence already gathered tonight.

Sketch (full file to be written on approval):

| Item | Verdict | Evidence |
|---|---|---|
| D2 credentials reachable by anon for a real broadcast | verified | live stack, 200 |
| D2 credentials rejected for unknown/null/lowercase/empty id | verified | live stack, 401 42501 |
| D2 credential is valid TURN REST auth | verified | HMAC recomputed, MATCH |
| D2 Coturn allocates a relay for the credential | verified | `turnutils_uclient`, ALLOCATE success |
| D2 Coturn rejects a tampered credential | verified | `turnutils_uclient`, no allocation |
| D2 broadcaster path unchanged | verified | anon on `get_turn_credentials` still 401 |
| D1 entitlement survives into the signed macOS bundle | verified | `codesign -d --entitlements` on all three built products |
| D1 networking actually works at runtime | **not verified** | needs Track B |
| D4 relay-only switch absent in release | verified by construction | `kDebugMode` guard |
| D4 route detection replaces the hardcoded value | verified | unit tests, 952 passing |
| EC3b TURN fallback observed in a real app | **not verified** | needs Track B |
| EC5 "other viewers unaffected" | **deferred** | D5: no real-protocol swarm |
| M3 swarm of 50 | **deferred** | D5 |
| B5 Google OAuth | **blocked on credentials** | provider disabled, placeholders only |
| Anonymous viewer claim (M-S3.6 clause 1, desktop) | **not verified** | needs Track B |
| Anonymous viewer claim (phone form) | out of scope | D6 -> Unit 13, gap G6 |
| CI workflows green on this branch | **not run** | no push, per instruction |

---

## G1-6. Pop-out geometry was amended in `aidlc-state.md` but never applied to `pip-ux-parity.md`

**Wrong.** This is not the drawer item I first suspected — I checked, and item
11 ("Opening the pop-out closes the drawer") is consistent; I have no evidence
the drawer behaviour is wrong, so it is dropped from this packet.

The real finding is the Q9 amendment. `aidlc-docs/aidlc-state.md:188` records,
in the owner's own approved wording, that Q9 **amended the binding contract**:
"the pop-out opens at 75% of the active display's work-area width, two
rendered caption lines plus the toggle row tall, bottom-anchored, min 320x96,
decorated and resizable — amending `pip-ux-parity.md` UX-PIP-10 and §8.8 item
13, **to be applied to that file at Documentation Refinement with the owner's
name and date**." `aidlc-state.md:199` repeats that it "was not changed by the
merge."

**Evidence.** `aidlc-docs/construction/output-targets/functional-design/pip-ux-parity.md:54`
still reads "640x320, user-resizable", and line 183 still reads "The window
opens at 640x320 and is resizable." The amendment exists only as prose in the
state file. So the binding UX contract still states the geometry the owner
explicitly overrode on 2026-10-21.

**Why this is group 1, and why the amendment wins (re-verified from primary
sources 2026-10-30T05:05Z, not from state-file summaries).** The ordering is not
inferred:

1. `plans/pop-out-functional-design-clarification-questions.md` framed the
   geometry as a conflict that "cannot be settled inside the unit", and offered
   Amendment A: "Amend §8.3 UX-PIP-10 and §8.8 item 13 to the new default".
   The owner chose A.
2. `audit.md:2653` records it verbatim: "the owner chose Amendment A, explicitly
   amending `pip-ux-parity.md` §8.3 UX-PIP-10 and §8.8 item 13 to 75%-width /
   two-rendered-lines / bottom-anchored, resizable, minimum 320x96, decorated."
3. `audit.md:2661`, at the Functional Design **approval gate**, lists the
   amendment ordering among three points "accepted by the approval without
   amendment".
4. `pop-out/functional-design/domain-entities.md:91` and `:218-223` specify
   `widthFraction 0.75`, `visibleLines 2`, `minWidth 320`, `minHeight 96`, and
   that shape is in shipped code.

So the owner approved *changing the contract*; applying it completes that
decision. And the implementation already matches the amended numbers, which
means 640x320 now describes a window the application does not open. Any future
verification run against the unamended `pip-ux-parity.md` would fail a correct
implementation.

**Proposed change.** Apply the amendment as recorded, crediting the owner and
the decision date, without inventing any detail beyond what `aidlc-state.md`
and the audit entry (`aidlc-docs/audit.md:2652-2653`) already state.

```diff
--- a/aidlc-docs/construction/output-targets/functional-design/pip-ux-parity.md
+++ b/aidlc-docs/construction/output-targets/functional-design/pip-ux-parity.md
@@ -51,7 +51,7 @@
-| UX-PIP-10 | Window defaults | 640x320, user-resizable | Same default size, resizable, with a sensible minimum size. |
+| UX-PIP-10 | Window defaults | 640x320, user-resizable | 75% of the active display's work-area width, two rendered caption lines plus the toggle row tall, bottom-anchored, minimum 320x96, decorated and resizable. Amended by the project owner 2026-10-21 (Q9); the 640x320 values were v1's and are superseded. |
@@ -181,7 +181,7 @@
-13. The window opens at 640x320 and is resizable.
+13. The window opens at 75% of the active display's work-area width, two
+    rendered caption lines plus the toggle row tall, anchored to the bottom of
+    the work area, at least 320x96, decorated, and resizable. (Amended by the
+    project owner 2026-10-21, Q9 — see `aidlc-state.md` Unit 8.1.)
+
+The 640x320 default above was v1's. The 2026-10-21 owner decision supersedes it
+so the pop-out matches the app's own caption surface; this table records v1
+parity, and this row is a recorded, owner-approved divergence from it.
```

Note the asymmetry this creates and whether you want it permitted: UX-PIP-10
is a parity claim against v1, and this amendment deliberately breaks parity on
geometry. Group 3 should record that as a documented, owner-approved departure
rather than leaving a reader to wonder why the "parity" table no longer
matches v1.

---

## G1-6b. Viewer design docs still name the session-scoped credential call that D2 replaced

**Wrong.** Two viewer design artifacts say the viewer obtains ICE servers from
`iceServerProviderProvider.iceServersFor(sessionId)` — the session-scoped,
authenticated path.

- `aidlc-docs/construction/zip-captions-viewer/functional-design/domain-entities.md:214`
- `aidlc-docs/construction/zip-captions-viewer/functional-design/business-logic-model.md:73`

Both add "the same anonymous-accessible TURN-credential path the broadcaster
uses (Unit 4)". That sentence was already false before Unit 9: the Unit 4
function guards on `auth.uid()` and is not anonymous-accessible (measured this
session: anon gets `401 42501`).

**Evidence.** `packages/zip_core/lib/src/services/webrtc/ice_server_provider.dart`
now has two methods: `iceServersFor(String sessionId)` for the broadcaster and
`iceServersForBroadcast(String broadcastId)` for the anonymous viewer, the
latter added by D2. `ViewerSessionNotifier` calls
`iceServersForBroadcast(id.value)`.

**Why this is group 1.** A reader implementing or verifying the viewer from
these docs calls the wrong method and gets an authenticated-only path that an
anonymous viewer cannot use - i.e. exactly the bug D2 was written to fix. Left
alone, the design docs would reintroduce it.

**Proposed change.** Point both at the broadcast-scoped call and stop claiming
the broadcaster's path is anonymous-accessible.

```diff
--- a/aidlc-docs/construction/zip-captions-viewer/functional-design/domain-entities.md
+++ b/aidlc-docs/construction/zip-captions-viewer/functional-design/domain-entities.md
@@ -211,8 +211,11 @@
-`ViewerTransportContext` it receives is built by the notifier from the
-resolved `sessionId`/`broadcastId`, `signalingServiceProvider`, and
-`iceServerProviderProvider.iceServersFor(sessionId)` — the same
-anonymous-accessible TURN-credential path the broadcaster uses (Unit 4).
+`ViewerTransportContext` it receives is built by the notifier from the
+resolved `sessionId`/`broadcastId`, `signalingServiceProvider`, and
+`iceServerProviderProvider.iceServersForBroadcast(broadcastId)`. The
+broadcaster's `iceServersFor(sessionId)` path is **not** available to a
+viewer: `get_turn_credentials()` guards on `auth.uid()` and is reachable only
+by an authenticated caller. Unit 9 (B2) added the broadcast-scoped variant
+precisely so an anonymous viewer could obtain relay credentials at all.
```

```diff
--- a/aidlc-docs/construction/zip-captions-viewer/functional-design/business-logic-model.md
+++ b/aidlc-docs/construction/zip-captions-viewer/functional-design/business-logic-model.md
@@ -70,8 +70,8 @@
    watch, Q5): state -> `ConnectingState`; build
    `ViewerTransportContext(sessionId, broadcastId, signalingService,
    iceServers: await ref.read(iceServerProviderProvider)
-   .iceServersFor(sessionId))`; `await transport.connect(context)`.
+   .iceServersForBroadcast(broadcastId))`; `await transport.connect(context)`.
    `connect()` returns after the handshake is *dispatched*; the outcome
    arrives on the `status` stream (step 6). A thrown exception from
```

---

## G1-7. Two smaller wrong statements found while checking the above

These are group 1 by consequence, not by size.

**(a) `docs/04-technical-specification.md` §9 says nothing about a service-role
surface.** The section documents that every table has RLS, that RLS has no
exceptions, and that channel naming is fixed. It does not mention that the
Supabase image's `public`-schema default ACL grants EXECUTE to `anon` on every
newly created function, which is the single most surprising fact discovered in
Unit 9 - a `REVOKE` does not survive a redeploy, so the guard has to be in the
function body. That belongs in §9 next to the RLS rule, because the next person
to add an RPC will otherwise assume grants are a real control.

```diff
--- a/docs/04-technical-specification.md
+++ b/docs/04-technical-specification.md
@@ -360,6 +360,12 @@
 - Migrations in `packages/zip_supabase/migrations/`, numbered sequentially
 - Migrations are forward-only — no editing existing migrations, create new ones to alter
+
+### Function Grants
+
+This image's `public` schema carries a default ACL granting EXECUTE to `anon`,
+`authenticated`, and `service_role` on every newly created function, and it
+re-applies on `CREATE OR REPLACE`. A `REVOKE` therefore does not survive a
+redeploy. Authorization for any `SECURITY DEFINER` function must be enforced
+in the function body (existence checks, `auth.uid()` guards, `RAISE ... USING
+ERRCODE = '42501'`), and the grant should be documented as defence in depth
+rather than treated as the control. Neither `get_turn_credentials()` nor
+`get_broadcast_turn_credentials()` relies on its grant.
```

**(b) `implementation`:** `aidlc-docs/construction/ci-pipeline/infrastructure-design/infrastructure-design.md:123`
documents a `test:coverage` melos script that does not exist in `melos.yaml`.
CI calls `melos run test:coverage --no-select`; melos does not find a script and
falls back to running the name as a raw command through `melos exec`, which
happens to work. The doc is wrong about the mechanism, and the workflow is
relying on undocumented fallback behaviour that a future melos release could
make into a hard error.

Approved as option 2: fix both halves, and stop the doc from holding a second
copy of the melos config.

**Code change** (the real fix; this is the one item in this packet that is not
docs-only):

```diff
--- a/melos.yaml
+++ b/melos.yaml
@@ -12,6 +12,12 @@
   test:
     run: melos exec --fail-fast -- flutter test
     description: Run all tests across packages that have a test directory
     packageFilters:
       dirExists: test
+
+  test:coverage:
+    run: melos exec --fail-fast -- flutter test --coverage
+    description: Run all tests with coverage collection (used by CI)
+    packageFilters:
+      dirExists: test
 
   analyze:
     run: melos exec --fail-fast -- dart analyze --fatal-infos
```

The `packageFilters` block is the point. The doc's version omitted it, so
copying that doc verbatim would have quietly changed which packages CI tests.
`test:coverage` must match `test` exactly, or the two commands disagree about
what the suite is.

**Doc change** (approved option 2: describe the commands, do not mirror the
YAML):

```diff
--- a/aidlc-docs/construction/ci-pipeline/infrastructure-design/infrastructure-design.md
+++ b/aidlc-docs/construction/ci-pipeline/infrastructure-design/infrastructure-design.md
@@ -110,26 +110,27 @@
-## Melos Test Scripts
-
-Defined under the `melos:` key in the root `pubspec.yaml` (Melos 7.x convention):
-
-```yaml
-test:
-  run: melos exec --fail-fast -- flutter test
-  description: Run all tests across packages that have a test directory
-  packageFilters:
-    dirExists: test
-
-test:coverage:
-  run: melos exec --fail-fast -- flutter test --coverage
-  description: Run all tests with coverage collection (used by CI)
-```
-
-CI uses `melos run test:coverage --no-select` (the `--no-select` flag prevents interactive package selection prompts).
+## Test Commands
+
+CI runs these two commands, in this order, from the repository root:
+
+```bash
+melos run analyze
+melos run test:coverage --no-select
+```
+
+Both are defined in `melos.yaml`; that file is the single source of truth for
+what they do, and this document deliberately does not reproduce its contents —
+an earlier revision did, and drifted: it showed a `test:coverage` script that
+had never been defined, so CI was relying on `melos run` failing to find the
+script and falling back to executing the name as a raw command through
+`melos exec`. That fallback worked, but it was undocumented behaviour, not a
+contract. The script now exists and the workflow is unchanged.
+
+Both scripts filter on `dirExists: test`, so a package without a `test/`
+directory is skipped rather than failing the run. Keep any new test script's
+filter identical to `test`'s, or the two will disagree about what the suite is.
+
+The `--no-select` flag prevents interactive package selection prompts.
```

Note that the melos scripts live under `melos.yaml` in this repository, not
under the `melos:` key in the root `pubspec.yaml` as the old text claimed — a
second, smaller error in the same paragraph, corrected by the rewrite.


---

## Not in this packet

- Group 2 (stale but harmless) and group 3 (contract and history) - not
  drafted, per D8's one-group-per-turn rule.
- Anything that changes code. G1-3(a) and G1-6 may turn into code changes; both
  need a decision first.
- The `aidlc-docs/construction/build-and-test/phase2-build-and-test.md` file
  itself - drafted as a table above, will be written in full on approval.

## Corrections made to this packet before publishing it

Recorded so the packet is not trusted more than it deserves:

- I first wrote G1-6 as "the docs say the pop-out closes drawer, the code hides
  the control", sourced from a misremembered line in
  `zip-captions-viewer/.../domain-entities.md:215`. On reading the actual
  files, item 11 of `pip-ux-parity.md` is consistent and I have no evidence of
  a drawer defect. G1-6 was rewritten as the real finding: the Q9 geometry
  amendment was approved and never applied to the contract file.
- G1-6b was added after checking the viewer design docs, which still name the
  session-scoped credential call D2 replaced.
- Every other finding was re-checked against the file it cites. Two of my
  earlier ledger notes were also wrong and are corrected there (the
  `test:coverage` script does *not* error, it falls back; and the web target is
  intended in ADR-001, the *shell* is missing).

## Approval status (all eight decided, 2026-10-30T05:18Z)

Nothing has been applied. This is the decision record; application is a
separate, reviewable step.

| Item | Decision | What it means |
|---|---|---|
| G1-1 | **approved, option 1** | `AGENTS.md`: worktree mandate -> branch mandate, isolation rationale kept |
| G1-2 | **withdrawn** | web is a deferred target, out of Unit 9 scope; no change |
| G1-3 | **approved, option 1** | delete `packages/zip_broadcast/{android,ios}` (59 tracked files) |
| G1-4 | **approved, option 1** | ADR-011 -> shipped `ConnectionType` enum + why two states are absent |
| G1-5 | **approved, option 1** | write `phase2-build-and-test.md` in full, including "not verified" |
| G1-6 | **approved, option 1** | apply the Q9 geometry amendment, with provenance |
| G1-6b | **approved, option 1** | fix both call sites, delete the false claim; plus two side-references found while applying |
| G1-7(a) | **approved, option 1** | tech spec Section 9 gains a "Function Grants" rule |
| G1-7(b) | **approved, option 2** | add `test:coverage` to `melos.yaml` + rewrite the CI doc section |

**APPLIED (all eight, 2026-10-30T06:05Z).** G1-2 withdrawn, the other seven
applied. Gates re-run after applying: `melos run analyze` no issues in all
four packages; `melos run test:coverage --no-select` now resolves the real
script (not the fallback) and passes 952+5 / 195 / 195 with `lcov.info`
produced for each. Two extra `iceServersFor()` references were found while
applying G1-6b (`business-logic-model.md:83`, `business-rules.md:65`) and
corrected with it.

Two carried-forward questions, neither assumed:

1. **G1-6 subsidiary:** should the deliberate v1 parity break be noted inside
   the G1-6 diff (done in the rendered diff, pending confirmation) or deferred
   to group 3?
2. **G1-6b options** (re-presented below) need an answer.

Everything else is ready to apply as a single documentation commit, with the
G1-3 deletion isolated into its own commit so it is trivially reviewable and
revertable, and the G1-7(b) `melos.yaml` change isolated because it is the only
non-docs change in the packet.

---

## G1-6b, re-presented (options unchanged)

1. **Correct both call sites and delete the false claim (recommended).** Point
   `domain-entities.md:214` and `business-logic-model.md:73` at
   `iceServersForBroadcast(broadcastId)`, and replace "the same
   anonymous-accessible TURN-credential path the broadcaster uses" with a
   statement that the broadcaster's path is authenticated-only and D2 added the
   broadcast-scoped variant because of that.
2. **Correct only the method name.** Minimal, but leaves the false explanation
   standing for the next reader.
3. **Correct the call sites and record that the original claim was wrong**, so
   the design history shows it was checked rather than silently edited.
4. **Leave it; treat the code as truth.** Accept that these read as current
   design but are historical.
