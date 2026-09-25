# ADR-0033 — A flight of steps replaces the stair that went straight up, and every cell carries the height of its surface

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** IF-MAP-010, FR-MAP-020, FR-MAP-025, FR-MAP-070, FR-MAP-150, FR-MAP-160, FR-SNAKE-010, FR-SNAKE-220, FR-BOT-250

## Context and problem statement

The blockout's floors were joined by a stair inside one cell: a map's `transition` line made an edge between the same cell on two floors, a walkable module a floor tall stood in it, and the snake entering the cell was carried the floor's height straight up (ADR-0021).
On 2026-09-25 the maintainer found that it looked and felt wrong and asked for ordinary stairs in its place; a way straight up may come back for sniper towers and lookouts, after the snake's destruction of buildings is settled (Q-330).
Everything below the map took a cell's height to be its floor's — the graph's nodes, where a bot stands and walks, where the snake's body is measured from, the ground the see-through asks about — computed in nine places as the floor's number times the floor height.

## Considered options

1. Steps: a flight drawn as a run of cells on the lower floor, each a block one rise taller than the one before.
2. A smooth ramp: one sloped surface over the same run of cells.

## Decision outcome

Option 1, chosen by the maintainer.
Everything that asks about geometry — the line tests bots see by (ADR-0019), the index that narrows them (ADR-0028), the see-through (ADR-0020) and the body's collision (ADR-0021) — works on boxes aligned with the axes. Steps are such boxes and need nothing new; a ramp is not, and each of the four would have had to learn slopes, or would have taken the ramp for a solid block and let nobody see under it.

### How it works

**The map draws a flight as arrows.** A cell on a floor's grid holding `^`, `v`, `>` or `<` is a step rising the way it points, up the page towards −z (IF-MAP-010). A flight is a run of the same arrow along its direction; its first step is the one no arrow of the run leads up to. The arrows are the format's, not the kit's, because which way a flight rises is the map's to say; the kit names the module a step is drawn as (`stepModule` in its legend) and a kit whose step module is not in its legend is refused at load.

**Heights are the flight's.** A flight of n steps shares the floor height in n equal rises, its top step level with the floor above, and the cell beyond the top must be walkable on the floor above, or the map is refused (`MAP_FLIGHT_LEADS_NOWHERE`). A rise higher than the tuning's step height refuses the map naming the flight's line (FR-MAP-160, `MAP_FLIGHT_TOO_STEEP`): with the shipped numbers, a floor of 3 m and a step of 0.4 m, a flight has at least eight steps. The parser takes the step height from its caller, since the map does not carry it; the launch passes the tuning's.

**Every cell has the height of its surface.** The parsed map carries its kit's floor height and answers how high a placement's surface is; the graph keeps that height for every node, and every place that took a cell's height from its floor now takes it from the node: where a bot stands and walks to, where it spawns, where the snake starts, the ground under the head for the see-through.

**Edges are a step apart.** Two neighbouring nodes are joined where their surfaces differ by no more than the step height, whichever floor each is on (FR-MAP-020). The top step joins the floor above by that rule alone, as the bottom step joins its own floor; beside a tall step there is no edge, so no bot steps off the side of a flight or onto it from the floor. A `transition` line still makes an edge between the same cell on two floors, and the snake still climbs one, for the way straight up a tower may have one day.

**Steps are blocks.** A step is placed as a box from the underside of its floor's slab, so the two meet, up to its height.

**The snake walks the graph's edges.** Crossing into a neighbouring cell, the head moves to the node the graph joins its own to there, on whichever floor, and walks the difference in height as a climb, as it walked a stair before (FR-SNAKE-030); a cell the graph does not join it to is a wall or a ledge. The body is measured from its node's surface, and ground is in its way only where it stands more than a step above the body's feet — the side of a step too tall to climb onto is met like a wall, one a step up is walked onto (this narrows ADR-0021). The side of a flight is a ledge like a balcony's edge (FR-SNAKE-220), and a landing ignores what was not in the body's way on the ledge it left — the step it slides down, and the one a step above that — which the body lands half beside and walks clear of.

**The blockout.** The shaft at cell (21, 12) and its `transition` line are gone. A flight of eight steps on the ground floor, rows 12 and 13 from x = 6 to 13, rises east into the balcony through an opening three cells wide, z = 11 to 13, in its west wall: the snake's body is 0.6 m across and a single cell is 0.5 m, so a one-cell opening would pass a bot and stop the snake — ADR-0021's gap. The flight was built one cell wide, 0.5 m, and on the phone the maintainer found it very hard to climb; on 2026-09-25 it was widened to two cells, 1 m, of which the snake's body, 0.6 m across, still covers more than half where it lies — the nearest to the stair FR-MAP-070 asks a map to have that can still be climbed; whether the body then stops a bot on it is FR-SNAKE-040's, not yet built. Walls along its sides were not the answer: a flight of one cell between walls is a gap the body cannot enter at all, and the kit has no wall that rises with the steps.

### Consequences

A map draws its stairs where it wants them, in the grid, and a stair that cannot be climbed is refused where it is written rather than found by a bot that never arrives.
A flight joins its floors for the bots as for the snake by the same step height, which is FR-MAP-025's agreement kept by construction.
A bot knows the ways between floors from the start (FR-BOT-250); a flight is such a way, and a bot that has not seen it still knows where it is.
The head crossing a cell corner diagonally is no longer carried into the diagonal cell, which the graph does not join; the piece of movement is split along the two axes instead, as at a hole's lip.
