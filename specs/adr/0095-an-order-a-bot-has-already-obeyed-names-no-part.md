# ADR-0095 — An order a bot has already obeyed names no part

- **Status:** accepted
- **Date:** 2026-10-14
- **Related requirements:** FR-BOT-660, FR-BOT-116, FR-BOT-360, FR-BOT-370, FR-CMD-030, FR-CMD-040, FR-BOT-130, CON-CMD-020, FR-TOOL-170

## Context and problem statement

The maintainer looked at the phone and said the bots had bunched up at opposite ends of the map, were walking back and forth over a couple of cells, and were not interacting at all.

Two screenshots twenty-five seconds apart show it: the red squad outside the arena's north-east corner, the blue squad outside its south wall, the snake alone in the room between them, and almost nothing moved in between. The frame record of a fresh two-minute run on the phone says what the squads were standing under: twenty-one commander calls, twenty of them answered, one refused — so both squads held a standing order for the whole run — and in a hundred and twenty-two seconds no meal began and the match did not end. What the record cannot say is whether the bots were shooting at each other: its `hit` counts rounds that struck the snake and nothing else.

What the model was answering is not visible from outside the app, so the cause was reproduced in the simulator instead, with no model anywhere: a commander that answers every call with "press the part your crew is standing in", which is what any sensible reader of `rivals: not seen` says. On the shipped arena, a hundred and fifty seconds, nobody steering:

| | no commander | ordered onto its own ground |
|---|---|---|
| a squad wiped out | 39.9 s | never |
| the match ends | 48.9 s, the treasure carried off | never |
| shots fired | 3660 | **0** |
| bots alive at the end | 4 of 8 | 8 of 8 |
| nearest a red bot came to a blue one | 0.52 m | 2.68 m |
| ground covered from where each began | 6.4 to 15.4 m | 0.4 to 12.3 m, four of the eight under 2 m |

The squads are pinned twice over by the same word. The ordered move scores `obedience × discipline × holding` every slot, which is always above nothing, so a bot under an order never has nothing to do and the motive that would send it at the enemy (FR-BOT-360) is never reached — ADR-0059 consults the quiet motives only when nothing scores. And an order that names the enemy's part (`press`, `flank`) replaces what a bot with no sighting believes about where the enemy is (FR-BOT-116, FR-CMD-040): told to press into the ground it is standing on, a bot believes the enemy is underfoot.

## Decision

**While a bot stands in the part of the arena its squad's order names, the order names no part** (FR-BOT-660). The squad is still under the order — the threat it was given still ranks what it fires at (FR-CMD-030), and a bot that leaves the named part is drawn back to it — but there is no place to score positions against and no place to believe the enemy is.

One rule for both mechanisms, because both read the same field and neither has anything to read once it is empty. It is per bot and not per squad: a squad spread over two parts has some of its bots obeying and some of them free, which is what being spread out means.

Which part a bot stands in is `Places.part(of:in:)`, computed from the words `SquadView.place` puts in front of the model (IF-CMD-010), so the game and the commander mean the same thing by "north-east" by construction rather than by agreement.

After it, the same two runs:

| | no commander | ordered onto its own ground |
|---|---|---|
| a squad wiped out | 39.9 s | 54.6 s |
| the match ends | 48.9 s | 72.7 s |
| shots fired | 3660 | 4334 |

An ordered squad is still slower than one nobody commands — seventy-three seconds against forty-nine — and that is obedience rather than a stall: while a bot is outside the part it was pointed at, it goes there first.

## What this is not

**Not a change to what the model is asked or told.** The prompt is the one thing a bench measurement covers, and changing its rendering voids the reading (FR-TOOL-170). The model goes on being free to answer badly; CON-CMD-020 is the standing obligation that the game survives whatever comes back, and this is one more way of surviving it. That the model keeps pointing squads at their own ground is a question of its own.

**Not a change to FR-BOT-116.** An order that names a part the squad is not in works exactly as it did, which is what the second test of the pair holds.

**Not a reversal of ADR-0059.** The quiet motives are still consulted only when nothing scores; what changed is that an order already obeyed stops scoring.

## On the phone

Installed and watched for seventy-five seconds, the same arena with the same model answering: nineteen calls, eighteen answered, and at the end of it the red squad is inside the room, spread over the crates and the stairs, with one of them carrying the treasure — which it can only do while it believes no enemy is left (FR-BOT-620) — and the blue squad is down outside the south wall. The two runs are the same build, the same map and the same commander; what changed between them is this rule.

## Consequences

A match under a commander ends. The cost is one condition in `Execution.deliberate` and one function in `Places`. The risk it adds is a bot on the boundary of two parts flipping between obeying and not — the parts are quarters of the arena measured from its middle, so a bot standing on a boundary line is in one of them and the reading is stable while it stands still, but nothing stops it stepping across. Nothing in the measurements shows it; if it ever matters, the answer is the same margin FR-BOT-140 uses for targets.
