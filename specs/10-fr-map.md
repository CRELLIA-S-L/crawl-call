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
code: [Sources/CrawlCall/Map/NavigationGraph.swift, Sources/CrawlCall/Map/World.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/Snake/Surfaces.swift]
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
code: [Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Config/MapFormat.swift, Sources/CrawlCall/Map/Setting.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/Config/Resource.swift, maps/blockout.map]
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
code: [Sources/CrawlCall/Setting/Scenery.swift, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/EntityName.swift]
tests: [Tests/CrawlCallTests/SurroundingsTests.swift]
created: 2026-09-24
```

The scenery of a setting **shall** take no part in movement, in what the bots see, in the navigation graph or in what is cut open for the snake.

**Rationale.** The arena is the game and the map's author designs it; a tree at the rim that blocked a bot's sight, or a shore the snake could crawl onto, would be play nobody put in the map.
A tree or a shrub that is to stop sight or movement is the map's module, not scenery, and says what it stops through its kit (FR-MAP-210).
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
code: [Sources/CrawlCall/Setting/FrameCoverage.swift, Sources/CrawlCall/Map/GroundRect.swift, Sources/CrawlCall/Setting/Scenery.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Config/Surroundings.swift, Sources/CrawlCall/Config/Interface.swift, Sources/CrawlCall/View/MatchHost.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Launch.swift]
tests: [Tests/CrawlCallTests/SurroundingsTests.swift]
created: 2026-09-24
```

While a match is running, the system **shall** fill every part of the frame the match camera can show — at any pitch FR-VIEW-010 allows, at any yaw, in any window FR-VIEW-210 allows, over any point the camera can look at — with the arena or the map's surroundings, leaving no part of it empty.

**Rationale.** Around the arena there is nothing today, drawn black on the phone and white in the simulator, and the frame shows it: at the arena's edge, and more of it when the head is on the balcony, a floor above the ground the rays then have further to fall to.
The world need not be endless, because the released game's camera angle is frozen (FR-VIEW-010) and only the free camera of debug mode, a testing tool, can see past a finite one; it has to be larger than all the match camera can show, and no larger.
At any yaw since 2026-09-25: the maintainer, turning the free camera, found the island at the very edge of the water on the camera's side, since the ground was sized for the one direction the match camera looks in; and the match camera may one day turn to follow the snake. A frame turned round the point looked at stays within a circle round it, so the ground is sized by the farthest corner of any frame, on every side (ADR-0041). It is still no larger than the frames it has to hold.
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
code: [Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Map/World.swift, Sources/CrawlCall/Launch.swift]
tests: [Tests/CrawlCallTests/FlightTests.swift]
created: 2026-09-25
```

If a flight of stairs a map draws would rise by more than the step height of the tuning configuration at any step, the system **shall** refuse the map, naming the line of the flight and the rise it would need.

**Rationale.** A step higher than the step height is one neither the snake nor a bot can climb (FR-MAP-025), so such a flight would join nothing; refusing it at load says so where the map is written, rather than leaving a floor nobody can reach.
With the shipped numbers — a floor of 3 m, a step of 0.4 m — a flight has at least eight steps.

## Ground, spawn points and outline

What the map's ground is, where the snake is born, how the setting's edge follows the map, and what each module stops (ADR-0034).
Settled by the maintainer on 2026-09-25: floor 0 is the ground, the map names the snake's spawn points, the map's edges are the edges of the island or whatever setting it stands in, and trees and shrubs are the map's modules.

### FR-MAP-170 — Floor 0 is the ground

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [IF-MAP-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/ScenePlan.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Map/Outline.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

The system **shall** take a map's floor 0 as the one at ground level, the floors numbered below it as underground and those above it as above ground.

**Rationale.** The maintainer, 2026-09-25, when basements came up: a floor below the ground is a basement, and the setting's ground has to be laid at one level whatever floors a map has below it. Until then the setting lay under a map's lowest floor, which a basement would have lifted the whole building above.

### FR-MAP-180 — The snake is born where the map says

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [IF-MAP-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Config/MapFormat.swift, Sources/CrawlCall/Game.swift, maps/blockout.map]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

When a match starts, the system **shall** place the snake's head at one of the spawn points the map names, chosen at random.

**Rationale.** The maintainer, 2026-09-25: where the snake is born is the map's to say, possibly in more than one place, one of them chosen at random. Until then it was born in the first walkable cell of the lowest floor, which a basement would have made the basement.
Each match is a new start, a restart included.

### FR-MAP-190 — A map without a spawn point is refused

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-MAP-180]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Launch.swift]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

If a map names no spawn point, or names one on a cell nothing can stand in — neither a surface nor a module that stops no movement — the system **shall** refuse the map, naming the refused spawn point's line where it has one.

**Rationale.** A snake born nowhere, or inside a wall, is a match that cannot be played; saying so where the map is written is cheaper than finding it on the phone.

### FR-MAP-200 — The setting's edge is the map's outline, rounded

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-MAP-120, FR-MAP-170]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/Outline.swift, Sources/CrawlCall/Map/GroundRect.swift, Sources/CrawlCall/Map/Setting.swift, Sources/CrawlCall/Map/DistanceField.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/Scenery.swift, Sources/CrawlCall/Setting/FrameCoverage.swift, Sources/CrawlCall/Config/Surroundings.swift]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

The system **shall** draw the edge of a map's setting along the outline of the map's floor 0, rounded so that no step of the grid shows in it and outside every cell of the map.

**Rationale.** The maintainer, 2026-09-25: maps are of any shape, not rectangles, and a map's edges are the edges of the island — or of whatever setting it stands in — rounded, so that the grid's staircase does not show.
Outside every cell, so that no cell anybody can stand on hangs over the water; the rounding is the drawing's, and where the snake and the bots may go is still the grid's.

### FR-MAP-210 — A kit says what each module stops

```yaml
status: implemented
verification: T
derives_from: [FR-MAP-100]
depends_on: [FR-MAP-020, FR-BOT-050]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/Kit.swift, Sources/CrawlCall/View/SceneBuilder.swift, Sources/CrawlCall/Config/Drawing.swift, config/kit/blockout/legend.json]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

