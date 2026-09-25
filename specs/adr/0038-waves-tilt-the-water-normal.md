# ADR-0038 — Waves on the water tilt its normal, and their crests are drawn in its colour

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-GREENHOLM-070, FR-GREENHOLM-060, FR-GREENHOLM-040, FR-VIEW-130

## Context and problem statement

The maintainer asked for a light ripple on Greenholm's water.
The water is several pieces: the foam and the shallows' bands and the open water near the island, which are surfaces cut along the edge's distance field (FR-MAP-200), and up to four slabs beyond them out to the edge of what the camera shows (FR-MAP-140).
Those surfaces were built from positions and normals only (`SceneryBuilder.meshResource`); the slabs are RealityKit's generated box, which carries texture coordinates, tangents and bitangents, checked on the Mac on 2026-09-25.
A RealityKit surface shader sets a normal in tangent space (`set_normal`, RealityKitSurfaceShader.h, iOS 27.0 SDK), which means nothing on a mesh without tangents.
And the gloss FR-GREENHOLM-060 asked for showed little on the phone: the light above the water is flat (FR-VIEW-130).

## Considered options

1. Waves in the normals: a tangent frame added to every surface of the island, a normal tilted by the shader, the sun and the gloss doing the rest.
2. Glints in the colour only: the shader lifts the water's own colour towards white where crossing waves run high.
3. A moving texture of glints: an image scrolled across the water.
4. Waves in the geometry: vertices moved by a geometry modifier.

## Decision outcome

Options 1 and 2 together.
Option 2 was built first, alone, to spare the meshes; on the phone on 2026-09-25 its glints read as white dots on flat water, and the maintainer named what was missing: the waves had no volume.
Volume is light falling differently on a slope, and only a tilted normal gives that, so option 1 was added, with option 2 kept, weaker, for the crests.
Option 3 needs texture coordinates the island's surfaces do not have and an image nobody has drawn; option 4 needs a dense mesh, where the water is long strips and slabs of twelve triangles.

### How it works

Every surface `SceneryBuilder.meshResource` builds carries a tangent frame at each vertex: x flattened onto the surface, or z where the surface faces along x, and the bitangent at right angles to both.
`crawlCallWater` in `WaterRipple.metal` takes the water's colour and roughness from its material, as the hole shader does (ADR-0020).
Three sine waves cross the ground at odd angles, lengths and speeds, in world metres divided by the configured wavelength and moving at the configured speed.
Their slopes, scaled by the configured steepness, tilt the normal in the world, which is then written in the tangent space of the fragment's geometry — so the generated slabs and the built surfaces agree.
Where the waves' mean rises from 0.45 to 0.8 the colour is lifted towards white, by at most the configured strength.
Because the waves are in world metres, every piece of the water — band, open water, slab — shows the same waves at a join, and no seam appears.
The ripple reaches the shader as the material's one custom value: wavelength, speed, crest strength, steepness.
Where Metal or the function is not there, the water is drawn glossy and still.

### Consequences

- The shader runs over the largest surface in the frame; its cost is measured on the phone, not assumed. On 2026-09-25 the match ran at 715 frames in ten seconds with 2 late, both at launch; the first frame came about half a second later than before the shader, which a second launch would tell apart from compiling it.
- The foam is drawn with the same shader; the crests do not show on near-white foam, the slopes do.
- The ground and the walls carry a tangent frame they do not use.
- The wave directions, ratios and thresholds are constants in the shader, like the hole shader's, and wait with them for Q-280.
