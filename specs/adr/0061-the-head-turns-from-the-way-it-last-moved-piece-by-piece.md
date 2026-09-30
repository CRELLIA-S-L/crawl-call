# ADR-0061 — The head turns from the way it last moved, piece by piece

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-SNAKE-290, FR-SNAKE-010, FR-SNAKE-015, FR-SNAKE-270, FR-SNAKE-280

## Context and problem statement

The head went the way the stick held the moment it was held (FR-SNAKE-010), so a stick pulled back folded the snake in two, its head going back through its neck. The maintainer asked on 2026-09-29 for a turning radius, 0.5 m at the body's centre line (FR-SNAKE-290).
Open: what the head turns from, where the turn is taken, and what a lunge and a coil, which steer the head through the same movement, make of it.

## Considered options

1. A heading kept by the snake — the way the head last moved across the ground — turned towards the held direction by at most the distance of each piece of movement over the radius; the lunge and the coil pass no radius.
2. The heading kept by the game, turned once a frame by the frame's distance over the radius.
3. The heading read off the body — from the first tail point to the head.

## Decision outcome

Option 1. The snake already walks a frame in pieces of at most half a cell so as not to pass through walls; turning each piece by its own length over the radius makes the head's path an arc of the radius at any frame length, where a turn taken once a frame is a corner followed by a straight.
The heading is the way the head last moved, so it is right after anything that moved it: a lunge, a coil, a slide along a wall (FR-SNAKE-015), a drop. A climb straight up changes nothing.
Option 3 reads a direction a body length behind the head, which lags every turn.

### How it works

- Each piece turns the heading towards the held direction by the smaller of the gap and the piece's length over the radius; a half turn has no shorter way and always goes the same way, so the same stick turns the snake the same way.
- The piece is then walked the turned way, sliding along what it meets as before.
- Before the head has moved at all there is no heading, and the first piece goes the way held.
- A lunge and a coil call the same movement without a radius and go where they aim at once.

### Consequences

Turning round takes a way twice the radius plus the body's 0.6 m, 1.6 m: the snake does not turn round in a one-metre doorway, and must go through.
Against a wall, the head slides along it, the heading becomes the wall's, and it turns back towards the held direction from there. While the head is still turning, the slide of FR-SNAKE-015 is taken in the way it has turned to rather than in the held direction the requirement names; once it has turned the two are one (Q-470).
