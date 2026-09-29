# ADR-0047 — The ground slabs are drawn as one mesh a module

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, FR-VIEW-240, FR-TOOL-020, NFR-PERF-010, NFR-PERF-050

## Context and problem statement

With the phone held at its sustained performance level (ADR-0046), a match ran at 36–39 frames a second, and the GPU was busy for 11 ms of each 26 ms frame: something other than the GPU held the frame.
A GPU frame capture taken on the phone on 2026-09-29 (`MTLCaptureManager` to a `.gputrace`, opened in Xcode 27.0) showed the main render pass issuing 3822 draw calls a frame for about a thousand entities: several draws an entity, among them an occlusion culling query, whose pipeline the capture names. Every draw is encoded on the CPU, whose clock the sustained level also lowers.
644 of the shipped map's 852 pieces are the slabs of the ground floor: the floor and ground cells, and the floor the map implies under whatever stands on them (FR-TOOL-020). They never move and never change their look.

## Considered options

1. The ground slabs joined into one mesh a module, built once when the map is built.
2. The ground slabs drawn as instances of one mesh (`MeshInstancesComponent`, iOS 26).
3. Every piece left an entity of its own.

## Decision outcome

Option 1. The main pass fell from 3822 draw calls a frame to 1283 and 1269 in the two main passes of a capture of the same scene, forty milliseconds long — about four draws fewer for each of the 644 slabs; the slabs look as they did.
Option 2 was tried first on 2026-09-28 and drew nothing where the floor had been, for a reason not found; a joined mesh has no such unknown, and the whole arena is on screen at once, so the finer culling instances would allow buys nothing.

### How it works

**Which pieces are ground slabs** (`ScenePlan.groundSlabs`): boxes of the ground floor (FR-MAP-170) whose tops lie at its walking surface, over no basement. The see-through never touches them, and a test holds that over the shipped map with the head on every cell anybody can stand on and the camera turned every eighth of a turn:
- a floor fades whole only when it is above the head's floor (FR-VIEW-140), and nothing is below the ground floor but a basement, which is why a slab over one is left out;
- a module is cut round the head only where its top stands above the surface the head is on (FR-VIEW-155), and a slab's top is that surface;
- a line of sight from the camera, above, to the snake, on or over the surface, does not pass through what lies under the surface (FR-VIEW-150); that the margin round the line does not reach them either is what the test shows, not what the geometry alone promises.

**The mesh**: each slab's rounded box (FR-VIEW-240), moved to where the slab stands, all of one module joined into one `MeshResource` with one material, a child of the map named `slabs:<module>`, lit by the scene's ambient light as every other model is. The see-through is given every piece but the slabs.

### Consequences

A slab can no longer be told apart from its neighbours at run time — nothing does that today, and a feature that needs it (a slab that breaks, FR-MAP-030) would take its slab out of the mesh.
A map with a basement keeps the slabs over it as entities of their own.
At the sustained level the match went from 38.7 and 39.0 frames a second to 59.6 and 59.9, over the 5th to the 30th second of four runs taken in turn — without, with, without, with — on 2026-09-29, after the phone had lain untouched for forty minutes and cooled for two and a half before each; the median frame interval went from 21–25 ms to 16.7 ms, the thermal state stayed `nominal`. Runs taken earlier the same day, soon after an update of iOS and with the phone in use, fell to twenty frames a second with the slabs joined and without, and showed nothing either way: a comparison is taken on a phone left alone first.
