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
Twelve waves are summed, as ocean shaders sum them (GPU Gems 1, chapter 1, "Effective Water Simulation from Physical Models"; Tessendorf, "Simulating Ocean Water"): the first as long as the configured wavelength, each next 1.18 times shorter and 0.82 times lower, so the water has waves of every size; each in its own direction within 60 degrees of a fixed wind, and from its own start; each at the speed deep water carries a wave of its length, ω = √(g k), slowed by the configured share, so that long waves overtake short ones and the pattern keeps changing; and each shaped exp(sin − 1), a narrow crest over a wide trough.
Slow noise bends the crests and raises and lowers the waves from place to place.
Their slopes, scaled by the configured steepness, tilt the normal in the world, which is then written in the tangent space of the fragment's geometry — so any mesh with a tangent frame agrees with any other. Since FR-MAP-280 made the water partly transparent, the slabs beyond the grid are drawn as rectangles built the same way as the surfaces, by their tops alone, rather than as RealityKit's box.
Waves in random phases add as the root of the sum of their squared weights, not as the sum, so the sum is turned back into standard units by the statistics of one wave exp(sin x − 1) over a turn — mean 0.466, deviation 0.302, slope 0.328 per unit — and the configured steepness is then the water's typical slope. Where the height stands 1.3 to 2.3 deviations above its mean, the colour is lifted towards white, by at most the configured strength. Divided by the sum of the weights instead, as first built, the twelve waves came out several times flatter than configured and never reached a crest.
The first version, on 2026-09-25, was three and then five sines of fixed lengths and speeds; the maintainer found them all of one size and standing still, which is what waves of one speed look like.
Because the waves are in world metres, every piece of the water — foam, open water, slab — shows the same waves at a join, and no seam appears.
The ripple reaches the shader as the material's one custom value: the longest wavelength, the share of deep water's speed, crest strength, steepness.
Where Metal or the function is not there, the water is drawn glossy and still.

### Consequences

- The shader runs over the largest surface in the frame; its cost is measured on the phone, not assumed. On 2026-09-25 the match ran at 715 frames in a ten-second run with 2 late, both at launch; the first frame came about half a second later than before the shader, which a second launch would tell apart from compiling it.
- The foam is drawn with the same shader; the crests do not show on near-white foam, the slopes do.
- The ground and the walls carry a tangent frame they do not use.
- The wave count, ratios, wind, spread and thresholds are constants in the shader, like the hole shader's, and wait with them for Q-280.
- The waves' turns are counted modulo one, so that the phase keeps its precision however long the session runs.
