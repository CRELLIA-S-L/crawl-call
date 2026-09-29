# ADR-0052 — The lunge follows its prey for a fixed time, by the snake's own movement rules

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-SNAKE-270, FR-VIEW-310, FR-VIEW-160, FR-SNAKE-090, FR-SNAKE-220, IF-SNAKE-010, IF-VIEW-010

## Context and problem statement

On 2026-09-29 the maintainer asked for eating to begin at a distance from the prey, with the snake throwing itself at it as a cartoon. Asked, they set the reach at 1.5 m, let the lunge miss, had it go by the snake's movement rules rather than only along a clear straight line, and chose a wind-up, a stretch and a squash for its look.
Each still needed a way chosen: what the lunge aims at while the prey moves, how long it lasts, when it has reached the prey, what the stick does meanwhile, and how the look is drawn.

## Considered options

For what the lunge aims at:

1. The prey where it is each frame.
2. Where the prey was when the lunge began.

For how long it lasts:

1. A fixed time: the wind-up and then as long as crossing the reach at the lunge speed takes.
2. Until the head has covered the reach in distance.

## Decision outcome

The prey where it is each frame, for a fixed time. A lunge at where the prey was would miss a bot that took a step, which a cartoon strike does not; one that follows the prey still misses a bot that runs clear or gets something between itself and the head, which is the miss the maintainer asked for. A limit in distance never ends where a wall holds the head still and it covers nothing, and a limit in time ends it anyway.
The numbers other than the reach are chosen here and are in `config/snake.json` for the maintainer to feel out: a wind-up of 0.25 s and a speed of 7 m/s, about half a second in all, faster than any bot runs. The first try, 0.1 s and 10 m/s, a quarter of a second, the maintainer found on the phone too quick to see: "something twitches, and that is all".

### How it works

The eat intent lunges at the nearest bot within the reach of the head, living or dead, when no meal or lunge is under way and the snake is not in the air off a ledge; otherwise it does nothing, and the eat button is lit exactly then (FR-VIEW-160).
The wind-up holds the head still. Then each frame the head is sent level towards the prey where it stands now through the same movement the stick drives, eased out: at a share u of the travel's time its speed is 3/2 · (1 − u²) of the lunge speed, half as fast again as the average as it sets off and nothing as it ends, so that it covers the reach in the time a steady pace would and does not stop dead — which the maintainer, on the phone, found the steady pace did: it slides along what stops it and goes off a ledge where the stick would take it (FR-SNAKE-010, FR-SNAKE-220). The stick is not heard until the lunge is over; the direction it holds is kept, and the snake goes on with it afterwards.
The lunge ends in the meal the frame the head is within the reach the meal began at before, the head's body plus half a cell; it ends with nothing when its time runs out, when the head goes off a ledge, since nothing is eaten in the air, or when the prey is gone. The time it ended at is kept for the drawing.

The drawing turns the head to the prey for the whole lunge and scales it along the way it faces and across it: squashing through the wind-up, stretched while it travels, and squashed where it ends, easing back over 0.3 s. Only the head: the body follows the head's path as it follows any movement.

### Consequences

A bot beside a wall can be lunged at from its other side and the head stops at the wall, a miss the player sees happen; the eat button says a bot is within reach, not that the lunge will land.
The meal still holds the head where it is (FR-SNAKE-090), now from where the lunge landed.
