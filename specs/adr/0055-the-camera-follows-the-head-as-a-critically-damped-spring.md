# ADR-0055 — The camera follows the head as a critically damped spring

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-VIEW-020, FR-SNAKE-270, FR-SNAKE-280, FR-TOOL-070, FR-VIEW-050

## Context and problem statement

With the lunge (FR-SNAKE-270) the head moves at up to ten metres a second for a fraction of a second. The camera was held to the central region of FR-VIEW-020 exactly: it did not move while the head was inside the region and moved as fast as the head the moment it left it. On 2026-09-29 the maintainer found the camera jerking during the lunge, and then, after a first fix, jumping at meals.
Three findings came out of it, and they are kept here because the next person to see the camera jump will want them.

1. **Not a stalled frame.** The frame record of two minutes of play on the phone, five meals in it, showed the frames round every meal 16.5–18 ms apart, and the room for a coil (ADR-0053) took 0.2–0.4 ms to find on the simulator. What moved the picture was the camera, not a frame the renderer missed.
2. **An easing at a steady rate still jolts.** Easing the camera towards where the region would have it, a share of the gap each frame, starts it at the full speed of the gap's closing the frame the head leaves the region: the picture's position no longer jumps, its speed does.
3. **Two thumbs are not a camera gesture.** Once the controls lay inside the view that carries the free camera's gestures (ADR-0051), a thumb on the stick and one on the right half were taken for a two-finger pan, pinch or twist of the free camera (FR-TOOL-070), which took the camera off the snake at every meal — "it moved off somewhere, I had to move it back by hand".

## Considered options

1. The camera as a critically damped spring towards where the region would have it, its speed carried from frame to frame.
2. The easing at a steady rate, slower.
3. The camera held to the region, as it was.

## Decision outcome

Option 1. A critically damped spring sets off from rest, slows as it arrives, and does not overshoot where the head stopped: following a head that moved at a steady pace and stopped, its lag behind it is exactly what brings it to rest without passing it. Stepped by its exact solution over each frame, x(t) = (c + (v + ωc)t)e^(−ωt) for c the gap and ω = 2 / the spring's time, a long frame does not throw it off. The spring's time is the view configuration's camera follow lag, 0.3 s. The height is not sprung: a change of floor is followed at once, as before.
Option 2 makes the jolt smaller and the lag longer, and keeps the jolt.
The two-thumb finding is fixed where it arose: a free-camera gesture does not begin on touches that lie on both halves of the screen (FR-TOOL-070).

### Consequences

For a moment after a quick movement the head is outside the central region, by the spring's lag; the region is where the camera brings it back to, not a wall it is held at.
A test holds the camera's speed to changing by less than a tenth of the lunge's speed from one frame to the next through a lunge.
