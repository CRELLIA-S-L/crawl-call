# Functional requirements — Greenholm

The first setting (FR-MAP-120): the arena on a small grassy island in open water, under a daylight sky.
What every setting must do — be named by the map, stay out of play, cover all the match camera can show — is in the MAP area, *Surroundings*; this area holds what makes the setting Greenholm.
Source: the maintainer, 2026-09-24; the plan is `materials/plans/surroundings.md`.

### FR-GREENHOLM-010 — The Greenholm setting

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-MAP-120, FR-MAP-130, FR-MAP-140]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Config/Surroundings.swift, Sources/CrawlCall/CrawlCallApp.swift, config/setting/greenholm.json, Sources/CrawlCall/Setting/Outline.swift]
tests: [Tests/CrawlCallTests/SurroundingsTests.swift, Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-24
```

The system **shall** provide the Greenholm setting: the map's ground as a grassy island, its edge a shore with open water beyond it.

**Rationale.** The maintainer chose an island for the first setting on 2026-09-24, having had the same idea independently.
An island hides the edge of a finite world by being an island: RealityKit in the iOS 27.0 SDK has no fog or haze to fade one out, and water reaching as far as FR-MAP-140 asks is a single surface, where a forest or a city reaching as far would be thousands of parts.
Judged on the phone, because whether it reads as an island in daylight is what the eye decides.
Rewritten on 2026-09-25, when the maintainer decided that the map's edges are the island's edges (FR-MAP-200): the island is no longer scenery round a rectangular arena but the map's own ground, and trees and shrubs are the map's modules, which stop sight or movement as their kit says (FR-MAP-210), not a ring of scenery.

### FR-GREENHOLM-020 — Greenholm has a daylight sky

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-GREENHOLM-010, FR-VIEW-130]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/Surroundings.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/SurroundingsTests.swift]
created: 2026-09-24
```

Where a map's setting is Greenholm, the system **shall** draw a daylight sky above it, leaving the scene lit as FR-VIEW-130 asks.

**Rationale.** The match camera never shows the sky (FR-MAP-140), so to a match a sky is a risk before it is a picture: it must not become a second light or dim the ambient, which is FR-VIEW-130's measure.
Worded as agreed on 2026-09-24 it said the sky "lights the scene"; building it showed that the lighting FR-VIEW-130 asked for — one sun, and a flat ambient every model receives explicitly — is best left as it is, and the frame with the sky and without it came out identical in every pixel sampled (ADR-0031). So the sky is drawn, and the scene is left lit as before.
Seen as a sky only through the free camera of debug mode.
On the phone, 2026-09-25, the free camera showed the sky a pale grey-blue: the picture is drawn, and RealityKit's default tone mapping, which runs over the whole frame, washes its blue towards grey. The maintainer left it as it is for now; Q-350 holds the measurements and the ways to change it.

### FR-GREENHOLM-030 — Birds cross Greenholm's sky

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-GREENHOLM-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Setting/Birds.swift, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/Surroundings.swift, Sources/CrawlCall/Config/EntityName.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/SurroundingsTests.swift]
created: 2026-09-24
```

Where a map's setting is Greenholm, the system **shall** fly birds across the sky over the arena at intervals the setting's configuration sets.

**Rationale.** The maintainer asked for birds on 2026-09-24; a world where something moves on its own is a world and not a backdrop.
Over the arena, low enough to cross the match frame, since the sky itself is never in it.
At intervals from configuration, because how often is tuned by eye, and a number in code would be a magic number (ART-070).

### FR-GREENHOLM-040 — Greenholm's water is shallow at the shore

```yaml
status: superseded
superseded_by: FR-MAP-270
verification: D
derives_from: []
depends_on: [FR-GREENHOLM-010, FR-MAP-200]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/GreenholmConfiguration.swift, config/setting/greenholm.json]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

Where a map's setting is Greenholm, the system **shall** draw the water beyond the shore in bands along the island's edge, the first the shallows colour and each further one a step nearer the water's colour, out to the width the setting's configuration sets, and the water's colour beyond them.

