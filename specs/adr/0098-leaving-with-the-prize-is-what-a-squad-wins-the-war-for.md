# ADR-0098 — Leaving with the prize is what a squad wins the war for

- **Status:** accepted
- **Date:** 2026-10-14
- **Related requirements:** FR-SCORE-160, FR-BOT-620, FR-BOT-630, FR-BOT-640, FR-BOT-650, FR-BOT-670, FR-BOT-680, FR-BOT-220

## Context and problem statement

ADR-0097 put the prize at the centre of the fight: every bot is offered it from the first second, its carrier has no hand for a weapon and walks at a third of its speed. What was still missing is the maintainer's own words — the other squad has to be removed — because carrying the box to a cell was enough to end the match whoever was still standing. On the shipped arena with the heavy prize the box was picked up at 3.15 s and the first carrier was shot off it, but a lone survivor could still have walked it out past four living enemies.

## Decision

**A squad leaves with the prize only once the other crew is gone.** The carrier that reaches the evacuation point stands there with the treasure in its arms; the match ends in the frame the last bot of the other squad falls. FR-SCORE-160 says it as a state rather than a moment, which is what lets the carrier arrive early and wait.

**Measured against the arena and not against what anybody believes.** The end of a match is the game's own fact, where what a bot does is decided by what it knows (FR-BOT-220). A carrier may be sure it has won and still be standing on the point; nothing about its knowledge is consulted.

**The carrier's motive is untouched.** FR-BOT-640 sends it to the point exactly as before. It was tempting to keep it away until the arena was clear — then it would never stand exposed — but a carrier waiting on the point with its hands full is a target the other squad can reach, and that is the fight this is for. If it dies there the prize lies on the evacuation point itself for whoever comes next (FR-BOT-650).

## Consequences

The three ends of a match are unchanged in number, and the third is now the hardest: the snake dying (FR-SCORE-140), nothing left alive (FR-SCORE-150), and a squad leaving with the prize having cleared the arena of the other crew.

**Nothing on screen says why.** A player watching a carrier stand on the evacuation point while the match runs on has no way to know what it is waiting for. That is an interface question and is not built; the match-end plate (FR-VIEW-190) already names which end it was, and what is missing is the state before it.

**A stalemate is now possible in principle:** both squads reduced to a carrier that cannot shoot and an enemy that cannot find it. The shipped arena has no such case in any measurement so far, and the snake is what breaks one in practice.
