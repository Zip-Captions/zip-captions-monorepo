# Functional Design Clarification Questions — Unit 8.1

One answer to the Functional Design questions conflicts with a binding input. Recorded here
rather than resolved by assumption.

---

## Contradiction 1: Q9's window geometry versus UX-PIP-10

**What you answered (Q9):** "I want a 75% width window at the bottom of the screen, tall enough
to render two lines of displayed text."

**What the binding contract says:** `pip-ux-parity.md` §8.3, UX-PIP-10, is explicit:

> **Window defaults** | 640x320, user-resizable | Same default size, resizable, with a sensible
> minimum size.

and `phase2-unit-of-work.md` describes §8 as "the binding user-visible contract", with §8.8
item 13 requiring "The window opens at 640x320 and is resizable". A 75%-width, two-line-tall
window is neither 640x320 nor a "sensible minimum" continuation of it; at 75% of a 1920-wide
display it is 1440x~120, roughly 4.5x wider and a third as tall.

This is a real design change, not an implementation detail, so it cannot be settled inside the
unit. §8.3's row would have to be amended, and §8.8 item 13 restated, before the unit could
claim item 13.

## Clarification Question 1
How should the pop-out window's default geometry be settled?

A) **Amend §8.3 UX-PIP-10 and §8.8 item 13 to the new default** (75% of the active display's
   width, height sized to two rendered caption lines at the current text size, bottom-anchored,
   still resizable with a sensible minimum). The unit then designs and tests against the amended
   contract, and the amendment is recorded as an explicit change to `pip-ux-parity.md` with your
   name and date — the same treatment D-1..D-13 got in the PR #37 review.

B) **Keep UX-PIP-10 exactly as written** for this unit: 640x320 default, user-resizable, sensible
   minimum. Record the 75%-width bottom-anchored idea as a Backlog item for a later UX pass, so
   the unit can claim §8.8 item 13 as-is.

C) **Implement both**: 640x320 per the contract as the shipped default, plus a user-facing
   "wide caption bar" preset (75% width, two lines tall, bottom-anchored) that the user can pick,
   with the preset recorded as an additive extension to §8.3 rather than a replacement.

D) Other (please describe after [Answer]: tag below)

[Answer]: 

---

## Note on Q10's answer (no contradiction, recorded for design)

You chose **B: no persistence at all**. That is compatible with BR-PIP-03 and BR-PIP-10 (which
permits but does not require remembering size/position, and forbids auto-reopening). The unit
will therefore hold popped-out state in memory only: a relaunch starts un-popped, and the
OS-close path needs no settings write. UX-PIP-13/16's "coherent state" requirement is then
satisfied entirely by in-memory state.