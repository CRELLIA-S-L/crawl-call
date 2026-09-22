# Functional requirements — maps

Multi-level layouts with a navigation graph derived from the map grid, pre-destructed cover, what a map must contain for the snake.
Source: concept §7 (destructible cover), §11 (maps), §11.2 (method), §13 stage 2.
The map's text format is IF-MAP-010; the tuning configuration for destruction is IF-MAP-020.
That the load-bearing frame never breaks is INV-MAP-010; that destruction never disconnects floors is INV-MAP-020; that no existing map is reproduced is CON-MAP-010.
The tools that assemble, validate and render a map are in the TOOL area.

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
tests: [Tests/CrawlCallTests/MapParserTests.swift, Tests/CrawlCallTests/LaunchTests.swift]
created: 2026-09-21
```

Every map **shall** contain at least two floors joined by at least one vertical transition the snake can traverse.

**Rationale.** Concept §3, §13 stage 2: multi-level maps are the thing verticality is measured on (H-020).
Checked by the validator (FR-TOOL-040).

### FR-MAP-025 — The snake and the bots agree on what is climbable

```yaml
status: deferred
verification: T
derives_from: [FR-MAP-020]
depends_on: [FR-SNAKE-010, IF-MAP-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

The step height, slope angle and body radius that decide where the snake's head may go **shall** be the same values the navigation graph uses to decide where a bot may go, both read from the tuning configuration.

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
code: [Sources/CrawlCall/Map/NavigationGraph.swift, Sources/CrawlCall/Launch.swift]
tests: [Tests/CrawlCallTests/NavigationGraphTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/MapParserTests.swift]
created: 2026-09-21
```

When a map is loaded, the system **shall** hold a navigation graph with one node for every cell and floor the map specification marks walkable and an edge for every transition between floors.

**Rationale.** The graph is the bots' model of the map (ADR-0016): a walkable cell outside it is a place no bot can go.
A node carries its floor, so a cell above a cell is never confused with it — the property RealityKit's navmesh queries turned out to lack.

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
status: deferred
verification: T
derives_from: [FR-MAP-020]
depends_on: [FR-SNAKE-020]
refines: []
conflicts_with: []
code: []
tests: []
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
code: [Sources/CrawlCall/Map/Kit.swift, ATTRIBUTION.md]
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
