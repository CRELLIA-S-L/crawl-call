# ADR-0037 — A rounded box is extruded, not generated

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-VIEW-240, FR-VIEW-150, FR-VIEW-170, FR-GREENHOLM-030, NFR-PERF-010

## Context and problem statement

The maintainer asked for the edges of every drawn box to be rounded slightly (Q-400, now FR-VIEW-240), and for a quick trial first: every box rounded, no questions asked.
The obvious way is RealityKit's own `MeshResource.generateBox(width:height:depth:cornerRadius:splitFaces:)`, which the bots' figures already use (ADR-0022).
Its documentation in the iOS 27.0 SDK (`RealityFoundation.swiftinterface` and its `.swiftdoc`) says only that the radius is clamped to half the smallest side; it has no parameter for how finely the rounding is cut.
Tried on the phone on 2026-09-25 with the trial's boxes, the match dropped from 673 frames in a ten-second run, 2 of them late, to 387 frames, 201 of them late; the game's own work stayed under a millisecond a frame in both runs, so the time went to drawing.
Counted on the Mac the same day, a square box is 12 triangles and that rounded box is 13 068, at every size and radius tried — a cube of a metre, a partition of 1 × 3 × 0.1 m, a figure's part of 15 cm — with `splitFaces` or without.

## Considered options

1. `generateBox(width:height:depth:cornerRadius:)` — 13 068 triangles a box.
2. `generateBox(size:majorCornerRadius:minorCornerRadius:)`, iOS 18 — 3 760 triangles at both radii 0.03 m.
3. A rounded rectangle extruded with rounded rims, `MeshResource(extruding:extrusionOptions:)`, whose `chamferResolution` and `boundaryResolution` set the segments across a rounded edge — 132 triangles at one segment, 328 at two, 620 at three, 3 600 at the default of eight.
4. A mesh of our own through `MeshDescriptor`, as the island's surfaces are built.

## Decision outcome

Option 3 at two segments.
It is RealityKit's own, so nothing is written that the SDK already does; at two segments the edges read as rounded at the camera's distance on the trial's screenshot from the phone; and its triangles are set by a number rather than left to the framework.
On the phone it drew 669 frames in a ten-second run, 4 of them late, three of those in the first 0.75 s after launch — beside the square boxes' 673 and 2.
Options 1 and 2 were measured out; option 4 is the same result for more code.

### How it works

`MeshResource.roundedBox(_:)` in `SceneBuilder.swift` builds a box of the size given, centred on its origin.
The radius is `Rounding.radius`, 0.03 m, or `Rounding.smallestSideShare`, a quarter, of the smallest side where that is less, so that a partition of 0.1 m is rounded by 2.5 cm and not into a bolster.
A rounded rectangle across x and y is extruded along z with rounded rims at both ends. The rims add a radius at each end, so the extrusion is shorter by two radii; the box then measures what it was asked to.
A box is built at its own size, never scaled to it: a scale that differs between axes stretches the rounding into ellipses.
The map's modules share a mesh between modules of one size, since a map is hundreds of cells in a handful of sizes; a bird's body and wings are each built once.
Where RealityKit cannot extrude, the box is drawn square.

### Consequences

- The ceiling in FR-VIEW-240, 400 triangles a box, is what a test holds, so that option 1 cannot come back unnoticed.
- The water beyond the island stays square. It is laid as up to four slabs of 0.1 m edge to edge, and the trial rounded them too: a groove showed on the water where two met, seen on the phone on 2026-09-25. Those slabs are the only boxes among the scenery's parts, which therefore keep one shared square box scaled to each part.
- The bots' figures still use option 1, 13 068 triangles a part; the frame rate held with them, and moving them is Q-420.
- One run of the trial with the water square showed 13 late frames, eight of them a stretch of about 33 ms each 10.4–10.8 s into the run, at the see-through's first hole. The run with the water rounded had one late frame near the same second. One run per variant does not tell that stretch from the match's own variation; repeated runs do.
- A module is still its box to the body, to sight and to the see-through (ADR-0034). The hole shader cuts by world position, not by the mesh (`SeeThroughHole.metal`), so it needed no change.
