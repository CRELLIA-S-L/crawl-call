# ADR-0068 — A part of the body with nothing under it falls under the drop gravity, oldest first

- **Status:** accepted
- **Date:** 2026-09-30
- **Related requirements:** FR-SNAKE-056, FR-SNAKE-055, FR-SNAKE-220, FR-SNAKE-020

## Context and problem statement

The head rides over its own body (FR-SNAKE-055, ADR-0067), and the place it lays down in the trail keeps that height. On the phone on 2026-09-30 the maintainer found the snake climbing its own layers and then hanging in the air: the body under a raised part moves on along its path, or is cut off the end of the tail, and the raised part stays where it was laid. The maintainer asked for physics.
Open: what holds a part up, how it comes down, and in what order.

## Considered options

1. Each frame every raised place of the trail is held up by the body laid before it past the neck where it crosses it, on the circle of ADR-0067, or else by the ground; one higher than that falls under the drop gravity, with a speed of its own, oldest places first.
2. The same, but a raised place drops to what holds it at once.
3. Draw each part at its support's height and keep no height in the trail.

## Decision outcome

Option 1. Option 2 is a snap the eye reads as a glitch, the thing the lift slope of ADR-0067 was put in to avoid. Option 3 would make the height a picture only, which the bots see and fire at through the body; and the order matters, since a part resting on a part resting on another comes down only as fast as the one under it.

### How it works

- Each place of the trail keeps the height it would have had with no body under it — where the head went — beside the height it is at.
- Once a frame, after the snake has moved, the places are taken oldest first. What holds a place up is the highest of: the ground, at the kept height; and each stretch of the trail laid before it, more than the neck's length of path back — two segment spacings — lying within a body's width of it, level, and no more than two widths above or below, on the circle of a body's width round that stretch.
- A place no higher than that stays, and its fall speed is nothing; a higher one gains the drop gravity times the frame's time in speed and comes down by that speed times the time, never below what holds it. Nothing goes up this way.
- The head is a place like any other, and its lift is what is left of its height above the ground once it has settled.

### Consequences

A part laid over another stays on it as long as the other is there, and comes down within about a third of a second of it going from a body's height — √(2 × 0.6 / 9.8).
The work is, for each raised place, a pass over the older places past its neck; nothing is done for a place on the ground. A long snake — thirty segments, 18 m of tail, a place every 5 cm at sixty frames a second, some 360 places — lying in two or three layers over itself is tens of thousands of checks a frame, found in review the same day and not yet measured on the phone.
