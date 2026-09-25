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
code: [Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Config/Surroundings.swift, Sources/CrawlCall/Map/ScenePlan.swift, Sources/CrawlCall/CrawlCallApp.swift, config/setting/greenholm.json]
tests: [Tests/CrawlCallTests/SurroundingsTests.swift]
created: 2026-09-24
```

The system **shall** provide the Greenholm setting: the arena on a grassy island ringed by trees and shrubs, with a shore and open water beyond it.

**Rationale.** The maintainer chose an island for the first setting on 2026-09-24, having had the same idea independently.
An island hides the edge of a finite world by being an island: RealityKit in the iOS 27.0 SDK has no fog or haze to fade one out, and water reaching as far as FR-MAP-140 asks is a single surface, where a forest or a city reaching as far would be thousands of parts.
Judged on the phone, because whether it reads as an island in daylight is what the eye decides.

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
