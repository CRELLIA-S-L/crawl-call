# ADR-0013 — Bodies persist for the match; awareness has exactly three sources

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-SCORE-090, FR-SCORE-120, FR-SCORE-125, FR-SCORE-130, INV-SCORE-020

## Context and problem statement

Concept §14 asks whether left bodies decay over time, lifting the evidence (Q-070), and whether a squad could suspect the snake from destruction it did not cause — a possible fourth source of awareness beside a witness, an inspected body and a vanished body (Q-080).

## Considered options

Bodies: persist for the match; decay after a time.
Awareness sources: the three of concept §6.3; those plus unexplained destruction.

## Decision outcome

**Bodies persist.**
A decayed body is indistinguishable, to FR-SCORE-125, from one the snake ate: a squadmate reaching the spot finds nothing and raises the alarm — decay would generate false alarms out of nothing the snake did.
It would also let evidence fade and awareness fall, and FR-SCORE-130's monotonic scale is the simpler model to read and to tune.
The third option the concept wanted from decay — leave the body and go — exists without it: a body left where the enemy finds it blames the enemy; one left where nobody goes is never found.

**Three sources of awareness, not four.**
Most destruction on the map is the squads' own doing (concept §7, the main scenario), so destruction nobody claims is rare and ambiguous.
A squad that grew suspicious from it would be reacting to noise, and the *perfect* stealth level would become unreachable by accident rather than by the player's mistake.

### Consequences

A body is map state until the snake consumes it (INV-SCORE-020); maps accumulate bodies over a match, which is also the visible record of the war.
The awareness machinery stays exactly the three requirements the concept describes.
