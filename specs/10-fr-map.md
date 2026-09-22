# Functional requirements — maps

Multi-level layouts on a navigation mesh, pre-destructed cover, what a map must contain for the snake.
Source: concept §7 (destructible cover), §11 (maps), §11.2 (method), §13 stage 2.
The map's text format is IF-MAP-010; the tuning configuration for destruction is IF-MAP-020.
That the load-bearing frame never breaks is INV-MAP-010; that destruction never disconnects floors is INV-MAP-020; that no existing map is reproduced is CON-MAP-010.
The tools that assemble, validate and render a map are in the TOOL area.

## Structure

### FR-MAP-010 — A map has more than one floor

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

Every map **shall** contain at least two floors joined by at least one vertical transition the snake can traverse.

**Rationale.** Concept §3, §13 stage 2: multi-level maps are the thing verticality is measured on (H-020).
Checked by the validator (FR-TOOL-040).

### FR-MAP-020 — The navigation mesh covers every walkable surface

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-TOOL-030]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a map is loaded, the system **shall** have a navigation mesh that covers every surface the map specification marks walkable, including every vertical transition.

**Rationale.** Concept §10: the navmesh is the foundation for both the bots and the snake's movement; a walkable spot outside it is a place nobody can go.

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

**Rationale.** Concept §7: pre-destructed states rather than physical simulation, because the navmesh must be rebuilt on every change and real physics is out of reach on a phone; and because pre-destruction is deterministic, so the bots can plan on it (ADR-0004).

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

### FR-MAP-050 — The navigation mesh follows destruction

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

When a module changes state, the system **shall** update the navigation mesh to the module's new footprint before the next deliberation slot is handed out.

**Rationale.** Concept §7: the navmesh needs rebuilding on every geometry change.
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

**Rationale.** Concept §7: everything that can be removed without changing the navmesh's connectivity between floors is destructible; the frame that carries the verticality is not.
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

Every map **shall** present, along every navigation-mesh path, a continuous surface for the tail to rest on, with no gap wider than the tail-gap tolerance of the tuning configuration.

**Rationale.** Concept §11: "solid surfaces for the tail" is the first requirement a snake map has and a shooter map does not; the tolerance is what a jump across a gap needs; a drop is FR-SNAKE-220.

## Modular kits

### FR-MAP-100 — Maps are assembled from a modular kit

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

Every map **shall** be assembled from modules of one kit listed in the attribution file.

**Rationale.** Concept §11.1: modular kits instead of ready maps — the layout is ours, the licence is clean; Kenney and Quaternius (CC0) for blockouts, Synty for quality.
The trap the concept names: an open engine is not free content.
That a listed kit's licence permits commercial redistribution is CON-PUB-030's obligation, not restated here.
