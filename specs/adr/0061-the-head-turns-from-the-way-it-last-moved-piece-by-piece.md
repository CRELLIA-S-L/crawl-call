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

- Each piece turns the heading towards the held direction by the smaller of the gap and the piece's length over the radius; a half turn has no shorter way and always goes the same way, so the same stick turns the snake the same way. A turn back that the shorter way would take into a wall goes the other way round (below, 2026-09-30).
- The piece is then walked the turned way, sliding along what it meets as before.
- Before the head has moved at all there is no heading, and the first piece goes the way held.
- A lunge and a coil call the same movement without a radius and go where they aim at once.

### Consequences

Turning round takes a way twice the radius plus the body's 0.6 m, 1.6 m at the first radius and 1.3 m at the 0.35 m of 2026-09-30 (FR-SNAKE-290): the snake does not turn round in a one-metre doorway, and must go through.
Against a wall, the head slides along it, the heading becomes the wall's, and it turns back towards the held direction from there. As built, while the head was still turning, the slide of FR-SNAKE-015 was taken in the way it had turned to rather than in the held direction the requirement named; once it had turned the two were one (Q-470). Since 2026-09-30 the slide goes to the side the held direction leans to (ADR-0066).

**2026-09-30, turning back beside a wall.** Found on the phone after that change: a head going along a wall, touching it, and steered back the way it came broke the snake. The shorter way round led into the wall; the wall stopped the turn at once, and the slide sent the head back along the wall at the whole of its speed, the held direction leaning that way — a half turn in a frame, back over its own neck, which FR-SNAKE-290 is there to prevent.
A turn back — the held direction behind the way the head is going by more than the five degrees of lean that count (ADR-0069) — now goes the other way round where the shorter way's next piece would be stopped or refused and the other way's is open: tried on a copy of the snake, the piece walked as it would be. The way round taken is kept until the held direction is no longer behind the head, no direction is held, or a lunge or a coil moves the head (found in review the same day: kept past a lunge, it sent the next turn back the longer way round on open ground); decided afresh each piece, the head went a few degrees away from the wall, found the shorter way open again, turned back into the wall, and went on along it every frame instead of turning round (found on the simulator the same day).
Where neither way round is open — a corridor narrower than the turn takes — the turn goes the shorter way as before, the slide takes the head back along the wall, and the head crawls over its own body (FR-SNAKE-055): the snake does not turn round there, as the consequence above says.
A held direction back behind the head and into the wall, such as back and a little into it, comes round the open way and then meets the wall, or its own body lying along it, as it would anywhere.
