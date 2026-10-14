# ADR-0094 — The second act is two motives, a belief that can be wrong, and a prize the map puts down

- **Status:** accepted
- **Date:** 2026-10-14
- **Related requirements:** FR-MAP-290, FR-MAP-300, FR-BOT-620, FR-BOT-630, FR-BOT-640, FR-BOT-650, FR-SCORE-160, FR-SCORE-170, FR-VIEW-370, FR-MAP-180, FR-BOT-200, FR-BOT-220, FR-BOT-250, FR-BOT-360, FR-SCORE-150, FR-VIEW-190, IF-MAP-010, IF-BOT-010, IF-SCORE-010

## Context and problem statement

A match that one squad had won ended in nothing. Measured on 2026-10-13 on the shipped arena, nobody steering: after the fortieth second four survivors spent a hundred and ten seconds between three points a metre apart, running at full speed the whole time. The slot-by-slot reading (Q-620) found the mechanism — a calm squad's snake flickers in and out of the situation at five metres — and the maintainer named the real fault: that is not a defect in the behaviour, it is the place where the game has no goal. Concept 0.12 §6.4 gives it one.

What that section asks for is a prize that cannot be touched while the war is on, a squad that goes for it when it believes it has won and may be wrong, one carrier whose death drops it on the spot, an evacuation point that ends the match, and a score that is not rewritten but multiplied. Nine requirements were authored from it; this records how they were built and what was deliberately left out.

## Decisions

**The two cells are the map's, and the configuration has no say.** `treasure <x>,<z> <floor>` and `evacuation <x>,<z> <floor>` join the header (IF-MAP-010, FR-MAP-290), and a map to be played that names neither, or names a cell nothing can stand in, is refused at launch beside the spawn points (FR-MAP-300, FR-MAP-190). Concept §11 says why: the length of the second act is the distance between the two cells and the snake's chance of getting back is where it is born with respect to the treasure — three numbers a map is designed around, and a number in `config/` would tune every map at once.

**Where the snake is born needed nothing new.** §6.4 asks for a snake born near the treasure and not on it, and FR-MAP-180 already puts it at a spawn point the map names. So "near" is the map author's doing, checked on the shipped arena rather than enforced by a rule: its three spawn points lie 4.5, 6.5 and 6.6 metres from the treasure, in an arena 16 metres across. Building a refusal around a distance would have been a number in the configuration deciding what §11 says the map decides, and a requirement nobody wrote (ART-040).

**The belief is read off the knowledge a bot already keeps.** `Knowledge.believesEnemyGone` is `enemies.isEmpty && enemyStart == nil` — no sighting it has not been to, and the enemy's starting area already swept (FR-BOT-240, FR-BOT-250, FR-BOT-360). That is the same reading that leaves a bot with nothing to advance on, which is what makes it the right one: the bot that has run out of enemies to look for is exactly the bot that thinks the war is over. Three other ways were available and all three are worse: a count of the enemy squad is knowledge no bot is given; a flag raised when the last enemy dies reads the arena and not the squad, which is what §6.4 forbids in as many words; and a message from the commander would make the second act wait on a model that may not be there (FR-CMD-120).

Being wrong is a property of this and not an allowance on top of it. A squad that never found the last survivor believes it has won and goes for the treasure; one that lost its commander and fell apart may never learn that it did win. Nothing had to be built for either.

**Two actions in the scored list, not a mode.** `Action.takeTreasure` and `Action.carryTreasure` are scored beside firing, fleeing, cover and an order, by the same formula and the same weights (FR-BOT-620, FR-BOT-640, concept §9.2). One new term weight, `treasure` in `utilityTermWeights` (IF-BOT-010), times the bot's courage for taking it and its discipline for carrying it: a frightened bot does not pick it up first and a disciplined one carries it under fire, while the fear terms go on being weighed against both. An evacuation mode would have taken a bot out of the game it was playing, and the first thing it would have had to grow back is fear.

**The weight is 2.0, and the number is what makes the second act finish.** At 1.0 it does not. Measured on the shipped arena, nobody steering: a squad was gone at 39.9 seconds, bot 3 took the treasure at 43.6, and then carried it nowhere for the remaining two hundred and fifty seconds. The carrier's slots alternated without exception — `carryTreasure` with a route of 28 cells, then `flee` with a route of 6, then `carryTreasure` again — and over a hundred and fifty seconds it moved from 7.21 m from the way out to 8.88 m. Carrying scored `1.0 × discipline` and fleeing `threat × closeness × fear × panic`, which at five metres from a snake is about the same number, so the choice turned on whether the snake was in the situation that slot — and for a calm squad it enters and leaves at five metres (Q-620). At 2.0 the same run ends with the treasure carried off seconds after it was picked up: 48.9 seconds, with the treasure in the cell it now stands in. What the number buys is the sentence §9.2 already asked for: a disciplined bot carries it under fire. An undisciplined one still does not.

