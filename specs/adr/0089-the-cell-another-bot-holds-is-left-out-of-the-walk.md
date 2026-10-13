# ADR-0089 — The cell another bot holds is left out of the walk

- **Status:** accepted
- **Date:** 2026-10-13
- **Related requirements:** FR-BOT-530, FR-BOT-220, FR-BOT-300, FR-BOT-420, FR-BOT-425, FR-BOT-116, FR-BOT-118, FR-BOT-119, FR-BOT-360, FR-BOT-370

## Context and problem statement

The first pass of `materials/plans/the-reload-and-the-rush.md` builds FR-BOT-530: a bot does not set out for a cell another bot holds or is making for. The rule already existed in one place — `Deliberation.post` left out the cells its squadmates had taken as their firing post and their refuge — and the other four cell searches had nothing of the kind. Where the exclusion should live, and what exactly holds a cell, were the two questions.

## Decisions

**The exclusion lives in the walk, not in each search.** Four of the five searches — cover, the post beside it, the order's place, flight — take their candidates from `Deliberation.walk`, so the cells it does not give are cells none of them can choose. The alternative was a filter repeated at each call site, which is four places to forget it in and four places for the two sets to drift apart. The walk still goes *through* an excluded cell: another bot standing in it is not a wall, and a route that crosses it is as good as any (FR-BOT-300, ADR-0064). The two quiet motives choose over the whole graph rather than over the walk — an advance by `nearestCell`, a look by `unseen` — so they ask for the set themselves.

**A claim is read off the squadmate's last decision.** `Execution.destination(of:)` is already the one answer in the game to "where is this bot's action sending it", and the set is that over the living squadmates, together with the post it fires from and the refuge it steps back to: a bot holding a post holds the pair, which is what `post` claimed before this and what SkirmishTests still reads. Nothing was moved between files — the two parts are one element (E-090) and the function is pure.

**What holds a cell, and what does not.** A squadmate standing in one, a squadmate making for one, an enemy *in view* standing in one. Not an enemy remembered and not seen: the memory is of a place it was, and a bot acts on what it knows (FR-BOT-220). Not where an enemy is going: that is told to its own squad and to nobody else. Not a body: nothing in the game treats one as an obstacle, and only the living are pushed apart (FR-BOT-320). Not the cell the bot itself stands in, nor the one it is itself making for.

**A test that reads a match had to change what it reads.** `CommandedMatchTests` compared where red stood at the fortieth second with and without an order to press east. Since the arms were built a firefight is decided inside half a minute, and the squad that presses east is now wiped out around the twentieth second, so at the fortieth there is no position to read — the test failed on an arena where nothing is wrong. It now compares where the squad was *over the match it lived*: the mean of red's centre over the frames in which red had anybody standing, which is defined whether the squad survives or not and still says what FR-BOT-116 claims. Measured: 14.20 m told against 12.12 m silent, where the arena's east is at 19.5 m.

## Consequences

**Fights resolve faster.** The shipped arena, red under an order to press east: red was down to one bot at the fifteenth second and gone by the twentieth, against one bot left standing for the rest of the match before this pass. Bots that no longer pile into one cell spread out, and a spread-out squad in the open is shot at from more directions at once. Nothing was asked about this, and it is a change in the match the maintainer's eye is the judge of.

**The exclusion can leave a bot with nothing.** Where every cell within reach is held, the action is not on the list at all, which is how every action with nothing to act on behaves. In a corridor the width of one cell this is a bot that stands while its squadmate moves, and that is the intended reading of the maintainer's "and not try to get into them".

**One test guards the wiring rather than the rule.** `CellClaimTests.testEveryBotStillChoosesAndNoTwoOfASquadSetOutForOneCell` passes with the exclusion removed: two bots standing apart are sent to two different cells by flight alone. It is kept as a guard that every bot is still given something to do — a filter one cell too wide would show there as a bot with nothing chosen — and it is said in the file that it is not a test of FR-BOT-530. The nine tests that do go red when the set is emptied are the cell searches above it.
