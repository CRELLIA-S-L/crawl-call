# ADR-0043 — A bot looks at every cell round it once a deliberation period, and its squad passes on the whole record

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-BOT-050, FR-BOT-220, FR-BOT-230, FR-BOT-240, FR-BOT-250, FR-BOT-260, FR-BOT-310, FR-BOT-150

## Context and problem statement

ADR-0032 settled what a bot knows and that its squad hears it after a delay, and left open how the record is filled and passed on. On 2026-09-25 the maintainer asked for the whole of it to be built in one piece, leaving the floods, the lines-of-fire table and movement by order, which ADR-0032 has put to them requirement by requirement, for later.
Five things had to be chosen: which point of a cell a bot looks at, how often it looks, how the snake's parts are told apart, how a squad passes a record on, and what a bot fires at when it remembers the snake but does not see it.

## Considered options

For the map:

1. One sight test per cell within the range, to a point on the cell's near side just off its ground, once a deliberation period.
2. Shadowcasting over the grid, floor by floor.
3. The same sight test every frame.

For the squad:

1. The whole record of every other bot of the squad, filtered by the delay, merged once a deliberation period.
2. A queue of facts per bot, each delivered when its delay runs out.

## Decision outcome

Option 1 for the map, and option 1 for the squad.
The map's sight is the snake's (FR-BOT-050), as ADR-0032 requires, so that a bot cannot know a cell it could not have seen; shadowcasting answers a different question — whether the cell's middle is visible over a flat grid — and would need its own rule for heights, which the game's sight test (ADR-0019, ADR-0022) already has. It is left as the optimisation ADR-0032 names, to be chosen by measurement.
The squad's merge keeps no second structure: a sighting carries when it was made, and a mate takes every sighting at least the delay old, so the queue is the record itself.

### How it works

**Looking at the map.** Once a deliberation period (FR-BOT-150) a bot looks at every cell of every floor within its detection range that holds a module or can be stood in. For each it takes the cell's centre at the height of its ground, moves it towards the bot by 0.55 of a cell — onto the near side of the cell, just past its edge — and lifts it 0.05 m off the ground; a wall is thus seen by its face and a floor by its near edge, where a line to the centre would cross the module standing in the cell itself. The cell is recorded with the module that stands in it, or with nothing, and when.
Every bot looks in the match's first frame; from then on the bots take turns spread evenly across the period, since all of them looking in one frame measured 2.4 ms a step at the 99th percentile on the iPhone, five times a second, against 0.05 ms before.

**The snake's parts** are told apart by their place from the head: part 0 is the head. A part seen again replaces its earlier sighting; parts not seen keep theirs, so a bot's picture of the snake can be pieced together from several moments.

**Firing** needs the snake in view now: a sighting made this frame. What is remembered is somewhere to be afraid of and to hide from, not a target.

**The start.** The building's outline is every cell with a module in it and every cell that can be stood on; the ways between floors are the cells of the flights of stairs, which a bot knows as it knows a cell it has seen; the enemy's start is the circle round the other squad's spawn cells, one cell wider than the farthest of them.

**The squad.** Once a deliberation period each bot takes from every other bot of its squad each sighting made at least the squad's delay ago, a later sighting of the same thing — the same part of the snake, the same enemy, the same cell — winning over an earlier one. What a mate heard is passed on with the time it was first seen, so a report does not grow older each time it is passed on.

**Forgetting** runs every frame, after the looking and the sharing, with the times of the configuration; a time of nothing forgets nothing.

### Consequences

A report arrives between the delay and the delay plus one deliberation period after it was seen, 0.2 s with the shipped numbers: accepted, since the delay itself is a second.
The map's looking costs one sight test for each cell within the range on every floor, for every bot, five times a second; with the shipped range of 6 m that is at most 625 cells a floor, and the frame record (FR-TOOL-230) is what says whether that is too much.
Routes are still found over the true map, and cover is still tested against the obstacles as they are: a bot chooses among the cells it knows, but its way there and its judgement of a cell as cover are not yet limited to what it knows (FR-BOT-220).
Enemy sightings are recorded and shared, and nothing reads them yet: no action of FR-BOT-200 is aimed at an enemy bot.