**Picking it up is the match's rule and not a decision.** A bot that may take the treasure and stands in its cell has taken it, whatever it came there to do (FR-BOT-630) — the same condition as the one that lets it want the treasure at all, so that the deliberation and the match cannot disagree about who may carry it.

**The rule is a value function, and the match only hands it the bots.** `Treasure.step(among:cell:cellOf:held:)` is the whole of the second act's bookkeeping: the carrier that has fallen drops it, a bot standing on it takes it, a carrier on the evacuation point has carried it off. It sits in `Sources/CrawlCall/Bot/` with the squads, because the deliberation reads the treasure and the match only moves it; what the match adds is which cell a bot stands in. The alternative was the fourth private routine in `Game`, which would have left every one of these behaviours reachable only through a ten-thousand-frame match.

**Three states, and a point rather than a cell.** `lying(at:floor:)`, `carried(by:)`, `carriedOff`. The treasure falls where its carrier fell (FR-BOT-650) and that is rarely the middle of a cell, so the lying state holds a point; which cell that is, is computed where it is needed. `held` — where the carrier stood as the frame began — is kept by the match because a bot the snake finishes eating is gone from `bots` before the frame ends, and the treasure still has to fall where that bot was.

**Every bot knows where the treasure is.** FR-BOT-220 binds what a bot reads of the snake, the enemy and the map to its own knowledge; the treasure is none of the three, and both squads came to the arena for it. So the cell is common knowledge from the first second, and no bot has to discover it. The alternative — the treasure as something a bot must see — would mean a squad that has won the war wandering until somebody walked past the prize.

**The third end of a match is an outcome and a line on the plate.** `Game.Outcome.treasureTaken` (FR-SCORE-160), and FR-VIEW-190's plate now names which of the ends it was rather than which of the two, with `matchEnd.treasureTaken` in the string catalog. FR-SCORE-150 keeps its own reading: a wiped-out squad still does not end a match, and now it hands the other squad a treasure to carry off — which is the trap §6.4 names, since the snake eating the last of a losing squad is one of the ways that squad can be gone.

**The treasure is drawn as its own thing.** One box at the point it lies at or in the hands of its carrier (FR-VIEW-370), made once and moved, as the grenades are (FR-VIEW-350). A mark on the floor would have been cheaper and wrong: the thing moves, and the one bot worth eating out of a winning squad is whoever is holding it.

Two things about it were settled on the phone on 2026-10-14 and neither could have been settled anywhere else. Gold was the first colour and it is the kit's crate colour — an orange box among orange boxes — so it is violet, which nothing the kit or the setting draws is. And the cell the map named was the middle of the room, where the flight of stairs stood between it and the camera: the first run on the phone showed no treasure at all, and a box blown up to 1.2 m to find out showed one edge over a step. The treasure moved to the open north-east of the room, which is a map's business (FR-MAP-290) and cost nothing but two numbers in the header.

## What was deliberately not built

**The multiplier.** FR-SCORE-170 is `deferred` with the score it multiplies: there is no score in the game yet (FR-SCORE-010 and its three axes are the layer under it), and a multiplier over a number nobody computes is not worth building first. `IF-SCORE-010` names the number so that the day the score arrives, the multiplier is already asked for.

**A carrier that gives up the job.** §9.2 says a bot of low self-sacrifice abandons the carrier's position. §6.4 names only one way the treasure changes hands — the carrier falls — and no requirement says the other, so nothing was built for it (ART-040). A carrier that flees, flees carrying it.

**The interrupt.** §9.2 adds "the squad believed no enemies remain" to the list of events that grant a bot a slot at once. Nothing was built: a bot gets a slot within a deliberation period anyway (FR-BOT-150), so the whole of what the interrupt buys is a fifth of a second at the start of the second act, and FR-BOT-170 is `partial` for its own reasons (Q-660).

**Hysteresis on the calm squad's five metres.** Q-620's narrow answer, and the measurement above is the reason it is still not built rather than the reason it is. The flicker is real and it reached the carrier: what settled it was a weight that makes carrying the treasure worth more than being afraid, which is a sentence the concept already carried. The boundary itself is untouched, so whatever else it does, it goes on doing; it is no longer in the way of a match ending, and it is a question of its own.

## Consequences

A won match ends. Measured on the shipped arena with nobody steering: a squad gone at 39.9 seconds, the treasure taken at 43.6, the match over at 47.3 — where the same arena ran to the end of a five-minute reading with four bots pacing between three points a metre apart. On the one-a-side room the fixture plays the same shape: a squad gone at 14.3 seconds, the treasure taken at 22.5, the match over at 24.2.

The cost is one term weight, one enumeration case, two actions, four map-layer messages and a value function of forty lines; nothing in the first act moved, which is what FR-BOT-620's condition is for. A map now has two more ways to be refused, and both fixtures and the shipped arena name the two cells.

What the snake gains is a reason to come back: the prey it did not eat while the squads fought is now walking in a line towards one cell, and the carrier is the one worth eating. What it loses by ignoring all that is a multiplier the day FR-SCORE-170 is built.
