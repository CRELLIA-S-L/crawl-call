# Functional requirements — maps

Multi-level layouts with a navigation graph derived from the map grid, pre-destructed cover, what a map must contain for the snake.
Source: concept §7 (destructible cover), §11 (maps), §11.2 (method), §13 stage 2.
The map's text format is IF-MAP-010; the tuning configuration for destruction is IF-MAP-020.
That the load-bearing frame never breaks is INV-MAP-010; that destruction never disconnects floors is INV-MAP-020; that no existing map is reproduced is CON-MAP-010.
The tools that assemble, validate and render a map are in the TOOL area.
What stands around the arena — its setting — is in *Surroundings* below; a setting's own requirements are in the area of its name.

## Structure

### FR-MAP-010 — A map has more than one floor

```yaml
status: implemented
verification: I
derives_from: []
depends_on: [IF-MAP-010]
refines: []
conflicts_with: []
code: [maps/blockout.map]
tests: [Tests/CrawlCallTests/MapParserTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/SnakeTests.swift]
created: 2026-09-21
```

Every map **shall** contain at least two floors joined by at least one vertical transition the snake can traverse.

**Rationale.** Concept §3, §13 stage 2: multi-level maps are the thing verticality is measured on (H-020).
Checked by the validator (FR-TOOL-040).

### FR-MAP-025 — The snake and the bots agree on what is climbable

```yaml
status: partial
verification: T
derives_from: [FR-MAP-020]
depends_on: [FR-SNAKE-010, IF-MAP-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Surfaces.swift, Sources/CrawlCall/Map/NavigationGraph.swift]
tests: [Tests/CrawlCallTests/SnakeTests.swift, Tests/CrawlCallTests/FlightTests.swift]
created: 2026-09-22
```

The step height, slope angle and body radius that decide where the snake's head may go **shall** be the same values the navigation graph uses to decide where a bot may go, both read from the tuning configuration.

**Partial, and how.** The snake reads the step height, the slope angle and the body radius from the tuning configuration (`Surfaces`). Since 2026-09-25 the graph reads the step height too: a map's flights of stairs are steps (FR-MAP-150), the graph joins two cells only a step apart in height (FR-MAP-020), and a flight too steep for that step is refused at load (FR-MAP-160) — so on steps the two agree by construction, the same number deciding both (ADR-0033). The slope angle is still read by the snake alone, because no map has a slope for it to decide about.
Since ADR-0021 the body radius keeps the snake's body out of what the map places, and the graph still knows nothing of width: a gap of one cell between two walls, half a metre, is a path for a bot and not for a body 0.6 m across. The blockout has no such gap — its narrowest passage is 0.9 m — so the two do not yet disagree on any map that exists.

**Rationale.** Two models of the same map that disagree produce a map with two shapes: a step the snake climbs and the bots path around, or a ledge the bots walk off and the snake cannot follow.
The tail blocking a passage (FR-SNAKE-040) only means something if both sides agree the passage exists.
The spike keeps one constant for both, which is what this requires of the game; the values belong in configuration because they are tuning (concept §12).

