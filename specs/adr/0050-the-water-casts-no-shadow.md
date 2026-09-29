# ADR-0050 — The water casts no shadow

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-MAP-280, FR-MAP-270, FR-VIEW-130

## Context and problem statement

On 2026-09-29 the maintainer found the water's edge along the foam toothed on the phone: a row of small wedges, a few centimetres apart, that changed as the camera turned.
Trials on the phone, each changing one thing, narrowed it down. The teeth stayed with the shore's wall gone and with the foam gone; they went with the water near the island gone, and with that water drawn opaque — unlit or with its waves.
So they showed only where the floor under the water was seen through it.

The scenery's models were given no `DynamicLightShadowComponent`, and a model without one casts the sun's shadow, the transparent water with the rest.
The water cast its shadow onto the floor 0.05 m below it (FR-MAP-270), and the edge of that shadow was what showed through the water: with the shadow taken off, and nothing else changed, the teeth went. Why the edge was toothed and changed with the camera was not measured; a shadow map's texels and cascades, which follow the camera, fit what was seen.

## Considered options

1. The water casts no shadow — the band near the island and the slabs beyond it alike.
2. Only the band near the island casts none.
3. The shadow kept, its edge softened by a larger depth bias or a finer shadow map.

## Decision outcome

Option 1. Taken off on the phone, the teeth went, and the water turned lighter and bluer: its own shadow had darkened the whole floor under it, and the colour the water had been judged by carried that shadow in it. The maintainer judged the lighter water better (2026-09-29).
Option 2 would leave the floor beyond the grid in the water's shadow and the floor within it out of it, a seam where the two meet. Option 3 treats the edge and keeps the shadow of something light passes through.
The island's ground and trees still cast their shadows onto the floor under the shallows, which is what ADR-0049 keeps.

### Consequences

Anything drawn transparent over a lit surface has to be kept from casting a shadow on it, or it shows its own shadow's edge through itself.
The shadow pass has the water's triangles to draw no longer.