Every module type of a kit **shall** declare whether it stops movement and whether it stops sight.

**Rationale.** The maintainer, 2026-09-25: trees and shrubs are modules of the map, with a different "permeability" — a shrub stops sight and not movement, a tree stops both — and trees will one day be destroyed, which FR-MAP-060 declares per module type as well.
Until then a module that was not walkable stopped both, and one that was walkable neither.

### FR-MAP-220 — A module stops what its type says

```yaml
status: implemented
verification: T
derives_from: [FR-MAP-210]
depends_on: [FR-MAP-020, FR-BOT-050, FR-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Map/NavigationGraph.swift, Sources/CrawlCall/Snake/Surfaces.swift, Sources/CrawlCall/Map/Sight.swift, Sources/CrawlCall/Map/ScenePlan.swift]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

The system **shall** let no movement through a module whose type stops movement, and no line of sight through one whose type stops sight.

**Rationale.** FR-MAP-210's declaration kept: movement is the snake's body (ADR-0021) and the bots' graph (FR-MAP-020), sight is the line test the bots see by (ADR-0019). Written apart from the declaration because the format takes one obligation to a requirement, and the two are built and tested apart.

### FR-MAP-230 — No ground is drawn where nothing stands

```yaml
status: superseded
superseded_by: FR-MAP-260
verification: T
derives_from: [FR-MAP-200]
depends_on: [FR-MAP-170]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/Passages.swift, Sources/CrawlCall/Map/Setting.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Map/Outline.swift, Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Launch.swift, maps/blockout.map]
tests: [Tests/CrawlCallTests/PassageTests.swift]
created: 2026-09-25
```

If the setting's edge would draw ground over a cell of floor 0 that holds no module, between two cells of floor 0 in its row or its column, the system **shall** refuse the map, naming the cell's line and column.

**Rationale.** The maintainer, 2026-09-25, after the snake ran into an invisible wall at the blockout's left edge: the edge FR-MAP-200 draws closes any gap in the map narrower than its margin and rounding, so an empty cell there looked like grass and could not be walked. Refused rather than taken for ground, by the maintainer's choice: taking it for ground would have the setting decide what the map is.
Between two cells of the map, because the edge also draws a strip of ground beyond the map's outermost cells, on purpose, and that strip has the map on one side only.

Superseded on 2026-09-25, the day it was written, by FR-MAP-260: the maintainer asked for one rule that names no kind of place, since each kind found — this one among them — was a case of the same thing, and the next would be one nobody had listed. Its case is among FR-MAP-260's tests.

### FR-MAP-240 — No passage narrower than the snake

```yaml
status: superseded
superseded_by: FR-MAP-260
verification: T
derives_from: [FR-MAP-220]
depends_on: [FR-SNAKE-010, IF-MAP-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/Passages.swift, Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Launch.swift, maps/blockout.map]
tests: [Tests/CrawlCallTests/PassageTests.swift]
created: 2026-09-25
```

If two things the snake's body cannot pass — modules that stop movement, and the side of a flight where it stands more than a step above the floor — stand closer together than the snake's body is wide, with nothing the body cannot pass between them, the system **shall** refuse the map, naming both cells.

**Rationale.** The maintainer, 2026-09-25: every passage a map shows should be wide enough for the snake. The body is wider than a cell (ADR-0021), so a gap of one cell between a tree and a wall looked like a way through and was none. The width is the tuning's body radius, twice, so a wider or narrower snake moves the limit with it.
Reworded on 2026-09-25, the day it was written, when the snake could not get between the blockout's flight and the wall beside it: the body meets a flight's side as a wall wherever a step stands more than a step above its feet (ADR-0033), and the first wording counted only modules that stop movement.

Superseded on 2026-09-25, the day it was written, by FR-MAP-260: the maintainer asked for one rule that names no kind of place, since each kind found — this one among them — was a case of the same thing, and the next would be one nobody had listed. Its case is among FR-MAP-260's tests.

### FR-MAP-250 — Nothing that stops movement stands at the map's edge

```yaml
status: superseded
superseded_by: FR-MAP-260
verification: T
derives_from: [FR-MAP-200]
depends_on: [FR-MAP-170, FR-MAP-220]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/Passages.swift, Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Launch.swift, maps/blockout.map]
tests: [Tests/CrawlCallTests/PassageTests.swift]
created: 2026-09-25
```

If a module that stops movement stands on a cell of floor 0 beside a cell that holds no module and has no floor below it, with a cell the snake can stand in beside it along that edge, the system **shall** refuse the map, naming the cell's line and column.

**Rationale.** The maintainer, 2026-09-25, after trees at the blockout's edge seemed to leave a way round them that the snake could not take. The setting's edge draws ground beyond the map's outermost cells (FR-MAP-200), and beside a tree it reads as a way round; the snake's head goes only where there are cells, so no width of that ground is a way round.
Only where a cell the snake can stand in lies beside it along the edge, because that is what leads the snake to it: a wall that runs along the edge has only wall beside it there. A cell with a floor below it is a basement's opening, and a wall beside one is a wall round a stairwell.

Superseded on 2026-09-25, the day it was written, by FR-MAP-260: the maintainer asked for one rule that names no kind of place, since each kind found — this one among them — was a case of the same thing, and the next would be one nobody had listed. Its case is among FR-MAP-260's tests.

### FR-MAP-260 — A map shows no way the snake cannot take

```yaml
status: implemented
verification: T
derives_from: [FR-MAP-200, FR-MAP-220]
depends_on: [FR-MAP-170, FR-SNAKE-010, IF-MAP-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/Passages.swift, Sources/CrawlCall/Map/Setting.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Launch.swift, maps/blockout.map]
tests: [Tests/CrawlCallTests/PassageTests.swift]
created: 2026-09-25
```

If the map, as drawn, shows the snake a way that its body cannot take, the system **shall** refuse the map, naming where that way is.

**Rationale.** The maintainer, 2026-09-25, after a day of finding such ways one kind at a time — ground drawn over an empty cell, a gap narrower than the snake, the side of a flight, a tree at the water's edge, a tree whose corner met the water's: each was a case of the same thing, and a rule that listed them would miss the next. So the rule names no kind of place, and the check behind it compares what the eye sees with where the snake can be (ADR-0035); the cases found are its tests.
"The snake's body" is the tuning's body radius and step height (IF-MAP-020): a wider snake, or a lower step, moves what counts as a way it cannot take.

### FR-MAP-270 — The ground goes on under the water

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-MAP-200, FR-MAP-140]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/Outline.swift, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/Scenery.swift, Sources/CrawlCall/Setting/SeaFloor.metal, Sources/CrawlCall/Config/GreenholmConfiguration.swift, Sources/CrawlCall/Config/Surroundings.swift, Sources/CrawlCall/Config/Geometry.swift, Sources/CrawlCall/Config/Resource.swift, config/setting/greenholm.json]
tests: [Tests/CrawlCallTests/SeaFloorTests.swift, Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

Where a map's setting ends its ground in water, the system **shall** draw a floor under the water that falls smoothly from just under the surface at the setting's edge to the depth the setting sets, coloured from the edge's colour towards the deep colour the setting sets as it falls.

**Rationale.** The maintainer, 2026-09-25, after shallows drawn as bands of colour on opaque water (FR-GREENHOLM-040): water one can partly see through, over a floor that rises to the shore, is shallow where it is shallow, without a step anywhere.
A rule of maps rather than of one setting, because every setting whose ground ends in water has the same edge (FR-MAP-200) and the same question of what lies under it; how far, how deep and in what colours is each setting's own.
Down to the edge of all the camera can show, like the water (FR-MAP-140): a floor that stopped short would leave nothing to be seen through the water at the frame's edge. The floor lies deeper than the water, so what the camera shows of it is worked out at its own depth, where every ray from the camera meets it further along than it met the water.
Judged on the phone. Seen only through water one can partly see through, FR-MAP-280.

### FR-MAP-280 — The water can be partly seen through

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-MAP-270]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/WaterRipple.metal, Sources/CrawlCall/Setting/Greenholm.swift, Sources/CrawlCall/Setting/Scenery.swift, Sources/CrawlCall/Config/GreenholmConfiguration.swift, config/setting/greenholm.json]
tests: [Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-25
```

