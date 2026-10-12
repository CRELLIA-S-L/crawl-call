# ADR-0081 — A bot in cover has no cover to take, and the search says so by answering nothing

- **Status:** accepted
- **Date:** 2026-10-12
- **Related requirements:** FR-BOT-119, FR-BOT-200, FR-BOT-330, FR-BOT-080, FR-BOT-360, FR-BOT-370, FR-BOT-167

## Context and problem statement

The maintainer watched a match and said the squads gather at sight range, stand in two clumps shooting at each other, sometimes stop shooting and look about, and never look like they are trying to win.

Q-600 measured it. On the shipped arena, from its first starting cell, nobody steering: the squads close to about four metres in the first ten seconds and then never move again. Over the second minute the furthest any bot gets from where it stood is 0.00 m, not one bot holds a route for a single frame, and from the eightieth second nobody even fires. The six survivors' scores, read from a situation built the way the deliberation builds it, hold one action each — taking cover in the cell the bot is standing in, at 0.068 to 0.139 — and `Deliberation.quiet` offers each of them an advance it never gets asked for.

The mechanism is two-sided. `Deliberation.cover` walks outwards from the bot's own cell and that cell ranks first by nearness, so the best hidden cell within reach is routinely the one under the bot's feet; the frame then finds the route empty, spends the action and clears it, and the next slot chooses the same thing again. And `Deliberation.choose` consults the quiet motives only where the best scored action is worth nothing at all (ADR-0059), so a cover action worth 0.07 keeps advancing and exploring out of reach for the rest of the match.

A decision was needed because the obvious repair — leave the bot's own cell out of the candidates — is the wrong rule. The maintainer settled it on 2026-10-12: a bot whose position already shields it from what it knows of has no business looking for another wall.

## Considered options

1. The bot's own cell is left out of the candidates, so a bot in cover is sent to the next best hidden cell.
2. A bot the cell it stands in already hides has no cover action at all: the search answers nothing.
3. The cover action keeps naming the bot's own cell and is scored at nothing where the bot is already there.
4. Nothing in the search changes, and the cover action is left to be beaten by scoring the quiet motives beside the rest.

## Decision outcome

Option 2, and it is FR-BOT-119's statement.

Option 1 trades a wall that holds for a wall that holds — the standing still concept §9.2 calls the signature stupidity, dressed as a decision — and it would have a bot shuffling between two hiding places under fire while an order and a closing danger were the things that should move it.

Option 3 keeps an action on the list at a score of zero, which the rest of the deliberation reads as an action available and worthless rather than as no action; FR-BOT-200's own second half says an action with nothing to act on is not on the list at all, so zero would have been the odd one out.

Option 4 is a design of its own and a reversal of ADR-0059, and it does not repair this: a bot would still spend slots choosing a route of no steps, only less often. It stays open as step 5 of `materials/plans/the-firefight.md`, to be decided on what a match looks like now.

### How it works

`Deliberation.cover` asks of the bot's own cell the same question it asks of every candidate — is there a part of the snake with a line to the cell's ground, or an enemy whose eyes, where the bot last saw it, have a line to where the bot's eyes would be standing in it (FR-BOT-330, ADR-0022) — and answers nil where nothing watches it. The question is one local function used in both places, so the two answers cannot drift apart as either side is edited.

One rule covers both halves of the defect. Where the bot's own cell is unwatched there is no cover action at all; where it is watched, the search skips it exactly as it skips any other watched cell, so it can never be the answer. The filter that drops a cell no distance from the bot stays where it is, now redundant.

What still moves a bot out of cover is unchanged: flight is its own action, holding ground falls as a danger closes (FR-BOT-090, ADR-0074), and an ordered zone is scored by the obedience term whatever cover the bot is in (FR-BOT-130). What a bot in cover scores instead is fire, reload, flight, the order, and — where none of them is worth anything — the quiet motives, which is how the squads started moving again.

### Consequences

The standstill is gone and the suite says so from both ends. `IdleTests.testOnceTheSquadsHaveMetSomebodyIsStillGoingSomewhere` reads the second minute of a shipped-arena match and went from 0 frames of walking and 0.0 m of movement to green; three unit tests in `DeliberationTests` pin the rule itself, and removing the rule turns all four red.

A bot in cover with nobody in view now advances rather than standing: the quiet motives are reachable again, because nothing scores. That is the behaviour FR-BOT-360 and FR-BOT-370 describe and it had been unreachable in play since the squads learned to hide.

`Deliberation.cover` is now a question about going somewhere better and not about being somewhere good, and being somewhere good is worth nothing in the scores. Whether a squad looks like it is trying to win is a separate question, and it is now measurable rather than hypothetical.

FR-BOT-167 is still unbuilt, and still needed: an action whose route comes back empty is cleared rather than excluded, and cover is no longer the only thing that can name the cell a bot stands in — `hold` from a commander names exactly it, and flight, flanking and dispersal each compare a cell's centre against the bot's exact position and so can land on it.
