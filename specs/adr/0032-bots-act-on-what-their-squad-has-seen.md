# ADR-0032 — A bot acts on what it and its squad have seen, and moves by floods over the map it knows

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-BOT-050, FR-BOT-080, FR-BOT-118, FR-BOT-200, FR-SCORE-090, FR-SCORE-130, FR-CMD-070, IF-CMD-010, NFR-PERF-020

## Context and problem statement

A bot that has once seen the snake is handed the true position of every part of it at every deliberation from then on: `Execution.deliberate` passes the whole body to any bot whose `knowsSnake` is set, and nothing ever clears it (FR-BOT-050). Cover is then a cell no part of the snake can see into, measured from where the snake really is (FR-BOT-118).
On 2026-09-25 the maintainer ruled that a bot's movement must not rest on what the snake sees — a bot is not the snake and cannot know it — and asked for movement built from a few behaviours, each computed from the bot's own sight: staying put or firing, fleeing, taking cover, and moving where the commander orders.
They settled what a bot knows the same day: the map roughly at the start — the shape of the ground, the large buildings, and roughly where the enemy squad is — and the rest as it sees it, remembered once seen; what it sees shared with its squad after a delay; changes — destruction, the enemy's and the snake's movements — learnt, remembered and shared the same way. The arena is small today and will not stay so: the algorithms are to be chosen for larger maps from the start.
The research behind the choices below, with a source for every claim and a mark on each that was not read at first hand, is `materials/research/bot-movement.md`.

## Considered options

For what a bot knows:

1. The truth, as now.
2. What the bot itself has seen, and nothing else.
3. What the bot has seen, shared with its squad at once, as The Last of Us did (McIntosh, *Game AI Pro 2*, ch. 34).
4. What the bot has seen, and what its squad has seen after a delay.

For how a bot finds where to go:

1. A search per question — A*, or Jump Point Search on a uniform grid (Rabin and Silva, *Game AI Pro 2*, ch. 14).
2. Floods: one breadth-first or bucket-queue Dijkstra search from a source gives the distance to every cell, and many questions read the same flood (Patel, *Flow Field Pathfinding*, Red Blob Games).
3. Local steering alone, towards the goal inside what the bot sees.

## Decision outcome

Option 4 for knowledge, and floods for movement.
The truth is what the maintainer ruled out; the bot's own sight alone leaves a squad that cannot warn itself, which the concept's squads exist to do; and sharing at once makes every bot of a squad as knowing as the first to see, where a delay keeps a witness's report worth something (FR-SCORE-090).
Floods, because every behaviour asks for distances to many cells at once, which is what a flood answers and a point-to-point search does not; A* and Jump Point Search answer one pair, and the latter also needs uniform costs, which a danger term breaks. Local steering alone stalls in any dead end the bot cannot see out of — the local minima of potential fields and the depressions of real-time search (`materials/research/bot-movement.md`, section E) — so it is kept for the last step between cells, if at all.

### How it works

**What a bot knows.** Each bot keeps a record of what it has perceived:

- the map, cell by cell — unknown, or seen, with the state it was in and when;
- the snake — the cells its parts were seen on, when, and which way the head was going;
- the enemy — each enemy bot seen, where and when.

At the start a bot knows the building's outline, its floors and the ways between them — a flight of stairs since ADR-0033 — not what stands inside them, and a rough area for the enemy squad's start (FR-BOT-250). Every perception tick adds what the bot sees, and a later sighting replaces an earlier one of the same thing. Nothing is forgotten; each kind of sighting of the snake and of the enemy carries a time after which it may be forgotten, off unless the configuration sets it.

**What a squad knows.** A fact a bot perceives reaches the rest of its squad after the squad's delay, one number per squad in configuration. A bot acts on its own record and what has reached it. A collapsed squad (squad collapse, glossary) shares nothing more; bots that meet in person may exchange what they know in a later version. The commander is told the squad's record, never the truth (IF-CMD-010); the awareness state (FR-SCORE-130) and what it hides from the commander (FR-CMD-070) are read from the same record.

