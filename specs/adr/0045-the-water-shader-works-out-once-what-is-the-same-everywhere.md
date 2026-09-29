# ADR-0045 — The water's shader works out once what is the same for every point of it

- **Status:** accepted
- **Date:** 2026-09-28
- **Related requirements:** FR-GREENHOLM-070, FR-MAP-280, FR-TOOL-230, NFR-PERF-010, NFR-PERF-050

## Context and problem statement

On 2026-09-28 the maintainer found the frame rate on the iPhone falling during play. The frame record showed the game's own phases flat at 0.3–0.5 ms, and its thermal column (FR-TOOL-230) showed the phone at `serious` after a few runs: the phone was throttling itself.
Metal's performance HUD (`MTL_HUD_ENABLED=1` at launch), read off screenshots, put the GPU at 13–14 ms of every 16.7 ms frame, in a cool state, at the screen's full 2622 × 1206.
Switching parts of the scene off one at a time, each run from a cooled phone, named the water: with its waves the frame took 13.9 ms of GPU, with the same transparent water and no waves 10.3 ms. Moving bots, shots, the ground and the trees changed nothing that the thermal drift did not swamp.
The wave shader (ADR-0038) worked out, for each of its twelve waves at every point of the water, the wave's direction from a sine-based scatter, its cosine and sine, its number of waves a metre, a square root for its speed and a second scatter for its start — none of which depends on the point — and hashed its noise with a sine at each of twelve corners.

## Considered options

1. The same waves, with what is the same everywhere worked out once: tables of each wave's direction, start, length factor, speed factor and height; one square root per point for the longest wave's speed; one `sincos` and one `exp` per wave; a noise hash with no sine.
2. Fewer waves, six instead of twelve.
3. Waves in a texture computed once a frame and sampled.

## Decision outcome

Option 1: the image is the same waves, and the cost measured on the phone fell from 3.6 ms to about 0.4 ms of GPU a frame (11.1 ms with waves against 10.7 ms without, 2026-09-28).
Option 2 gives the look the maintainer rejected as waves all of one size; option 3 needs a render pass of our own that RealityKit's surface shaders do not offer.

### How it works

The tables are the values the old loop computed, worked out in double precision and written into the shader: direction = the wind (0.8, 0.6) normalised and turned by (2·s(n) − 1)·1.05, start = 2π·s(n + ½), where s(x) = fract(sin(12.9898·x)·43758.5453); length factor 1.18ⁿ, speed factor √1.18ⁿ, height 0.82ⁿ; and the sum of the heights and the root of the sum of their squares, which the old loop added up at every point.
The noise is value noise as before, its corner values hashed by multiplying and folding (Hoskins, *Hash without Sine*), so the crests bend differently than before, by the same amount.
A change to the number of waves, the wind or the spread is a change to the tables.

### Consequences

The waves are as they were, bar where the noise bends their crests.
The rest of the frame's GPU time is spread over the scene — the shadows, the water's transparency, the bots and the floor each about 1–1.5 ms, the multisampling about 1.5 ms — and about 5 ms that none of those holds, the cost of a frame at the screen's full resolution. Whether the phone still heats is measured in minutes, not settled here.