### FR-MAP-020 — The navigation graph covers every walkable cell

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-TOOL-030]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/NavigationGraph.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/Snake/Surfaces.swift]
tests: [Tests/CrawlCallTests/NavigationGraphTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/MapParserTests.swift, Tests/CrawlCallTests/FlightTests.swift]
created: 2026-09-21
```

When a map is loaded, the system **shall** hold a navigation graph with one node for every cell and floor the map specification marks walkable, at the height of its walking surface, an edge between every two neighbouring nodes whose surfaces differ in height by no more than the step height of the tuning configuration, whichever floor each is on, and an edge for every transition between floors.

**Rationale.** The graph is the bots' model of the map (ADR-0016): a walkable cell outside it is a place no bot can go.
A node carries its floor, so a cell above a cell is never confused with it — the property RealityKit's navmesh queries turned out to lack.
Since 2026-09-25 a node carries the height of its surface as well: a step of a flight stands between two floors (FR-MAP-150), so the floor alone no longer says how high a cell is. An edge joins neighbours a step apart in height and no more, so the top step of a flight joins the floor above by the same rule that keeps a bot from stepping off the side of a tall step (ADR-0033).

## Destruction

### FR-MAP-030 — Destructible modules have three states

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [IF-MAP-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a destructible module's accumulated damage crosses a threshold of the tuning configuration for its module type, the system **shall** switch the module to the next of its states — intact, damaged, debris — never skipping one and never going back.

**Rationale.** Concept §7: pre-destructed states rather than physical simulation, because the navigation graph must follow every change and real physics is out of reach on a phone; and because pre-destruction is deterministic, so the bots can plan on it (ADR-0004).

### FR-MAP-040 — Debris stops blocking sight and fire

```yaml
status: deferred
verification: T
derives_from: [FR-MAP-030]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a module enters its debris state, the system **shall** stop it from blocking line of sight and line of fire.

**Rationale.** Concept §7: cover works both ways — the snake that breaks a wall loses the wall too, and a map ground to rubble is worse for everyone.
That is the natural arc from a hunt in a maze to an open slaughter.

### FR-MAP-050 — The navigation graph follows destruction

