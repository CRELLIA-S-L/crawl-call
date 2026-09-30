# ADR-0066 — A slide goes the way the stick leans, the tail past the neck is a wall, and a coil falls with its bot

- **Status:** accepted
- **Date:** 2026-09-30
- **Related requirements:** FR-SNAKE-015, FR-SNAKE-050, FR-SNAKE-285, FR-SNAKE-280, FR-SNAKE-290, FR-SNAKE-220, IF-SNAKE-010

## Context and problem statement

On 2026-09-30 the maintainer found three things on the phone: the snake running into obstacles and stopping, trees included; the snake folding in two when its head, in a corner, was pulled the other way; and a bot on a stair that could not be eaten, the snake falling off the flight as it coiled round it.
Measured on the simulator the same day: a head crawling at a tree stopped at it in 11 starts of 33, with the turning radius of 0.35 m, of 0.5 m or none, the same starts each time — a head that meets a face squarely stands still, as FR-SNAKE-015 always said. With the arc the head no longer swerves at the last moment, and while it turns, a slide was taken in the way it had turned to rather than the way held (Q-470). In a corner, a slide turned the head at once, and the arc then brought it back within a third of a metre of its own body, where the body is 0.6 m wide. Round a bot on a flight one cell wide, no ring of two bodies fits, and the head went off the flight's side.
The maintainer chose the slide to follow the stick, which settles Q-470; to build FR-SNAKE-050, the tail stopping the head; and, for the stair, the snake falling with the bot and eating it where it lands.

## Considered options

For a slide while the head is turning:

1. Along the obstacle to the side the held direction leans to, at the held direction's part along it; where the stick is held away from the obstacle, the way the head is going taken along it instead.
2. Always the held direction, as before the arc.
3. Always the way the head is going, as the arc left it.

For what of the tail is in the head's way:

1. The line through the tail's segments past the first `neckSegments`, as it is drawn, a body's width thick.
2. Every segment, as a ball.
3. The trail's cells on the grid, as the bots' blocking is planned (ADR-0016).

## Decision outcome

Option 1 for the slide: it is the maintainer's words, and it keeps the head from standing against a wall the stick is pulling it away from, where option 2 has no part of the held direction along the wall and would hold it there.
Option 1 for the tail: balls a segment apart leave gaps a head slips through at a slant, and the grid is a cell coarse where the head is steered to the centimetre (ADR-0016 already says the head's is collision, not the graph).

### How it works

**The slide.** A piece of movement goes the way the head is going (FR-SNAKE-290). Where that meets an obstacle, what is left of the piece is laid along the obstacle's face: if the held direction leans into the obstacle, or along it, the rest is its part along the face, to the side it leans — nothing where it leans squarely in; if it leans away, the part of the way the head was going. A second face, in a corner, is met the same way. A side of a cell the graph refuses — the lip of a hole with nothing below, the edge of the ground — has no face but the cell's side, and is slid along the same way on the axis the piece did not cross: the held direction's part there, or the way the head was going where the stick leans back across the side; this was missed at first and found in review the same day.

**The tail.** While the stick steers the head, and in a lunge, the tail past its first two segments is a wall: the head goes along a piece no further than where its centre comes a body's width — the segment spacing — from the line through those segments, and the way off that line is the face slid along. A head already that near a part of the tail is stopped only by moving nearer to it, so that it can always leave. In a coil the tail stops nothing.

**The fall.** A coil whose head goes off a ledge is marked falling; the head then only comes down the rest of its drop, the bot held where the head is, and when the head lands the bot is on the head's floor and the meal begins.

### Consequences

Pulled out of a corner the head turns away along a wall and round beside its own body, a body's width off it; the body drawn on behind the head can come in a few centimetres further as it follows, which the test allows for.
The snake can now shut itself in: a head in a dead end narrower than its turn stands against its own tail, which is what concept §4 and FR-MAP-080's trap corridors intend.
A head pushed squarely into a wall still stands still.
Q-470 is settled here.
The same day, 2026-09-30, the tail as a wall was taken back: on the phone the maintainer found a snake that cannot get past itself strange, and the head now crawls over its own body instead (FR-SNAKE-055, ADR-0067), so the snake no longer shuts itself in. The coil's fall stands as written here; the slide went on the same day to the whole of the head's speed, round to the roomier side where the stick leans to neither (ADR-0069).
