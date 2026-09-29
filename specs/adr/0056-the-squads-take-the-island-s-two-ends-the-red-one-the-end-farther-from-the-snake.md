# ADR-0056 — The squads take the island's two ends, the red one the end farther from the snake

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-BOT-350, FR-BOT-020, IF-BOT-010

## Context and problem statement

The squads were placed away from the snake: the red squad at the cell the walk from the snake's start reaches last, the blue squad at the farthest such cell outside the grouping distance of the first.
Both squads wanting to be away from the player put them on the same side of it whenever the snake starts off the island's middle, and on Greenholm it usually does.
The maintainer asked on 2026-09-29 for the squads to start at opposite ends of the island (FR-BOT-350), which leaves open which squad takes which end and how a squad fills round its end.

## Considered options

1. The two cells farthest apart across the ground among those the snake's start reaches outside its interrupt distance; the red squad at the one farther from the snake.
2. The same pair, the squads assigned by colour at a fixed side of the map.
3. The pair that maximises the smaller of the squads' distances from the snake.

## Decision outcome

Option 1. It is the requirement's own measure, needs nothing the map does not say, and gives the same match for the same map and spawn point.
Option 2 depends on how a map is drawn, which a map does not declare.
Option 3 answers "away from the snake", which is not what was asked, and pulls both ends back towards one side on a long island.

### How it works

- The candidate cells are those the walk from the snake's start reaches, less those within the interrupt distance across the room (IF-BOT-010); where that leaves none, all it reaches.
- The ends are the pair of candidates farthest apart across the ground, whatever floor each is on, every pair compared; a tie goes to the pair first in the order floor, z, x.
- The red squad takes the end farther from the snake across the ground, the blue squad the other.
- Each squad fills the free cells nearest its end along the walk, and every blue cell keeps the grouping distance from every red bot, as before.

### Consequences

The comparison is over every pair of cells, once a match, before it begins: the blockout's six hundred walkable cells make 185,000 pairs, fewer once the snake's surroundings are taken out.
A snake that starts at one end of the island leaves that end's squad just outside its interrupt distance, since the excluded cells move the end inward; that is the requirement's trade, not a flaw of the choice.