**Rationale.** The maintainer, 2026-09-25: the water is to be a little prettier, and shallows at the shore were the first of the four ways put to them.
In steps rather than a smooth fade, because the island is a diorama of flat, rounded pieces and the water is built the way its shore is — as surfaces cut along the edge's distance field (FR-MAP-200) — so a band is one more such surface and costs nothing a frame.
Judged on the phone, because whether it reads as shallow water is what the eye decides; the maintainer found it good on 2026-09-25 at three bands over 2.4 m.
Superseded on 2026-09-25, the day it was written, by FR-MAP-270: the maintainer asked for the shallows to be a sea floor rising to the shore under water one can partly see through, rather than bands of colour, and for that to be a rule of every map whose setting ends in water rather than of Greenholm alone.

### FR-GREENHOLM-050 — Foam lines Greenholm's shore

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-GREENHOLM-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/GreenholmConfiguration.swift, config/setting/greenholm.json]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

Where a map's setting is Greenholm, the system **shall** draw a band of foam on the water along the shore, as wide and of the colour the setting's configuration sets.

**Rationale.** The maintainer, 2026-09-25: the second of the four ways to make the water prettier. A pale rim where water meets sand is how a diorama draws a shore, and it separates the sand from the pale shallows, which are close to it in brightness.
A band of the same kind as the shallows' (FR-GREENHOLM-040), for the same reason: a surface cut along the edge, costing nothing a frame. Still, not moving; whether it moves is for the ripple.
Judged on the phone: on 2026-09-25, at 0.3 m and near white, it barely parted from the pale sand, and the maintainer left it as it is for now.
The clause that had the shallows begin where the foam ends went with the shallows' bands, when FR-MAP-270 put a floor under the water in their place on 2026-09-25; the floor's slope begins at the shore, under the foam.

### FR-GREENHOLM-060 — Greenholm's water is glossy

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-GREENHOLM-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/Scenery.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/GreenholmConfiguration.swift, config/setting/greenholm.json]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

Where a map's setting is Greenholm, the system **shall** draw the water, its foam and its shallows included, with the roughness and the strength of reflection the setting's configuration sets, while the island's ground stays matt.

**Rationale.** The maintainer, 2026-09-25: the third of the four ways to make the water prettier. Water that catches the sun reads as water; matt, it reads as blue ground.
A number from configuration, because how glossy is judged by eye (ART-070); the ground keeps the matt of the rest of the scenery, since FR-VIEW-130 has the arena lit as bright daylight and a glossy lawn would glare.
Judged on the phone: on 2026-09-25, at 0.2, the screenshot showed the water much as it was matt — a smooth surface reflects what is above it, the ambient light above it is flat (FR-VIEW-130), and the sun's highlight falls outside the match frame at its pitch. The maintainer kept it and went on to the ripple (FR-GREENHOLM-070), whose glints do not depend on the sun. Once the waves had volume the maintainer found the water too pale and asked for its reflection to be weaker, and the strength of reflection joined the roughness in configuration.

### FR-GREENHOLM-070 — Waves move across Greenholm's water

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-GREENHOLM-060]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Setting/WaterRipple.metal, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/Scenery.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/GreenholmConfiguration.swift, Sources/CrawlCall/Config/Resource.swift, Sources/CrawlCall/Config/Surroundings.swift, config/setting/greenholm.json]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

Where a map's setting is Greenholm, the system **shall** draw waves of many lengths that move continuously across the water, each faster the longer it is, their slopes lit by the sun and their crests paler, without a seam where one piece of the water meets another, at the longest length, speed, steepness and crest strength the setting's configuration sets.

**Rationale.** The maintainer, 2026-09-25: the fourth of the four ways to make the water prettier, and the one that makes it move. The gloss alone (FR-GREENHOLM-060) showed little, because the light above the water is flat. Pale glints drawn in the water's colour came first, and on the phone they read as white dots: the maintainer found the waves had no volume, which is what the sun on their slopes gives them. With volume, they found the waves all of one size and standing still: of many lengths, each faster the longer it is, is how water moves, and how ocean shaders are built (ADR-0038).
Without a seam, because the water is laid in bands along the shore and in slabs beyond them, and a pattern laid in each piece's own space would break at every join; ADR-0038 says how.
Judged on the phone, and measured there in frames, because the water is the largest surface in the frame and the shader runs over all of it.
