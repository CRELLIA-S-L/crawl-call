# ADR-0035 — A map shows no way the snake cannot take, found by comparing what the eye sees with where the snake can be

- **Status:** accepted
- **Date:** 2026-09-25
- **Related requirements:** FR-MAP-260, FR-MAP-230, FR-MAP-240, FR-MAP-250, FR-MAP-200, FR-MAP-220, FR-SNAKE-010

## Context and problem statement

On the phone, the snake ran into an invisible wall at the blockout island's left edge, about halfway down. Its column had three cells with no module in it, (1,5), (1,10) and (1,15). The edge FR-MAP-200 draws lies half a metre beyond the map's cells and rounds its hollows off with a metre's radius, so it closed each of those gaps with grass. The ground looked unbroken, and the head stopped where the cells ended.
The maintainer also asked that every passage a map shows be wide enough for the snake. The body is 0.6 m across and a cell is 0.5 m (ADR-0021), so a gap of one cell between two things that stop movement looks like a way through and is not one.

The same day brought more such places, one kind at a time, each found on the phone after the check before it had passed the map:

- a partition drawn as a column of `=`, thin across the rows, so that the column was a row of fins with slots 0.4 m wide between them;
- a single row between the flight and the house's south wall, which the check had passed because it left the flight's side out;
- trees on the island's outermost cells, where the ground drawn beyond them reads as a way round and no cell is;
- a tree whose corner met the water's corner, so that the way round it ran through a point.

Each kind got a rule of its own: FR-MAP-230, FR-MAP-240, FR-MAP-250 and a widening of the last. The maintainer then asked for one rule that names no kind of place, since a list of kinds would miss the next one.

## Considered options

For what the map may show:

1. A rule for each kind of place found, and a detector for each.
2. One rule, that the map as drawn shows the snake no way its body cannot take, and one check that compares what the eye sees with where the snake can be.

For a map that shows such a way:

1. Refuse it, naming the place.
2. Take every cell the edge draws ground over as ground to walk.

## Decision outcome

Option 2 for the rule, chosen by the maintainer (FR-MAP-260): the four kinds above were cases of one thing, and a detector per kind is a list that only grows after the phone has found its next entry.
Option 1 for the map, chosen by the maintainer. Taking drawn ground for ground would have the setting decide what the map is, would need the setting's edge before the graph is derived, and would let a different setting change where the snake can go. A map is refused at launch, like a map with no spawn point (FR-MAP-190); a map read for a test is not.

### How it works

Each floor is sampled on a grid of 5 cm, the grid the island's edge is drawn on, and two pictures of it are laid over each other.

**What the eye sees.** Open, where there is ground to stand on and nothing stands in it that stops the body. On the ground floor the ground is what the setting draws, and over a floor below it the ground floor's own cells: where there are none, the eye looks down into a basement. On any other floor the ground is that floor's cells. What stops the body is what stops movement, and ground whose top stands more than a step above the floor — the side of a flight, which the body meets as a wall (ADR-0033), by the threshold the body uses. A piece counts where its box reaches into the body's height on its own floor. Everything else is shut: the water, a basement's opening, the air beyond a balcony.

**Where the snake can be.** Its head, inside a cell it can stand in, no nearer to what stops its body than the body's radius (ADR-0021).

Where the eye sees open ground and the head cannot be is the space between the two pictures. A map is refused where that space does one of three things.

1. **It runs between two things the eye sees apart, somewhere the snake can come to.** That is a gap the eye looks through and the snake cannot take: two walls half a metre apart, fins of a partition, a flight's side and a wall, a tree and the water where the ground drawn beyond the map's outermost cells passes by it, and a tree and the water that meet corner to corner. Things that touch are one thing; sampled, a touch can fall between two samples, so things a step and a half apart are taken as touching. The strip of ground drawn outside a room walled round at the map's edge runs between the wall and the water too, but the snake cannot come to it, and it is left alone. The place is named by the smaller thing, where it comes nearest the larger: the tree, not the water; the flight, not the house.
2. **It parts two stretches of ground the snake stands on that the eye sees as one.** That is a way through the eye looks for and the snake cannot find: a room whose only door is narrower than the snake. It is named at the middle of the crossing.
3. **It lies on a straight way between two places the snake stands, farther from what stops the body than the body's radius.** That is ground the eye sees and the snake cannot walk: a cell the drawn edge closes over between cells of the map, as at the blockout's left edge, or a hole in the middle of it. Along every row and every column of samples, a run of such ground with the snake's ground at both ends and nothing shut between them is refused, named at its middle.

The third was first measured differently, as ground deeper than the strip the edge draws beyond the map's cells. It does not hold. The rounding of FR-MAP-200 fills a hollow corner of the map's outline about as deep as a one-cell gap — some 1.1 m at a corner with long sides, by the geometry of a margin of 0.5 m and a rounding of 1 m, against some 1 m in the gap — so no depth tells the two apart; on the blockout, a threshold between them was a matter of sampling, and it moved from corner to corner as the map changed. What does tell them apart is where the ground leads. A hollow corner leads only to the water, and the snake that stops short of it has nowhere to go that the eye promised. A gap between cells has the snake's ground on its far side.

None of the three names a kind of place. The kinds found on 2026-09-25 are the check's tests, and whatever nobody has found yet is found by the same comparison.

On the blockout the check takes about 50 ms on the phone, once, at launch.

### The maps

The blockout, after the three rounds:

- grass in the seven cells along its left and right edges that the edge had drawn over;
- its partition in column 14 a wall of two cells, with a doorway two cells wide in rows 10 and 11;
- its trees neither one cell from a wall nor on the island's outermost cells, and none corner to corner with the water; on the island's sides, where two or three cells lie between the house and the water, they stand against the house's wall, so that the two cells beyond them are a way round;
- its flight a row higher, in rows 15 and 16, so that two rows lie between it and the south wall, and the two crates that stood in row 15 in row 11;
- its top and bottom rows lengthened, so that its edge steps by at most two cells a row, which the depth measure had asked for and the island keeps.

The room fixture loses the partition at row 4 of column 10, which made a slot with the one below it; the others stay, because a test of the body passing a gap of 0.9 m between two of them rests on them. Its flight stays where it is, so that nothing the suite measures in that room moves, and the row under its taller steps became wall.

### Consequences

A map that shows the snake a way it cannot take is refused at launch, naming the line and the column, and a map author learns of it before the phone does.
A map author gets no list of shapes to avoid, only the place. A shape the three comparisons do not catch is a way the check misses; finding one means a fourth comparison, and FR-MAP-260 stays as it is.
A partition drawn as a column of `=` is refused wherever two of them are neighbours in a column. The kit's partition runs along the rows only, and a partition that runs along a column waits for a kit with modules that face a direction.
What the eye sees is taken to be boxes, not the figures drawn in them (ADR-0034). A tree drawn narrower than its box shows a little more room than there is, and that room is not counted.
The check asks about the snake alone. Bots are placed and walk by the graph (FR-MAP-020), so what is narrow to the snake is not narrow to them.
