# ADR-0039 — The water's opacity reaches its shader through the clearcoat's roughness

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-MAP-280, FR-MAP-270, FR-GREENHOLM-070

## Context and problem statement

FR-MAP-280 has the water drawn at an opacity its setting sets.
The water is a custom material with a surface shader (ADR-0038), and a custom material's opacity is given by its blending: `CustomMaterial.blending = .transparent(opacity:)`.
Probed on the iOS 27.0 simulator on 2026-09-25, a custom material made from a physically based one drops that opacity: given 0.6 as a float literal or as `Opacity(scale: 0.6)`, before or after it is made, its blending reads back `transparent` at a scale of 1.0; the same call on a physically based material reads back 0.6, and `Opacity(scale: 0.6)` on its own holds 0.6.
Whether the renderer sees 1.0 as well is not visible from the probe; a test that relied on reading it back failed.
The hole shader beside the modules had met the same wall from the other side: it sets its material transparent at 1.0 and gives each fragment its opacity itself (ADR-0020).
So the water's shader has to set its own opacity, and has to be told what it is. The one four-component value a custom material carries is taken by the waves (ADR-0038).

## Considered options

1. The material's opacity scale, `opacity_scale()` — lost as described.
2. Pack the opacity into the custom value beside a wave number, as a whole part and a fraction.
3. The emissive colour, which the water does not use — it is converted to linear light on the way, 0.6 arriving as 0.3185, probed the same day.
4. The clearcoat's roughness, which the water does not use — a plain number, read by `clearcoat_roughness_scale()`.
5. A texture carrying the opacity.

## Decision outcome

Option 4.
It arrives as it was set, it needs no packing, and the water has no clearcoat for it to mean anything else: the material's clearcoat is set to 0, and the shader sets the fragment's clearcoat to 0 as well.
Option 2 works and hides two numbers in one; option 5 is a resource for one number.

### How it works

`SceneryBuilder.water` makes the water transparent at 1.0, sets its clearcoat to 0 and its clearcoat's roughness to the setting's water opacity.
`crawlCallWater` sets the fragment's opacity to that roughness, clamped to 0…1, and its clearcoat to 0.
Where Metal or the function is not there, the water is a physically based material, transparent at the setting's opacity through its own blending, which that material keeps.

### Consequences

- A test reads the opacity back from the clearcoat's roughness, where it is kept, not from the blending, which reads 1.0.
- If a later SDK keeps a custom material's opacity, option 1 becomes the plain way again, and this decision is the one to revisit.
- The clearcoat's roughness means something other than its name on this one material; the code says so where it is set and where it is read.
