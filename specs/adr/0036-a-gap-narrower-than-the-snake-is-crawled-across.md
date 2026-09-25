# ADR-0036 — A gap in the floor narrower than the snake is crawled across, and a corner of a cell is ground

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-SNAKE-260, FR-SNAKE-220, FR-SNAKE-010, FR-MAP-020

## Context and problem statement

On the phone the snake fell from the blockout's balcony to the floor below in cells nowhere near its edge, whichever way it was going, and it fell the way it falls off a ledge. A probe that walked the snake about the balcony at random reproduced it in 36 walks of 200.
The head moves a frame's distance in one piece, in the direction held, and asks the graph about the cell it ends in (ADR-0021). When that piece crosses a corner of the cell it starts in, it ends in the cell corner to corner with it. The graph joins cells side by side only (FR-MAP-020), so it joined nothing there, and a cell the graph joins nothing to was taken for a ledge. On the ground floor there was nothing lower to land on and the head slid on; on the balcony there was, and it dropped.
The first fix let the head through a cell beside the corner. The maintainer then set the rule it was a case of: the snake does not go where it does not fit, and that holds for a gap in the floor and a joint between cells as it does for a gap between walls, and for every part of the snake. A gap too narrow to fall into is crawled over (FR-SNAKE-260); a gap wide enough is a ledge (FR-SNAKE-220).

## Considered options

For a corner crossed within a frame:

1. Join the graph's cells corner to corner as well.
2. Break every step of the head into its part across and its part down, so that no step crosses a corner.
3. Let the head through one of the two cells beside both, where the graph joins them, and across the corner itself where it does not.

For a gap in the floor narrower than the body:

1. Stop the head at it, as at a wall.
2. Let the snake crawl across it at the floor's height.

## Decision outcome

Option 3 for a corner. Option 1 changes what the bots path along: a bot would cut corners between two walls that meet at a point, and the graph is the bots' as much as the snake's (FR-MAP-020). Option 2 changes how the head moves in every frame, and with it the trail the tail follows, to mend a case of one cell.
Option 2 for a gap, chosen by the maintainer.

### How it works

**A gap narrower than the body.** When the snake's surfaces are built, each floor is sampled on a grid of 5 cm. What holds the body at a floor's height is a cell with a surface from a step below that height up to the floor above — on whichever floor, so that the top of a flight holds the balcony's edge and a flight's taller steps stand on the ground floor rather than being a gap in it — or a cell something stands on. The rest is gap. A gap is narrow where no point of it is as far from what holds the body as the body's radius, and where it does not reach the grid's edge, which would make it as wide as the world beyond the map. The cells of a narrow gap become ground for the snake at the floor's height: it walks onto them and off them as onto the floor's own cells, within a step of its height. The graph does not hold them, and no bot crosses a gap.
The head never goes down into a narrow gap, and every other part of the snake lies along the head's trail, so no part of it does.

**A corner of a cell.** Where the head enters the cell corner to corner with its own, it goes through the cell beside both across, or the one beside both down, where the graph or a narrow gap joins it to that one and that one onward. Where neither does, the two cells meet at a point, which is a gap of no width, and the head crosses it to the cell it entered if there is ground there within a step. Where there is none, it is a ledge as before.

**Everything else is as it was.** A gap as wide as the body, the balcony's open edge, the side of a flight: the head drops where FR-SNAKE-220 lets it and stops where there is nothing to land on.

### Consequences

The random walk that dropped the snake 36 times in 200 drops it only off the balcony's open edge in row 17, beside the top of the flight — a real ledge, which the maintainer keeps open.
A hole of one cell in a floor, or a slot one cell across however long, is crawled over. A hole two cells across both ways is a drop.
The narrow gaps are found once, when a match's surfaces are built, not every frame.
Leaping a gap wider than the body is a question for later (Q-410).