**What a bot sees.** A cell is seen when the game's own sight test (ADR-0019) finds a clear line from the bot's eyes to it within its detection range: the same rule by which it notices the snake (FR-BOT-050), so that a bot cannot know a cell it could not have seen. The test runs over the cells within the range, spread over frames, so its cost grows with the range and not with the map; a faster exact method, such as shadowcasting over the grid, is an optimisation to be chosen by measurement.

**Floods over the known map.** The navigation graph is stored as arrays indexed by cell, with a fixed neighbour list, rather than dictionaries and sets, and one flood is the primitive every behaviour uses. A flood runs over the map as the squad knows it; a cell nobody has seen counts as passable until somebody sees otherwise, and a route through it is replanned then (the free-space assumption). A flood bounded to a bot's range costs what the range holds, however large the map; a whole-map flood runs only per order and per squad, at the commander's 0.1–0.2 Hz. When a map grows until those are too costly, the growth path is hierarchy — floods over rooms joined by their doors, refined inside a room (Botea, Müller and Schaeffer, HPA*, 2004) — to be taken when a measurement shows the need, not before.

**Staying put or firing.** No search.

**Fleeing.** Three floods, all within what the bot knows: from the bot, bounded to its range; from every snake cell it remembers; and the escape term of the roguelike "flee map" — the danger distances multiplied by about −1.2 and flooded again, which draws a fleeing bot to exits rather than into corners and, when it is cornered, past the danger (*The Incredible Power of Dijkstra Maps*, RogueBasin). A cell the snake reaches before the bot is not a candidate, nor is a route through one. Of the rest, the bot takes the best by the escape term and follows the flood back to it.

**Taking cover.** At load, a lines-of-fire table records for every cell and each of 16 sectors around it the farthest an attacker in that sector can fire at it from, built once with the game's sight test (Beij and Straatman, *Killzone's AI*, GDC Europe 2005); a cell is covered from a remembered snake cell when that cell lies farther away than the table allows, which is one comparison and no sight test. The search follows the tactical point pipeline (Jack, *Game AI Pro*, ch. 26): candidates are cells the bot knows within its range; cheap filters first — covered from every remembered part of the snake, not claimed by another bot, reached before the snake — then weights, nearer to the bot and farther from the danger; and flight when nothing passes, the failure told to the squad. The table is built from the map as it is, so a cell a bot knows is rated with the obstacles beside it even where the bot has not seen them: an approximation accepted because what makes a cell cover stands next to it, where a bot that has seen the cell has most likely seen it too. Destruction (FR-MAP-030) rebuilds the entries around what it changed.

**Moving by order.** For each order the squad floods from the ordered zone over the map it knows. Each tick a bot takes, among the cells within its range, the one with the fewest steps from it plus steps to the zone, plus a weight on the danger it remembers, and walks there: moving step by step in what it sees, as the maintainer asked, but never into a dead end, because the distance to the zone is exact over what is known. An order is a goal weighed against the bot's others, and fear can outweigh it (Orkin, *Three States and a Plan*, GDC 2006); a zone nobody can reach is told back to the commander.

**Choosing among them** stays the utility of FR-BOT-080, as the maintainer confirmed on 2026-09-25: a bot chooses by what comes in — an enemy or the snake in what it knows, the commander's order, how great the danger is, the health it has left, its own courage, and what it has to fight with — each read from its record, never from the truth. These four are how the actions of FR-BOT-200 find where to go, not a new chooser. The maintainer named a motive for later, idle curiosity, so that a bot with nothing happening around it does not simply stand still.

### Consequences

A bot can be surprised: it flees from where it last saw the snake, not from where the snake is, and a squad learns a flank only after a witness's report has had time to arrive.
The deliberation reads a record instead of the truth, so FR-BOT-050 stops being a latch, and FR-BOT-118's cover stops being "a cell the snake cannot see into"; both requirements change, and new ones describe the record, the sharing and each behaviour — written one at a time and put to the maintainer before they are approved.
The graph moves to arrays before anything else, and the frame record (FR-TOOL-230) measures the result against NFR-PERF-020 before and after.
The costs in the research are estimates, not measurements, and for 768 cells; at a larger map the bounded floods and the per-order flood are what keep the cost tied to a bot's range and to the commander's rate rather than to the map.
