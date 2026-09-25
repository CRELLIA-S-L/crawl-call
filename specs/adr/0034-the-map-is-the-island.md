# ADR-0034 — The map is the island: its outline, rounded, is the setting's edge, and its modules say what they stop

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-MAP-170, FR-MAP-180, FR-MAP-190, FR-MAP-200, FR-MAP-210, FR-MAP-220, FR-GREENHOLM-010, IF-GREENHOLM-010, IF-MAP-010, FR-TOOL-020, FR-MAP-130, FR-MAP-140

## Context and problem statement

Until 2026-09-25 the island was scenery round a rectangular arena: an ellipse of grass round the arena's bounding box, a ring of trees and shrubs on it, and water beyond (ADR-0031).
The maintainer then settled four things: maps are of any shape, and a map's edges are the island's — or whatever setting's — edges, rounded so that the grid's steps do not show; floor 0 is the ground, and floors below it are basements; the map names where the snake is born, possibly in several places, one chosen at random; and trees and shrubs are modules of the map, a shrub stopping sight and not movement, a tree stopping both, trees to be destroyed one day.
A basement also showed a fault of the old island: its grass and its water were whole sheets under the arena, and a floor below the ground would have been hidden under both.

## Considered options

For the edge:

1. An outline traced along the cells and smoothed as a polygon — offset curves, spline fitting — then triangulated.
2. A signed distance to the edge over a fine grid, the edge where it crosses zero, and surfaces cut from it by marching squares.

For what a module stops:

1. Keep "walkable" as the only property: what is not walkable stops everything.
2. Each module type declares what it stops, movement and sight apart.

## Decision outcome

Option 2 for the edge, option 2 for the modules.
A polygon traced along the cells and offset, rounded and triangulated with the map's own cells as holes and basements as more holes is the harder road, and brittle where the outline touches itself; a distance field answers every one of those at once, one sample at a time, and marching squares places the edge between samples by their values, so it is smooth to a fraction of the grid's step. The modules' option 1 cannot say a shrub.

### How it works

**Floor 0 is the ground** (FR-MAP-170). The setting's ground is laid just under floor 0's walking surface, 1 cm, whatever floors lie below it: the map's own ground is cells drawn one by one, and laid a slab lower, as it first was, the island showed between them as a dark line along every cell. A plan with no floor 0 falls back to its lowest floor.

**The edge** (FR-MAP-200). `Outline` samples the ground every 5 cm over the map's floor-0 cells and a reach beyond them. The cells are grown by the margin and by the rounding radius, and what is grown is then shrunk by the rounding: the outline grown by the margin, with its convex corners rounded by the margin and its hollows filled and rounded by the rounding — on the shipped numbers 0.5 m and 1 m, so that a gap of a cell or two closes and a bay of several cells stays a bay. Every step is a threshold on a distance, computed exactly by the Euclidean distance transform of Felzenszwalb and Huttenlocher (*Distance Transforms of Sampled Functions*, 2012), in time linear in the samples. The result is a signed distance to the edge, positive inside. Measured on samples, it can fall short of the margin by about two steps of the grid, so the edge lies at least 0.4 m outside every cell.

**Surfaces from the field.** Grass at the ground where the distance is not negative; a wall from the grass down to the shore along where it is zero; the shore's surface where it is not below minus the shore's width; a wall from there to below the water; and the water where it is below minus the shore's width, up to the grid's edge. A square of samples wholly inside is part of a strip along its row; a square the edge crosses contributes the part inside it, a polygon on its boundary and so convex, fanned into triangles. The walls stand along the segments where a square's inside polygon runs between two crossings, facing where the field falls. The rest of the water, out to all the camera can show (FR-MAP-140), is the covered ground less the grid, in up to four slabs. On the shipped island that is some fifteen thousand triangles, built once at a match's start in 73 ms on the simulator. The surfaces are custom meshes (`MeshDescriptor`, iOS 15 and later) with back-face culling off (`PhysicallyBasedMaterial.faceCulling`, iOS 27.0 SDK), so no winding can hide a wall.

**Basements stay open.** The ground and the shore are left out over any cell with a floor below floor 0, the opening grown by a step of the grid so that no sliver of ground reaches into a basement's cells; the water is cut to the shore, and so never runs under the island. A basement is seen as any floor is, through what is above it (FR-VIEW-140).

**What a module stops** (FR-MAP-210, FR-MAP-220). Every legend entry says whether the module is a surface (`walkable`), whether it stops movement and sight, which module is laid under it where it is not a surface (`floor` — indoors the floor, outdoors the ground; FR-TOOL-020 now places that one), and what it is drawn as (`figure`: a box, a tree, a shrub). A cell is passable where its module is a surface or stops no movement: the graph has a node there, and the snake's body passes it. The body is stopped by what stops movement, and by ground more than a step above its feet (ADR-0033). A line of sight is stopped only by what stops sight — which surfaces do, since nobody sees through a floor. A tree is drawn as a crown on a trunk and a shrub as a mound, each fitted into its module's box; for sight, the body and the see-through, every module is its box. The kit's trunk colour is the kit's.

**Spawn points** (FR-MAP-180, FR-MAP-190). `spawn <x>,<z> <floor>` in the header, as many as the map wants. The launch refuses a map that names none or names one where nothing can stand; a map read for a test need not name one. `Game.start` takes one at random, and a restart takes one again. Tests that need the same start every run take the map's first.

**The squads keep their distance in metres.** The squads were placed as far from the snake as the graph reaches, and on the island a cell many steps away can be a wall's width from the snake, outside a building the snake starts in: a bot started 7.6 m from the snake, inside its interrupt distance. Every cell within the interrupt distance, across the ground, is now taken before anybody is placed.

**The blockout is an island.** The room, its balcony and its flight stand shifted four cells across and four down on grass of no particular shape, 32 by 24 cells, with trees and shrubs about it, doorways two cells wide west and south — the snake's body is wider than one — and three spawn points: the room's corner, where every match began before, and two on the grass. The old room is kept as `maps/room.map`, a fixture of the test suite, so that the tests of how the snake, the bots and the camera behave do not move with every change to the shipped level.

**The camera keeps its metres.** It stands back 1.1 lengths of the map's larger side (IF-VIEW-020); the island is 15 m where the room was 12, and the share was brought down to 0.88 so that the camera still stands 13.2 m back and the picture keeps its scale.

### Consequences

A map of any shape draws its own island, and a new setting draws its own edge from the same field.
The ring of trees and shrubs of ADR-0031, and with it the rule on how tall scenery in front of the arena could be, are gone: trees and shrubs are the map's, and what stands between the camera and the snake is cut open like any module (FR-VIEW-150).
The camera still stops at the arena's bounding box (FR-VIEW-020), not at its outline, so over a bay of the island it can show water beyond the map's edge. With the island there, what it shows is the island's own water, not a void.
The suite takes the room fixture where it tests mechanics, and the shipped map where it tests the shipped map.
