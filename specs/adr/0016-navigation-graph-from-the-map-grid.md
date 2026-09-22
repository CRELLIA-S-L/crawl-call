# ADR-0016 — Navigation is a graph derived from the map grid; the snake is a character controller, not a pathfinder

- **Status:** accepted
- **Date:** 2026-09-22
- **Related requirements:** FR-SNAKE-010, FR-SNAKE-040, FR-SNAKE-050, FR-SNAKE-220, FR-MAP-020, FR-MAP-050, FR-BOT-115, FR-TOOL-030, FR-TOOL-040, FR-TOOL-080, FR-TOOL-100, INV-MAP-020

## Context and problem statement

The concept and the first decomposition assumed RealityKit 5's navigation mesh for both the bots' pathfinding and the snake's movement (concept §4, §10; ADR-0001 check 1).
The technical spike of 2026-09-22 (`materials/spike/README.md`) showed that `NavigationController` resolves a position to a polygon by its XZ column alone, taking the first polygon it finds and ignoring height: two points on the same floor, requested at y=0 and at y=3, return the same path, and which floor that path lies on depends on polygon order.
Neither layers nor geometry thickness change this, and the API offers no nearest-point query.
On a map with floors above floors — the map the concept is about — the built-in pathfinder cannot be used as it is.

## Considered options

1. Own polygon pathfinding over the navmesh RealityKit generates — nearest polygon by distance, A*, funnel — keeping the navmesh as the map's walkable model.
2. No navigation mesh at all: the bots path over a graph derived from the map's own grid — one node per walkable cell and floor, stairs and ramps as edges between floors — and the snake's head is a kinematic character controller steered by the player, which the map's geometry keeps on the floor and out of the walls.
3. SwiftGodot, whose navigation server has a height-aware closest-point query (the fallback ADR-0001 names).
4. Maps without vertical overlap.

## Decision outcome

Option 2, proposed by the maintainer.
The snake never needed a path: the player steers it (concept §3: swipes, a held direction; FR-VIEW-050), and "moves only on the navigation mesh" always meant "stays on walkable surfaces and does not pass through walls", which is what a character controller does — RealityKit's `CharacterControllerComponent` (iOS 15+) with slope and step limits and gravity, so ramps, stairs and drops come from geometry.
The bots do need paths, and the map is already a grid per floor (IF-MAP-010, ADR-0012): the grid is the graph.
A node carries its floor, so height is unambiguous by construction; a path between floors follows an explicit transition edge.
The graph is small — hundreds of nodes — deterministic, and testable without a device.

What the grid gives that the navmesh would have had to be argued into: the tail blocks a passage by marking the cells its segments occupy (FR-SNAKE-040); destruction changes a cell's passability and cost when its module changes state (FR-MAP-050, FR-BOT-100); the validator's connectivity, trap-corridor and blockable-stair checks (FR-TOOL-040) and the debug overlay (FR-TOOL-080) read the same structure.

Option 1 would have kept a dependency on the one part of RealityKit 5 the spike found untrustworthy and fixed it from outside.
Option 3 changes the whole stack for one query.
Option 4 gives up the balconies the game is about.

### Consequences

RealityKit's `NavigationMeshResource`, `NavigationComponent` and `NavigationController` are not used; `LowLevelMesh`, ECS, rendering and Foundation Models remain, so ADR-0001 stands with its first check redefined.
Grid resolution is a tuning number in the tuning configuration (IF-MAP-020); paths are smoothed by string-pulling over cell corners so that bots do not walk in staircases.
The snake's own head is kept out of its tail by collision shapes on the segments, not by the graph.
Tail continuity for the tube (FR-MAP-090) and the maximum drop (FR-SNAKE-220) are properties of the geometry and the controller's fall, not of any mesh.