```yaml
status: deferred
verification: T
derives_from: [FR-MAP-030]
depends_on: [FR-MAP-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a module changes state, the system **shall** update the passability and cost of the graph cells the module occupies before the next deliberation slot is handed out.

**Rationale.** Concept §7: the navigation model needs updating on every geometry change; on a grid that is a cell update, not a rebuild (ADR-0016).
"Before the next slot" is the bound that keeps a bot from planning through a wall that is no longer there, or into one that is.

### FR-MAP-060 — What can and cannot be destroyed is declared per module type

```yaml
status: deferred
verification: I
derives_from: []
depends_on: [IF-MAP-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Every module type of the map kit **shall** be declared either destructible — cover, barricades, furniture, non-load-bearing partitions — or load-bearing — walls, stairs, floor slabs — and never both.

**Rationale.** Concept §7: everything that can be removed without changing the connectivity between floors is destructible; the frame that carries the verticality is not.
INV-MAP-010 is the promise the declaration serves.

## What a map holds for the snake

### FR-MAP-070 — Stairs the snake can block

```yaml
status: deferred
verification: I
derives_from: [FR-MAP-010]
depends_on: [FR-SNAKE-040]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Every map **shall** contain at least one stair narrow enough for the snake's body to make it impassable to bots.

**Rationale.** Concept §11.2's functional description of a map: "one stair the snake can block with its body".
A map without one has no use for FR-SNAKE-040.

### FR-MAP-080 — Trap corridors

```yaml
status: deferred
verification: I
derives_from: [FR-MAP-010]
depends_on: [FR-SNAKE-050]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Every map **shall** contain at least two corridors narrower than the trap width of the tuning configuration, in which a snake of the trap length can lock itself in.

**Rationale.** Concept §11.2: two narrow trap corridors; §12: the width at which the tail becomes a problem is one of the things only a human settles by crawling the map, which is why it is configuration.

### FR-MAP-090 — Every reachable surface is continuous for the tail

```yaml
status: implemented
verification: T
derives_from: [FR-MAP-020]
depends_on: [FR-SNAKE-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/ScenePlan.swift, Sources/CrawlCall/Config/Geometry.swift]
tests: [Tests/CrawlCallTests/ScenePlanTests.swift]
created: 2026-09-21
```

Every map **shall** present, along every walkable route, a continuous surface for the tail to rest on, with no gap wider than the tail-gap tolerance of the tuning configuration.

**Rationale.** Concept §11: "solid surfaces for the tail" is the first requirement a snake map has and a shooter map does not; the tolerance is what a jump across a gap needs; a drop is FR-SNAKE-220.

## Modular kits

### FR-MAP-100 — Maps are assembled from a modular kit

```yaml
status: implemented
verification: I
derives_from: []
depends_on: [IF-MAP-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/Kit.swift, ATTRIBUTION.md, Sources/CrawlCall/Config/Resource.swift, Sources/CrawlCall/Config/MapFormat.swift]
tests: [Tests/CrawlCallTests/MapParserTests.swift, Tests/CrawlCallTests/ScenePlanTests.swift]
created: 2026-09-21
```

Every map **shall** be assembled from modules of one kit listed in the attribution file.

**Rationale.** Concept §11.1: modular kits instead of ready maps — the layout is ours, the licence is clean; Kenney and Quaternius (CC0) for blockouts, Synty for quality.
The trap the concept names: an open engine is not free content.
That a listed kit's licence permits commercial redistribution is CON-PUB-030's obligation, not restated here.

### FR-MAP-110 — A cell can declare that it has no floor

```yaml
status: draft
verification: T
derives_from: [IF-MAP-010]
depends_on: [FR-TOOL-020, FR-MAP-020]
refines: [FR-TOOL-020]
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

When a map declares a cell to have no floor, the system **shall** place no floor module there and hold no navigation node for it, whatever module stands on the cell.

**Rationale.** The floor under a standing module is implied (FR-TOOL-020) because a cell holds one module and a person should not have to spell out the obvious. A hole is the case where the obvious is wrong, and it is worth the exception because it is tactical: a gap under a crate is a way down the snake can take and a bot cannot, a shaft behind a partition is a route that exists only while the partition stands, and both stop being possible the moment "something stands here" silently means "the floor is here".
Marked `draft` because what it does not yet settle is how a map says it — a header list of cells like the transitions, a legend character that means the absence of a floor, or a second grid per floor — and that choice belongs to the maintainer, not to the first person who needs a hole.
The graph half is not decoration: a hole nobody can path through is a hole the bots walk over.

## Surroundings

What stands around the arena is a setting (glossary): the map names it, the game draws it, and play never touches it.
Each setting's own requirements are an area of its name; the first is Greenholm (`specs/10-fr-greenholm.md`).
The plan these were written from, with what the match camera can show and how it is derived, is `materials/plans/surroundings.md`.

### FR-MAP-120 — A map names its setting

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [IF-MAP-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Config/MapFormat.swift, Sources/CrawlCall/Setting/Setting.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/Config/Resource.swift, maps/blockout.map]
tests: [Tests/CrawlCallTests/MapParserTests.swift, Tests/CrawlCallTests/SurroundingsTests.swift]
created: 2026-09-24
```

A map **shall** name the setting its arena stands in, from the settings the game provides.

**Rationale.** On 2026-09-24 the maintainer asked for a world around the arena — a sky, the space beyond the map, vegetation, birds — and decided that settings will vary: a first island, later a crater, a spaceship, a forest clearing, a closed building.
Named by the map, the way the kit is (FR-MAP-100), so that a new setting is a new family beside the others and never a change to them, and so that one layout can stand in more than one setting without being copied.

### FR-MAP-130 — Scenery takes no part in play

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-MAP-120]
refines: [FR-MAP-020, FR-BOT-050, FR-VIEW-150]
conflicts_with: []
code: [Sources/CrawlCall/Setting/Setting.swift, Sources/CrawlCall/Setting/Scenery.swift, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/EntityName.swift]
tests: [Tests/CrawlCallTests/SurroundingsTests.swift]
created: 2026-09-24
```

The scenery of a setting **shall** take no part in movement, in what the bots see, in the navigation graph or in what is cut open for the snake.

**Rationale.** The arena is the game and the map's author designs it; a tree at the rim that blocked a bot's sight, or a shore the snake could crawl onto, would be play nobody put in the map.
The four are one obligation — scenery is for the eye — and the list says what play is, so that "no part" can be checked: a test finds the same pieces and the same navigation graph for one map read on two different settings.
Kept out of what is cut open because FR-VIEW-150 is paid for every frame over every piece it considers, and scenery between the camera and the arena is settled where it is placed, not by cutting it; how is the setting's decision record's.

### FR-MAP-140 — The setting covers all the match camera can show

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-MAP-120, FR-VIEW-010, FR-VIEW-020, FR-VIEW-210, IF-VIEW-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Setting/FrameCoverage.swift, Sources/CrawlCall/Setting/Scenery.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/Surroundings.swift, Sources/CrawlCall/Config/Interface.swift, Sources/CrawlCall/View/MatchHost.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Launch.swift]
tests: [Tests/CrawlCallTests/SurroundingsTests.swift]
created: 2026-09-24
```

