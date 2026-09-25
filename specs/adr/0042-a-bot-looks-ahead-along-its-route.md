# ADR-0042 — A bot cuts its route short by looking ahead along it, every frame

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-BOT-270, FR-MAP-020, FR-MAP-025, FR-BOT-165, INV-BOT-010

## Context and problem statement

FR-BOT-270 has a bot walk straight wherever its body can, instead of from cell to cell. ADR-0016 had said as much — "paths are smoothed by string-pulling over cell corners" — and the code walked every route cell by cell (`Execution.advance`, `Route.between`).
A route is found once, when a bot has none (FR-BOT-165, at most one a frame); it is walked every frame (INV-BOT-010). ADR-0032 will replace how the route is found with floods over what a bot knows; how it is walked stays.

## Considered options

1. A funnel over the route's cells when the route is found: the shortest line through the corridor of cells, computed once.
2. Looking ahead while walking: each frame the bot drops the next point of its route while the one after it can be walked to in a straight line.
3. Steering towards the route with a pull to its next points, and no straight line.

## Decision outcome

Option 2.
It needs nothing but the test "can the body pass straight from here to there over level ground", which the grid answers cell by cell; it works on whatever route there is, however it was found — today's search or ADR-0032's floods; and it costs a few cells' look-ups a frame for each bot.
Option 1 is exact but is tied to the route being a corridor of cells found in one piece, which a route that floods re-choose each tick is not. Option 3 cuts corners the body cannot pass.

### How it works

`Execution.straighten` runs before each step a bot walks. While the route has two points or more and the bot can walk straight from where it stands to the second, the first is dropped.
A straight walk is open when, sampled every quarter cell along it and along two lines beside it at the body's radius (FR-MAP-025), every point is over a cell of the bot's floor that the navigation graph holds, at the height the bot stands at.
So a bot heads for the farthest point of its route it can see a clear, level way to, and turns towards the next only when it reaches it or the way to it opens.

### Consequences

- Where no shortcut is open — along a wall a body's radius from it, up a flight, round a corner — the bot walks cell by cell, as before.
- The look-ahead is re-done every frame, so a bot that has turned a corner straightens at once.
