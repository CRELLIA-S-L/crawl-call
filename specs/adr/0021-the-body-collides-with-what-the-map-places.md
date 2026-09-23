# ADR-0021 — The snake's body is kept out of walls by their geometry, not by the grid

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** FR-SNAKE-010, FR-SNAKE-015, FR-SNAKE-220, FR-MAP-025, IF-MAP-020
- **Settles:** Q-230, which is removed from `specs/91-open-issues.md` with this decision

## Context and problem statement

The head's movement asked the navigation graph one question: is the cell under the head's centre walkable.
The head is a body with a radius, and the shipped tuning gives it 0.3 m on a grid of 0.5 m, so a head at the centre of a cell beside a wall was 0.25 m from the wall's face and sank 5 cm into it.
FR-SNAKE-010 said the head never passes through walls; by its centre it did not, by its body it did.
Q-230 recorded the divergence on 2026-09-22 and left the choice to the maintainer, since one of the ways out changes how the snake looks and feels.

It was not what had been decided either. ADR-0016 made the head a character controller that "the map's geometry keeps on the floor and out of the walls", and the spike built it so: a `CharacterControllerComponent` of radius 0.3 and height 0.6 against the arena's collision shapes (`materials/spike/README.md`, check 1). The game's head, written on 2026-09-23, is a point that asks the navigation graph where it may go; nothing recorded the change, and this decision is where it is recorded.

## Considered options

1. A finer navigation grid.
2. A smaller body radius.
3. Collision of the body against the boxes of the modules the map places, with the grid left to decide everything else.
4. RealityKit's `CharacterControllerComponent`, as ADR-0016 and the spike had it.

## Decision outcome

Option 3, chosen by the maintainer on 2026-09-24.

Option 1 does not do what Q-230 said of it. Q-230 offered a finer grid "so that half a cell exceeds the radius", and a finer grid does the opposite: at a cell of 0.25 m the centre of the cell beside a wall is 0.125 m from its face, and the body sinks 17.5 cm into it instead of 5. A grid keeps a body out of walls only when the walls are grown by the body's radius before the grid is made, and that is option 3 carried out on the grid, at four times the nodes for each halving of the cell.

Option 4 moves an entity in a RealityKit scene, so where the head is would be decided in the scene and not in `Snake`, which is kept free of RealityKit so that a test can read it. The slide of FR-SNAKE-015 and the drop of FR-SNAKE-220 are arithmetic that tests check without a device; a controller brings its own answer to both, and the game's would then be whatever that answer is, checked on the phone.

Option 2 changes the snake rather than the rule. The radius is also the spacing of the tail's segments, half of it, and part of how far the head reaches to eat: at 0.2 m the six segments a match starts with lie over 2.4 m instead of 3.6 m, and the reach falls from 0.55 m to 0.45 m. Those are look-and-feel numbers (concept §12), and nothing about them was wrong.

**What is decided.**

- **What the body is.** A circle of the body's radius around the head on the ground plane, as tall as it is wide, standing on the floor the head is on. What it may not enter is every module the map places that is not walkable — a wall, a crate, a partition — whose box reaches into that height. A walkable module is ground, however tall its box: a stair's box stands the height of a floor and is walked up, not bumped into.
- **What the grid still says.** Which floor the head is on, which cell is ground and which is air, where a stair leads and where a drop may be taken — everything it said before. The geometry says one thing only: how close to what stands on that ground the head may come.
- **Contact.** A step that would take the body into a module stops where the body touches it, not where the step began, and what is left of the step is laid along the module, as FR-SNAKE-015 asks: the part of the held direction that runs along the face the body touches. Along a straight face that is the same arithmetic as before. At the end of a wall, where the face turns, the body rounds the corner instead of catching on it.
- **A body already in a wall.** A head stands overlapping a module only where something put it there without asking about the body: the start of a match, a test, or a stair, which changes the floor under the head without moving it and does not ask about what stands on the floor it arrives at. The blockout's stair has open floor all round it at both ends. It may move in any way that takes it no deeper, so that it is never frozen where it stands. The match does not rely on this: the head is set down clear of walls when a match begins, moved out of whatever it overlaps within the cell it starts in; the start cell of the blockout is in the corner, a quarter of a metre from two walls, and the head starts 5 cm further out along both.
- **A drop.** The body is checked on the floor it lands on as well as the one it leaves; a drop whose landing would put the body into a module below is refused like a wall, and the head slides along the lip instead (FR-SNAKE-220).

### Consequences

The grid becomes the bots' model of the map alone where width is concerned. It has no idea how wide anything is: a gap of one cell between two walls is half a metre, which a bot's path goes through and the snake's body, 0.6 m across, does not. FR-MAP-025 asks that the snake and the graph decide where each may go with the same body radius, and was already met only on the snake's side; this is where what the two decide would first differ. The blockout map has no such gap — its narrowest passage is the 0.9 m between two partitions — so the disagreement is a rule for whoever draws the next map, not a fault in this one.

The snake reads the boxes the scene is built from (`ScenePlan`), which the map layer makes from the map and the kit; it still knows nothing about how any of it is drawn.

The see-through of ADR-0019 and ADR-0020 does not change with this. ADR-0019 recorded that every wall the snake touches is drawn see-through because the body overlapped it. The body now touches such a wall and no more, 0.3 m from the head's centre, and the wall is still within the body's radius plus the see-through margin of IF-VIEW-020, which is 0.45 m — so it is still cut open, now because the margin asks for it, which is what the margin is for. A wall that stands clear of the body by more than the margin is left alone, as before.

What a step costs grows from one lookup in the graph to a search along the step against the modules that stand at the body's height — about a hundred boxes on the blockout, once a frame in the open, and some twenty times over for each step that ends against something, since the contact is found by halving the step. It is not measured; NFR-PERF-010 is not measured either (Q-250).
