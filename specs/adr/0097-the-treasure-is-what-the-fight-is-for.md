# ADR-0097 — The treasure is what the fight is for

- **Status:** accepted
- **Date:** 2026-10-14
- **Related requirements:** FR-BOT-620, FR-BOT-630, FR-BOT-640, FR-SCORE-160, FR-BOT-116, FR-BOT-220, IF-BOT-010

## Context and problem statement

The maintainer watched a match on the phone in which the red squad had wiped the blue one out, stood under `hold west side`, and never went near the treasure. Three rules composed into it: the prize was offered only to a bot that believed the enemy gone; believing that needed both every sighting spent and a walk to the enemy's starting area (FR-BOT-250); and a standing order kept the squad from ever taking that walk. Nothing was broken — FR-BOT-620's own rationale described exactly this condition, and it came from concept §6.4, under which the treasure cannot be taken while an enemy lives.

The maintainer then set the rule the game is to follow: the treasure is what a squad is there for, it goes for it whatever else is happening, a firefight included, and the enemy squad — and the snake, once a squad knows of it — is what stands between the squad and the prize, which is why they are fought.

## Decisions

**The gate is gone from both places that held it.** FR-BOT-620 offers the treasure to every bot while nobody carries it, and FR-BOT-630 makes whoever stands in its cell the carrier. The two had to move together: the deliberation and the picking up must not disagree. `Knowledge.believesEnemyGone` was read by nothing afterwards and went with them.

**The prize decays with distance, as every other motive does.** Taking it was the one action on the list scored flat: `weight × courage`, the same at two metres and at forty, where a target is scored within the bot's sight and an ordered part within the arena's span (FR-BOT-116). A flat term beats every decaying one from the first frame, and the measurement said so — with the gate gone and the term flat, the shipped arena was a footrace: the treasure taken at 3.15 s, the match over at 8.48 s, nobody hurt, 944 frames of anybody firing. It is now scaled by nearness to the box within the arena's span. Carrying stays flat: a bot holding the prize has no better job, and that flatness is what stopped the carrier flickering between carrying and fleeing when the second act was built (ADR-0094).

**The arena's span is the arena's, not the order's.** It was written into a bot's situation only where its squad stood under a command, which was enough while the ordered part was the only thing measured against it. The treasure's nearness is measured against it too, so a match with no commander needs it as much.

**The weight is 1.0, down from 2.0**, settled by measurement over the shipped arena with nobody steering and no commander, one run a point:

| treasure weight | the prize taken | the match over | bots down | frames with somebody firing |
|---|---|---|---|---|
| 2.0 | 3.15 s | 8.48 s | 0 | 944 |
| 1.0 | 3.15 s | 37.53 s | 1 | 3379 |
| 0.5 | 5.78 s | 13.58 s | 0 | 1836 |

It is not a straight line, and the middle is the match the rule was asked for: the box is grabbed in the first seconds and the next half-minute is spent trying to stop the carrier getting out with it. One deterministic run a point is one sample a point, not a distribution; the phone is what judges it.

## Consequences

Three end-to-end fixtures stopped proving what they were written for, because a match now ends long before a snake gets a meal or a squad loses anybody: the meal in the frame record, the bodies coming back after a restart, and the war under orders that already obey themselves. Each is given an arena with no treasure in it (`withoutTreasure` in the tests' own support), which is the smallest change that keeps each measuring what it measures.

**The specification and the concept now disagree on purpose.** §6.4 says the treasure cannot be taken while any enemy is alive; FR-BOT-620 says the opposite, on the maintainer's word of 2026-10-14. The concept is the document to amend, and that is the maintainer's to make.

**Not built, and named so it is not forgotten:** nothing yet makes a squad protect its carrier, and nothing makes the enemy fire at the carrier first. Both follow from "the other squad is what stands in the way", and neither is written as a requirement yet.
