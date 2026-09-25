# ADR-0040 — A drop is an arc chosen at the edge, landing as far on as the body can land clear

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-SNAKE-220, FR-SNAKE-030, FR-SNAKE-020, IF-MAP-020

## Context and problem statement

Off a ledge the head was moved to the ground below in the frame it went over, with the edge and the landing put into the trail so that the tail hung down the drop (FR-SNAKE-220, as written on 2026-09-21).
On 2026-09-25 the maintainer found that the snake fell off the side of the flight and off the balcony in a single frame. Coming straight down at 6 m/s was built first and turned down: a jump off the balcony is an arc, as it was in the first spike, whose snake ran on a character controller under a gravity of 9.8 m/s² and kept its speed across as it fell (`spike/Spike/Snake.swift`, commit e8312b3, retired in 6dcd175).
The body is checked against what is below before it lands (`Surfaces.fits`, ADR-0021): a landing inside a wall down there is refused like a wall (FR-SNAKE-220's tests). An arc lands somewhere other than straight below, so where it lands has to be checked too.

## Considered options

1. Straight down at a speed of its own, the direction held waiting until the head has landed.
2. An arc steered in the air, as the spike's controller did: the head goes on the way the player holds, and falls under gravity until something below stops it.
3. An arc chosen at the edge: across at the speed the head walked off at, down under gravity, to a landing found before it leaves — as far on as the fall carries it, or nearer where only nearer is open, or straight down.

## Decision outcome

Option 3.
It is the arc the maintainer asked for, and every landing is checked before the head leaves the edge, as every landing was before.
Option 1 was turned down. Option 2 needs the body tested against everything below on every frame of the flight, with a landing that can be anywhere, including in a wall or over nothing; the game has no physics and the checks it has are made for a head that is on a surface.

### How it works

`Snake.stepOnce`, going over a ledge that straight down is open below, puts the edge into the trail and asks `Surfaces.arc` for the landing, with the direction of the step and the speed the head last walked at.
`Surfaces.arc` first measures how far the air at the ledge's height is open along that direction: where ground comes back at that height — the far side of a hole in a floor — the arc may land no farther than the body's radius short of it, since beyond it the head would go on under the floor it left. Review found that on 2026-09-25, before the first commit, as an arc across a hole two cells wide that landed at x = 2.55 m, under the floor past the hole's far side at 1.25 m.
It then tries landings along that direction from the farthest the fall allows — the speed times the time to fall the maximum drop, 2.35 m at 3 m/s off 3 m at 9.8 m/s², or the open air, whichever is less — back towards the edge every 5 cm, and takes the first one where: there is ground below within the maximum drop; the fall to that ground lasts long enough to carry the head that far at its speed; the body fits there; and it fits every 10 cm on the way there at that ground's height. What stands lower than the ledge it leaves — the steps of a flight below its own — is flown over. Where none farther fits, the arc lands straight below.
`Snake.advance` goes on along a drop under way before anything else, whether or not a direction is held: across at a steady rate, down as the square of the time gone by, in the time the fall takes. Every place goes into the trail, so the tail follows the arc. What is left of the frame once the head has landed is walked.
A drop gravity of nothing lands the head at once, straight below.

### Consequences

- Off the balcony, 3 m, the head is in the air for 0.78 s and lands up to 2.35 m on; off a step of a flight, less. The player's direction does nothing in the air.
- A landing is as far as the speed carries the head or nearer, never farther: a wall below shortens the arc rather than being gone through.
- The flight is checked at the landing's height only; a body passing over something that stands higher than the ledge it leaves and lower than its arc is refused rather than flown over, which makes some arcs shorter than they could be.
- No meal is begun in the air: a meal holds the head where it is (FR-SNAKE-090), and one begun mid-drop held it there, found in review on 2026-09-25. The eat button says there is nothing to eat until the head has landed.
- The tests that stepped off a ledge in a single call now step frame by frame until the head has landed.