Where a map's setting ends its ground in water, the system **shall** draw the water with the opacity the setting sets, casting no shadow.

**Rationale.** The maintainer, 2026-09-25, with FR-MAP-270, of which it was the second half until the checker had the two obligations split: the floor under the water is what makes the shallows, and water one cannot see through hides it.
Judged on the phone, and measured there in frames, because the water now blends with what is under it across most of the frame. How the opacity reaches the water's shader is ADR-0039.
No shadow since 2026-09-29, the maintainer's call on the phone: the floor is seen through the water, and the water's own shadow on it showed through as a toothed edge along the foam and darkened the shallows (ADR-0050).
The water beyond the island's grid, laid out as slabs, is drawn by its tops alone: a slab's sides show through water one can see through, as a line wherever two slabs meet.

### FR-MAP-290 — The treasure lies where the map says

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [IF-MAP-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-10-14
```

When a match starts, the system **shall** place the treasure in the cell the map names for it.

**Rationale.** Concept §6.4: one treasure for both squads, lying in a cell the map names. §11 says why the map and not the configuration: how long the second act runs is the distance from the treasure to the evacuation point, and whether the snake can get back in time is where it is born with respect to the treasure — three numbers a map is designed around, and tuning them anywhere but on the map tunes every map at once.
Where the snake is born needs nothing new for the same reason: FR-MAP-180 already puts it at a spawn point the map names, and "near the treasure but not on it" is where the map's author puts those spawn points.

### FR-MAP-300 — A map that does not name a treasure and an evacuation point is refused

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-MAP-290]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-10-14
```

If a map names no cell for the treasure or none for the evacuation point, or names one on a cell nothing can stand in — neither a surface nor a module that stops no movement — the system **shall** refuse the map, naming the refused cell's line where it has one.

**Rationale.** The same reasoning as FR-MAP-190, which refuses a map the snake cannot be born in: a match whose second act cannot happen is a match that ends on the timer, and saying so where the map is written is cheaper than finding it on the phone.
Asked of a map to be played, at launch, as the spawn points are; a map read for another purpose — a test of the parser, a tool — need name neither cell.
