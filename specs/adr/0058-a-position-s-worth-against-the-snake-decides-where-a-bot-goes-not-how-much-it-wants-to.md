# ADR-0058 — A position's worth against the snake decides where a bot goes, not how much it wants to

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-BOT-110, FR-BOT-115, FR-BOT-080, FR-BOT-118, FR-BOT-220, IF-BOT-010

## Context and problem statement

FR-BOT-110 and FR-BOT-115 raise a position's score with its height above the snake's head and with the length of the snake's shortest path to it.
A bot scores positions in two actions: taking cover, where the nearest cell the snake cannot see into was taken, and fleeing, where the reachable cell farthest from the danger was.
Both searches stayed on the bot's own floor, so a position above the snake could not be chosen at all.
Four things were open: what "the snake's head" is to a bot that acts on what it knows (FR-BOT-220), how height and path are put on one scale with the rest, whether the raised score is the action's utility or the choice among cells, and how far a bot looks.

## Considered options

1. The worth multiplies the action's utility and ranks the cells.
2. The worth ranks the cells only; the action's utility is what it was.
3. Height and path as separate actions — "go up", "go far".

## Decision outcome

Option 2. Option 1 was built first and run against the suite: with both weights at one, hiding and running came to up to three times what they were, and the squads all but stopped firing — the scenario tests that walk the snake onto a bot, or have the squads finish off a tailless snake, failed, and passed again with the weights at zero.
Option 2 keeps how much a bot wants to hide or run as FR-BOT-080's inputs set it, and makes where it goes the better place.
Option 3 adds actions FR-BOT-200 does not name and a position to them that the two existing actions already have.

### How it works

- The snake's head, to a bot, is the part nearest the head it has seen, where it last saw it; a bot that has seen no part gives every position the worth one.
- A position's worth is one, plus the height weight times its height above that head in floors, taken between nothing and one, plus the snake-path weight times the length of the snake's shortest path to it over the navigation graph, as a share of the bot's detection range, taken between nothing and one. A cell the snake cannot reach counts as the full share. Both weights are in the bot configuration's term weights (IF-BOT-010), one each.
- The path is walked over the whole graph from the head's cell, once a deliberation step for every bot that places the head in the same cell. The graph is the truth rather than what the bot knows, as the routes already are; FR-BOT-220 is `partial` for that reason.
- Cover: every cell the bot knows within the search distance is ranked by nearness times worth before sight is asked about, and the first in that order that nothing watches is taken — the best by construction, with no sight test spent on a worse one.
- Flight: the cell that maximises the ground gained times its worth is taken, where the ground gained is more than the bot has now.
- Both searches walk the graph across floors: a flight of stairs is as much a way to cover as a doorway. The search distance is unchanged, measured across the room from the bot, and the walk does not leave it.

### Consequences

A bot reaches the floor above only where the stairs lie within its search distance; on the blockout that is a bot near the flight, not one anywhere in the room.
A bot hides or runs as often as before and fights as often as before; what changes is that it goes up and away from where the snake can follow, which is what the maintainer sees on the phone.
