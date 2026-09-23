# ADR-0020 — What is in the way is cut open around the snake, not faded whole

- **Status:** accepted
- **Date:** 2026-09-23
- **Related requirements:** FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, IF-VIEW-020

## Context and problem statement

FR-VIEW-150 and FR-VIEW-155 were met by switching a whole map module between solid and see-through.
On 2026-09-23 the maintainer watched the arena's left wall, which runs almost along the camera's line of sight, go see-through for seven cells, most of which could hide nothing of the snake.
Measured at the match's start and camera, two of the seven were cleared by FR-VIEW-150, because the body overlaps them, and the other five by FR-VIEW-155, because a wall lying along the line of sight hides a strip of ground for its whole length and some of that strip is always within the radius.
Narrowing the radius did not help: at one metre it still cleared two cells the snake could not be hidden by.
What was wrong was the unit. A module is a cell's worth of wall; what the player needs cleared is the patch of it in front of the snake.

## Considered options

1. Keep fading whole modules, and narrow what chooses them.
2. Cut a hole in the material of whatever is in the way, centred on the snake — the ordinary answer for a camera that is not allowed to move: a mask around the character, handed to the occluder's own material. Baldur's Gate III does it this way.
3. Move the camera in until nothing stands between it and the snake — which FR-VIEW-010 rules out, the pitch and yaw being fixed and the distance set by the arena.

## Decision outcome

Option 2.
It was checked before it was written: a throwaway build of 2026-09-23, not kept, looked at on the phone by the maintainer, in which a partition beside the snake went clear only around the snake and stayed a partition above it, where fading the whole module had left a hard-edged pale block.
That build centred every hole on the head, which is right for a module standing against the snake and wrong for one standing a metre or two in front of it; the partition it was looked at against stood against the snake, so it could not show the difference, and it was found in the arithmetic when this was being built.

**What is decided.** Which modules are touched is decided as before — by the line test of ADR-0019 for FR-VIEW-150, and by nearness to the head for FR-VIEW-155. What changes is what happens to them. A chosen module is drawn through a surface shader that fades its opacity towards a hole, clear inside it and solid beyond a radius, with a soft rim between. The hole has one of two shapes: along a line of sight — every part of the module within the radius of the line from the camera to a point of the snake, and nearer the camera than that point — or around a point, a sphere.

- **What a module must be open around.** For every part of the snake the module hides, the stretch of the line of sight to that part which runs through the module, to the body's own reach plus the see-through margin of IF-VIEW-020 — the same distance that decides the module is in the way, so no new number is needed (FR-VIEW-150). The stretch and not the part itself: a 2 m partition cuts the line of sight from 1.4 m in front of the snake at the shipped pitch, and a hole kept to the snake's side of it would leave the partition solid and the snake hidden. That is where Baldur's Gate III puts the mask too — at the point the cast from the character to the camera hits the occluder, not at the character. And the head, to the visibility radius, where the module stands near enough for FR-VIEW-155.
- **Which shape.** A module in front of the snake is cut along the line of sight to the middle of the parts it hides, to the reach plus how far the farthest of them is from that middle: the lines to them all start at the camera and spread towards the snake, so where they pass the module they are no further apart than at the snake itself. A module near the head that hides nothing is cut around the head. A module that is both is cut with one sphere holding every stretch of line through it and the head's window — wider than either needs and never narrower. That is the ordinary case beside the head, where whatever stands in front of the snake also stands within the window, and there the module is cleared all but whole; it is away from the head, along the tail and past the window's edge, that the line of sight is what the module is cut by.
- **Why a line and not a sphere.** The first build of this cut every hole as a sphere holding the stretch of line of sight through the module. A steep line stays near a thin partition for a metre and more, so that sphere came out 1.3 m in radius on a 2 m partition and cleared it whole, which on the phone could not be told from fading it whole. Cut along the line, the same partition is open within 0.45 m of the line — 0.45 m across, and about 0.8 m up and down from where the line goes through, the partition leaning away from a steep line — and stands below that.
- **What is never cut for the head.** Nothing whose top is no higher than the floor the head is on: that floor would otherwise open onto the void, which is what the throwaway build's first run showed. The floor and not the head, because a head walking a stair has already changed floors and is still climbing towards the surface, and measured against the head the balcony would be cut open under it. Nothing standing wholly beyond the head, measured across the ground away from the camera as ADR-0019 says. Both belong to FR-VIEW-155; the lines of sight of FR-VIEW-150 already carry ADR-0019's own height cut-off, measured against each part of the snake and not against the head — a tail lying down a drop is lower than the head, and what hides it can be too.
- **What stays as it was.** A floor above the head still fades whole (FR-VIEW-140): a balcony drawn at low opacity keeps its shape readable, which is why it was chosen by eye on 2026-09-22, and a hole in it would be a different look.
- **If the shader is not there.** A chosen module falls back to fading whole, so the game is never worse than it was before this decision.
- **Shadows.** A module with a hole in it keeps casting its shadow. The module still stands and only a patch of it is see-through, while in the throwaway build, which put shadows out as the whole-module fade does, the partition's shadow went out the moment the snake came near and the partition itself stayed standing.

The rim, and how much of the module is left at the centre of the hole, are numbers settled by eye and kept in the shader, as the whole-module fade's opacity is kept in the code; they move to the view configuration if they ever have to be tuned per map.

### Consequences

A Metal source enters the repository, carried by the view (E-050). It uses RealityKit's `CustomMaterial` with a surface shader, available since iOS 15; its contract was read from the iOS 27.0 SDK's own headers, `RealityKitSurfaceShader.h`, and not from memory.

Which modules are chosen, and where and how wide their holes are, is a pure computation and is tested. How the hole looks is not something a test in this repository can see: it is judged on the phone, which is what the `D` of FR-VIEW-150 and FR-VIEW-155 already asks for.

Each chosen module carries its own material, so that its hole can sit where that module needs it. A material carries one four-component value for the shader, which is room for one hole: a point and a radius, whose sign says which shape — around the point, or along the line of sight to it. The shader finds the camera itself, from the view matrix RealityKit hands every surface shader, so a line needs nothing more than its far end.

The half of ADR-0019's point 5 that describes a window of floor cells is replaced by this. The line test of ADR-0019 is not: it is still what decides that a module hides the snake at all.

What a hole costs to draw is not measured. NFR-PERF-010 was not measured before this either.