While a match is running, the system **shall** fill every part of the frame the match camera can show — at any pitch FR-VIEW-010 allows, in any window FR-VIEW-210 allows, over any point the camera can look at — with the arena or the map's surroundings, leaving no part of it empty.

**Rationale.** Around the arena there is nothing today, drawn black on the phone and white in the simulator, and the frame shows it: at the arena's edge, and more of it when the head is on the balcony, a floor above the ground the rays then have further to fall to.
The world need not be endless, because the released game's camera angle is frozen (FR-VIEW-010) and only the free camera of debug mode, a testing tool, can see past a finite one; it has to be larger than all the match camera can show, and no larger.
How much that is follows from the camera, the map and the window — the distance scales with the arena, and the span across with the window's shape, which on an iPad is whatever the player gives it — so it is computed from them, never written down as a number, and a test computes it for the whole range.
The sky is not part of it: with the shipped field of view of 50 degrees, the top of the frame looks 25 degrees or more below the horizon at every pitch FR-VIEW-010 allows.

## Stairs

A flight of stairs is drawn in a map as a run of arrows, each a step, rising the way they point (IF-MAP-010, ADR-0033).
It replaced on 2026-09-25 the stair that went straight up inside one cell, which looked and felt wrong; a way that goes straight up may come back for towers and lookouts (Q-330).

### FR-MAP-150 — A flight of stairs joins two floors

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [IF-MAP-010, FR-MAP-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Config/MapFormat.swift, Sources/CrawlCall/Map/Kit.swift, Sources/CrawlCall/Map/ScenePlan.swift, Sources/CrawlCall/Map/NavigationGraph.swift, Sources/CrawlCall/Snake/Surfaces.swift, Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Squads.swift, Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Game.swift, maps/blockout.map, config/kit/blockout/legend.json]
tests: [Tests/CrawlCallTests/FlightTests.swift, Tests/CrawlCallTests/MapParserTests.swift, Tests/CrawlCallTests/SnakeTests.swift]
created: 2026-09-25
```

When a map draws a flight of stairs on a floor, the system **shall** raise its steps in equal rises from that floor's surface to the surface of the floor above, the top step level with the cell beyond it on that floor.

**Rationale.** The maintainer, 2026-09-25: the stair that went straight up in one cell looked and felt wrong, and an ordinary flight of steps replaces it (ADR-0033).
Equal rises because a flight is walked by rhythm, and the top step level with the floor beyond so that the last step is onto the floor, not up to it.

### FR-MAP-160 — A flight too steep to climb is refused

```yaml
status: implemented
verification: T
derives_from: [FR-MAP-025]
depends_on: [FR-MAP-150, IF-MAP-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Launch.swift]
tests: [Tests/CrawlCallTests/FlightTests.swift]
created: 2026-09-25
```

If a flight of stairs a map draws would rise by more than the step height of the tuning configuration at any step, the system **shall** refuse the map, naming the line of the flight and the rise it would need.

**Rationale.** A step higher than the step height is one neither the snake nor a bot can climb (FR-MAP-025), so such a flight would join nothing; refusing it at load says so where the map is written, rather than leaving a floor nobody can reach.
With the shipped numbers — a floor of 3 m, a step of 0.4 m — a flight has at least eight steps.
