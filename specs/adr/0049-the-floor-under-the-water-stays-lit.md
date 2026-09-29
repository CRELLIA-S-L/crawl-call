# ADR-0049 — The floor under the water stays lit

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-MAP-270, FR-MAP-280, NFR-PERF-050

## Context and problem statement

After the ground slabs were joined (ADR-0047) and multisampling dropped (ADR-0048), the GPU's work was spread over the scene with no one part far out of line. Measured by the method of `specs/50-verification.md`, drawing the floor beyond the island with no light worked out on it saved 0.45 ms of the GPU's work a frame, about 3 % — the floor there lies flat at its depth and is seen only through the water.

## Considered options

1. The floor lit, as it is.
2. The floor beyond the island unlit, the slope under the shallows lit.
3. The whole floor unlit — the slope's colour written as the emissive colour, which an unlit material takes (RealityKitSurfaceShader.h, iOS 27.0 SDK), and the floor at depth given the colour the floor's shader sees at depth, so that the two meet.
4. Option 3 with a sun and a flat light worked out in the floor's own shader, normalised so that flat floor keeps its colour.

## Decision outcome

Option 1, the maintainer's call on the phone on 2026-09-29.
Option 2 drew a band along the edge of the camera's first view, where the lit slope meets the unlit floor beyond it.
Option 3 met without a band, and made the edge between the water and the shore hard, "as if it were paint and not water": an unlit material receives no shadow, and the island's shadow on the lit floor under the shallows is what softened that edge — the same shadow whose loss lightened the shallows when the island's ground stopped casting (ADR-0046, option 2). Option 4 gave the slope its shading back but not the shadow, and the edge stayed hard.
A thirtieth of the frame is not worth the look of the shore, with the match holding sixty frames a second for ten minutes without it (ADR-0048).

### Consequences

What makes the shallows read as shallows is light the renderer works out — the island's shadow through the water — so a cheaper floor has to keep receiving it.
