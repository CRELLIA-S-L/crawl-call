# ADR-0041 — The ground is covered for a camera turned any way round the point it looks at

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-MAP-140, FR-MAP-270, FR-VIEW-010, FR-VIEW-020

## Context and problem statement

FR-MAP-140 had the setting cover every frame the match camera can show, and the match camera's yaw is fixed (FR-VIEW-010), so the ground was sized for one direction: far beyond the arena, where the camera looks, and a few metres on the camera's own side (`FrameCoverage.covered`, ADR-0031).
On 2026-09-25 the maintainer turned the free camera of debug mode (ADR-0023) and found the island at the very edge of the water on that side, and asked for it to stand in the middle of the water whichever way the camera turns, since the match camera may one day turn to follow the snake.

## Considered options

1. The covering rectangle of a circle: the arena grown on every side by the farthest any corner of any frame lies from the point looked at.
2. The exact ground a turning frame sweeps, sampled over yaw, and its bounding rectangle.
3. A ring of water round the island, drawn as a disc rather than as rectangles.

## Decision outcome

Option 1.
A frame turned round a point stays inside the circle through its farthest corner, whatever the yaw, so the rectangle round that circle holds every frame at every yaw, and needs no sampling to be sure of it. Its corners reach farther than any frame does, by about two-fifths of the radius, and that ground is water drawn as a few rectangles either way, so it costs nothing a frame.
Option 2 is the same rectangle for a sweep that is a full turn, since a full turn of a frame round a point is the circle; it only adds sampling. Option 3 changes how the water beyond the grid is drawn for no gain.

### How it works

`FrameCoverage.reach` keeps, beside how far the frame reaches beyond, towards and across, its `radius`: the largest distance of any corner from the point looked at, over the pitch range, the widest frame and the highest and lowest point looked at. A corner's distance is convex in the drop and the aspect, which the corners are affine in, so it is largest at the ends of their ranges, as the other reaches are.
`FrameCoverage.covered` grows the arena's footprint by that radius on every side, and by the slack as before. The water and the floor under it (FR-MAP-270) are laid out to it as they were to the one-direction rectangle.

### Consequences

- The water reaches the radius on every side: on the phone at 55 degrees, about 23 m round the arena where it was 5.7 m towards the camera.
- The test that the covered ground is no larger than it needs to be now turns the frame's farthest corner to face straight out past the arena, and finds the rectangle shrunk by the slack missing it.
- A match camera that turns later needs nothing more from the setting.
