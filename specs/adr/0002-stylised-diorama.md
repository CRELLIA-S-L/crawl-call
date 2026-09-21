# ADR-0002 — A stylised diorama, not military realism

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-VIEW-060, FR-VIEW-070, FR-VIEW-090, FR-VIEW-100, FR-VIEW-110, CON-MAP-010

## Context and problem statement

A giant snake eating soldiers has to land as something.
The visual style decides whether that is body horror or comedy, whether a solo production can sustain it, and whether a military map invites comparison with a specific shooter.

## Considered options

1. Military realism.
2. Stylised shooters — Overwatch, TF2, Diablo 2 — the early references.
3. A cosy diorama with physical comedy — Overcooked, Moving Out, Two Point Museum.

## Decision outcome

Option 3, on three independent lines at once.
Tone: in realism the premise is body horror and drags the game dark; in stylisation it is comedy, and the panicking bot lines become the heart of the game instead of an oddity.
Production: realism is judged on "how close to real", which a solo project always loses; stylisation is judged on internal consistency, which one person can hold, and reads under a top-down camera on a phone.
Legal: a realistic military map inevitably evokes a specific shooter; a stylised one has nothing to be compared with, and style itself is not protected.
Option 2 was dropped as an inaccurate reference set.

### Consequences

The style must not eat tactical honesty: cover has to look like cover, sight lines read at once, height read from above — form is loose, space is exact.
Squad affiliation and the wounded and stragglers need their own readability rules (FR-VIEW-060, FR-VIEW-080).
Visuals are assembled by script from rounded primitives (concept §2.1, FR-TOOL-130); close-ups — menus, portraits, a trailer — will probably need separately modelled characters.
The interface follows the same aesthetic rather than a military HUD.
