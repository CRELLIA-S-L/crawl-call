# ADR-0090 — A reload per weapon, costing time, magazines and nerve

- **Status:** accepted
- **Date:** 2026-10-13
- **Related requirements:** FR-BOT-540, FR-BOT-550, FR-BOT-560, FR-BOT-090, FR-BOT-425, FR-BOT-450, FR-BOT-460, IF-BOT-010, FR-SNAKE-090
- **Supersedes:** ADR-0063 in the part that says a reload takes no time of its own; ADR-0086 in the part that says one reload fills everything a bot carries

## Context and problem statement

The second pass of `materials/plans/the-reload-and-the-rush.md` carries out three of the maintainer's six asks of 2026-10-13: reloading the primary should take longer, the number of spare magazines should be limited, and the choice between hiding to reload and drawing something else should depend on the bot's courage. Before it, a reload was instant, filled every firearm at once, and was unlimited — which is why a bot with a dry rifle reloaded rather than drawing anything, and why `fire sidearm` and `throw knife` were chosen zero times in a hundred and fifty seconds (ADR-0088).

## Decisions

**A reload is one action per firearm.** With a time per weapon, one act cannot take two lengths: the primary's two seconds and the pistol's one cannot both belong to a single reload. So the reload takes the shape fire already has — one action per weapon, the action carrying the slot (FR-BOT-540, FR-BOT-460) — and that part of ADR-0086 is superseded. It is also what makes a bot with a dry rifle and a full pistol choose which magazine is worth filling.

**What a reload is worth: `empty × spent² × strength × (1 − courage ÷ 2)`.** The square is as it was — flat while there is a magazine to spend, climbing as it runs out. `strength` is the weapon's damage against the best the bot carries, the same share firing it is scored by (FR-BOT-450): an empty pistol is as empty as an empty rifle and matters half as much, which is what makes a bot with both dry fill the rifle first. This term was added while building, not planned: without it a bot behind cover with a full rifle and an empty pistol filled the pistol rather than coming out to fire, and `SkirmishTests` said so. Courage takes a share and not the whole, so that a bot of whole courage still reloads when there is nothing better to do.

**The courage share is 0.5, and it is a shape and not tuning.** It lives beside the share of health that takes from the wish for cover (`Utility`), because what shapes a term is the formula's and the weight of one term against another is the configuration's (ART-070). Measured at the shipped weights: a bot with a dry rifle and an enemy at a metre strikes with its knife above a courage of about 0.65 and reloads below it, so of the six archetypes the assault (0.7) and the heavy (0.8) close and the sapper (0.5), the scout (0.3), the sniper (0.5) and the medic (0.4) duck away — the split the maintainer described, and `ReloadTests` reads it at 0.7 against 0.3.

**The clock starts when the reload is chosen and runs while nothing else is chosen.** The bot carries which firearm is being filled and the second of the match the filling is due; any other action clears it, and starting again starts from the beginning (FR-BOT-550). Progress kept per weapon and resumed was the alternative, and it was left alone: a bot that can duck out, fire and duck back without losing the reload is a bot for which reloading is free again, which is the thing this pass exists to end.

**The filling happens in the frame that finds the time up, not at a deliberation slot.** Slots come every fifth of a second and by priority, so a reload read at a slot would take two seconds or four depending on the queue. `Execution.fill` runs every frame from `Game.advance`, which is also where the spare magazine is spent.

**It does not hold the bot.** Eating holds the snake in place (FR-SNAKE-090); a reload does not hold a bot, which walks to the cell it reloads in, can be interrupted and loses the reload if it decides on anything else. A bot frozen for two seconds while the snake arrives is the standing still the concept calls the signature stupidity.

**Reload time and spare magazines are the weapon's, in the catalogue.** Both are in each firearm's entry rather than on the archetype, for the reason the damage and the range are there (FR-BOT-450): a pistol filled as slowly as a rifle is a number belonging to the body holding both. Shipped: every primary 2.0 s and three spares, the pistol 1.0 s and two.

**FR-BOT-425 keeps the move and loses the moment.** Its rationale said the magazine is full once the bot is in the hidden cell. The cell is now where the bot waits the time out, and arriving spends nothing — which is the part of ADR-0063 this supersedes. What the requirement asks for, the step behind the cover, is untouched.

## Consequences

**The spare limit bites, and sooner than expected.** The plan reckoned four magazines might never run out on an arena whose match is over in fifty seconds. Measured over a hundred and fifty seconds of the shipped arena with nobody steering: by the thirtieth second four of the five living bots had no spare left for their primary, and by the fortieth all three survivors were out. So a firefight now ends with bots carrying one last magazine, which is what the ask was for.

**The knife and the grenade are chosen far more often.** Over the same measurement: 708 deliberation slots spent striking with a knife and 105 throwing a grenade, where the measurement before this pass counted a single grenade thrown in a whole match (ADR-0087, ADR-0088). The grenade gains because the reload term no longer stands at its full 1.2 over everything else; the knife because courage now pulls the two apart.

**`fire sidearm` is still chosen zero times.** Not because reloading beats it: the bots that run out of primary spares survive into the standstill at the end of the match, where no enemy comes within the pistol's six metres at all. Whether a bot should draw its pistol in a firefight is now a question about the rush (FR-BOT-570), and the standstill is Q-480, Q-490 and Q-620.

**Five tests had their premise rewritten, and it is said rather than hidden.** Four asserted that a magazine is full the moment a reload is chosen, which is the behaviour this pass ends: they now wait out the weapon's own time. Two posed "no reload to be had" through an unroutable cell (FR-BOT-167) and now pose it through a bot with no spare magazines left, which is the real case in a match. One — a bot that comes out again after reloading behind cover — had both its firearms emptied and now has only its rifle dry, because filling the rifle while the pistol is also empty leaves a second reload to choose.

**A bot reloading its pistol is drawn holding the pistol.** The action now names the weapon, so the view can show it (FR-VIEW-340); before this, a reload named nothing and the figure kept its primary in its hands.
