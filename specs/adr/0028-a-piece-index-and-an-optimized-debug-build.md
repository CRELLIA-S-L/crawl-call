# ADR-0028 — Sight tests look only at the pieces a line can touch, and the Debug build is optimized

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** FR-BOT-050, FR-BOT-118, FR-VIEW-150, NFR-PERF-010, NFR-PERF-020

## Context and problem statement

On 2026-09-24 the maintainer played the Debug build on the iPhone 16 Pro with the Metal performance HUD and saw the picture freeze about once every one or two seconds once the snake was long and two bots were left.
Measured on the simulator, with the snake laid along the cells around a bot on the blockout's 558 pieces, one bot's deliberation cost 20 ms with a snake of one point and 88 ms with sixty, nearly all of it in the cover search; the see-through check cost 5.6 ms a frame with sixty points and 9.7 ms with a hundred. The frame's budget is 16.6 ms (NFR-PERF-010), and a deliberation's is 0.5 ms (NFR-PERF-020).
Two causes, each measured on its own. Every sight test walked all 558 pieces, rejecting almost all of them by their box; and the Debug build is compiled with `-Onone`, which ran the same arithmetic about twenty times slower than `-O`.
With a long snake the cover search finds no hidden cell and walks every cell in reach — 166 on the blockout — asking about 470 sight tests, so the cost of one test is the cost of the frame.

## Considered options

1. An index of which pieces cover which cells of the ground, built once with the plan, from which a sight test takes only the pieces its line's box can touch.
2. Fewer sight tests: sampling the snake's parts, or searching fewer cells.
3. Leave the Debug build unoptimized and play Release builds.
4. Optimize the Debug build.

## Decision outcome

Options 1 and 4.
Option 2 changes what a bot does — a cell watched by one part the sample left out would be taken for cover — and FR-BOT-118 says what cover is; option 1 changes nothing a bot does, only how fast it learns it.
Option 3 gives up debug mode, which is the Debug build (ADR-0023) and is the build the maintainer plays.
Optimizing Debug keeps `DEBUG` and the free camera, and costs only stepping through code in Xcode's debugger, which this project does not use.

Measured after both, on the simulator: a deliberation next to a snake of one point costs 0.13 ms and of a hundred 0.90 ms; the see-through check 0.01 ms and 0.66 ms. Without the optimization, the index alone brought the deliberation from 20 to 1.9 ms and from 88 to 18.8 ms.
Ordering the snake's parts nearest the bot first in the cover search was tried and changed little — the cost was in cells visited, not in tests per cell — and is kept, since it costs one sort and cannot change an answer.

### How it works

`PieceIndex`, built by `ScenePlan`'s initializer, maps each cell of the navigation grid's size on the x–z plane to the pieces whose footprint touches it, a piece listed in every cell its box spans.
`candidates(low:high:)` returns, once each, the pieces listed in the cells the query box spans; where that box spans more cells than the plan has pieces, it returns every piece.
`Sight.isClear` asks each candidate exactly what it asked each piece before — the box test, then the slab test — so its answer is the answer without the index.
Invariants, held by `PieceIndexTests`: every piece whose footprint touches a box is among its candidates, touching included; and every line between a sample of cells on every floor, at a body's height and at a bot's eyes, is answered through the index as through every piece. Dropping one piece from each cell of the index fails 126 of them.
It stops working where a piece's footprint is not its box — nothing today — and where cells are so small against a line that the query spans more cells than there are pieces, which it answers by falling back to every piece.

### Consequences

A deliberation still exceeds NFR-PERF-020's 0.5 ms next to a long snake, and nothing yet hands out slots by time rather than by count; the requirement stays deferred.
Frame times on the device are the maintainer's HUD until the game's own instrument exists (Q-250).
