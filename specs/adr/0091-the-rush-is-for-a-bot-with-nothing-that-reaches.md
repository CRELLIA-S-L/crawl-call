# ADR-0091 — The rush is for a bot with nothing that reaches

- **Status:** accepted
- **Date:** 2026-10-13
- **Related requirements:** FR-BOT-570, FR-BOT-460, FR-BOT-530, FR-BOT-090, FR-BOT-440, NFR-PERF-020

## Context and problem statement

The third pass of `materials/plans/the-reload-and-the-rush.md` builds the second half of the maintainer's third ask: a bot should be able to draw what it has left and run in, rather than always hiding to reload. The plan's statement obliged a rush for every weapon whose range does not cover its target. What that reads as in the code, and what it costs a frame, were the two questions.

## Decisions

**The rush is offered only where nothing the bot carries reaches the target.** Built as the plan wrote it, the knife — which reaches an arm's length — made every target beyond a metre a reason to run, and bots with loaded rifles charged across the open: twelve tests of the firefight went red in one run, among them both strafing tests and the one that says the primary is what a bot with two loaded firearms fires. The requirement's own rationale already said what was meant — "a bot with a loaded primary is not a candidate, since its weapon reaches already" — so the statement was narrowed to say it, the same day it was written and before anything was called done. A grenade in the pouch counts as something that reaches: its ten metres cover anything a bot can see.

**The cell is the one the rush is worth most from, not the nearest.** The plan asked for the nearest cell from which the weapon reaches. Measured, that cell is always the one at the very edge of the weapon's range, where firing is worth almost nothing: with the pistol's six metres against the assault's six-metre detection range, the nearest cell scores exactly zero and the rush is an action nobody can ever choose. So every cell within the cover search is weighed by what firing from it would be worth, scaled by how near it is, and the best wins — which is the same trade the plan described and a number that is not always zero.

**What it is worth is the firing it is for.** The fire term of that weapon, evaluated at the distance from the cell to the target, scaled by `nearness` of the cell within the cover search distance. Courage is already in the fire term, so a brave bot runs and a timid one does not without a second multiplier (FR-BOT-090). A thrown knife and a grenade are not rushed for: both leave the hand and are gone, and neither is a reason to cross a room.

**One walk for the whole slot, and only where a rush is possible at all.** The cells are walked once and reused for every weapon and every target, and the walk is not made at all unless some target is out of reach of everything (NFR-PERF-020). In the shipped arena that is rare, which is the point: the cost is paid by the bot that has run out, not by every bot in every slot.

## Consequences

**The rush is built, tested and never chosen in the shipped arena.** Over a hundred and fifty seconds with nobody steering, `close` was chosen zero times, and the match is frame-for-frame the one pass B measured: the same five deaths, at 15 s, 20 s, 29 s, 31 s and 40 s.

The reason is the pistol. A bot sees six metres (the assault's detection range) and its pistol reaches six, so everything it sees is within reach of something — and the pistol's magazine is never spent, because `fire sidearm` is still chosen zero times. Over the whole match no bot ever fired its sidearm: with the primary dry, reloading is worth 0.78 against the pistol's 0.16 at four metres, and once the spares are gone, fleeing at about 0.25 beats the pistol too.

So the rush waits on the sidearm being worth firing. The levers are the pistol's `strength` share in the fire term, the `empty` weight, and the detection range against the pistol's range — all tuning, all the maintainer's, and all better judged on the phone than argued here.

**It is the maintainer's to keep or narrow.** The plan said this pass ends at the maintainer's eye, and what there is to look at is nothing: the behaviour cannot be seen in a match until a bot runs its pistol dry. What can be judged is the question behind it — whether a bot with nothing left should run in at all, and whether the pistol should be worth firing before it comes to that.
