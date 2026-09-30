# ADR-0069 — The head goes round what it meets at its whole speed, and feels half a metre ahead

- **Status:** accepted
- **Date:** 2026-09-30
- **Related requirements:** FR-SNAKE-015, FR-SNAKE-016, FR-SNAKE-290, FR-SNAKE-055, IF-SNAKE-010

## Context and problem statement

After the slide came to follow the stick (ADR-0066), the maintainer found on the phone that the snake still ran its nose into things, and asked for something taken from real snakes. A snake does not push against what it meets: it follows its outline, and it feels what is ahead with its tongue. Measured on the simulator the same day: steered all along at a point past a crate whose line ran within 0.2 m of the crate's middle, the head stayed against the crate for the rest of the trial, 132 frames of the 150 it had; aimed further off, it slid at the part of the stick along the crate's face and got by.
The maintainer chose both: the head going round at its whole speed, to the side the stick leans to or the roomier one (FR-SNAKE-015), and a feel half a metre ahead (FR-SNAKE-016).
Open: what the roomier side is, what counts as leaning, what the head does wedged in a corner, and how the feel picks its side.

## Considered options

For a stick held nearly square into what the head meets:

1. A lean of less than five degrees is none: a head already going along the obstacle goes on the way it is going, one at rest against it goes to the roomier side.
2. Any lean counts.
3. Always the roomier side.

## Decision outcome

Option 1. With any lean counting, a stick aimed at a point just past an obstacle swings to one side of its face and then the other as the head slides and the aim follows it round, and the head stays where it is — the 132 frames above, found in building this. Option 3 ignores the player where the player does lean.

### How it works

**Going round.** Where a piece of movement meets a face, the rest of it is walked along the face at the whole of it: to the side the held direction leans to along the face, when it leans by more than five degrees; else the way the head was already going along the face; else, at rest square against it, the side with more room — measured along the face among the modules and over ground the graph holds, up to 1.2 m, two body widths, each way, the nearer to the way the head was going where the two are even.
Along a side of a cell the graph refuses — a hole's lip, the ground's edge — the same, on the axis the piece did not cross, the stick's lean on that axis first, and never against the stick by more than the five degrees: a head in a corridor one cell wide pushed into its end stands, and does not walk back and forth, and a thumb trembling a degree either side of square does not turn it back and forth along the edge (found in review the same day).
A second face met sliding along the first — a corner — is slid along only as the stick leans along it, and never back the way the slide came; brought to rest against a face the stick leans to neither side of — going along a wall into a corner with the stick held into the wall — the head goes to the roomier side of that face, which may be back along the wall the way it came, rather than standing there for good (found in review the same day); held into both walls of a corner, the head stands. Found on the phone the same day: letting the second face turn the head the way it was going, or to the roomier side, sent it from one wall to the other and back every frame, its body piled up on the spot and the snake rose into the air over it.
Wedged in a corner, where every way along what it touches leads into the other side of the corner, the head goes out the way the stick is held, if that is open.

**Feeling ahead.** Before each piece turns the head towards the stick (FR-SNAKE-290), the way the head is going is felt half a metre ahead. Where it would meet something within that, and the stick is not held back behind the head, the head turns instead along the face it would meet — to the side the stick leans to along it, by the same five degrees, or else the side the way the head is going glances off to — as hard as the turning radius lets it, until the way ahead is clear. A stick straight along the way it is going still has a side: the side the face turns the way off to.

Only what stands on the ground is felt — walls, crates, trees — and not what is walked on. A flight's steps two ahead rise more than a step, and felt as a wall they turned a head that came at the flight on the slant along the steps and off it; found on the phone the same day, where a flight was hard to go up. Measured: steered on the slant at the landing of a flight three cells wide, the head took 191 frames to get up where one feeling nothing took 175; feeling only what stands on the ground, 175.

**Up onto its body.** Going round at its whole speed, a head can meet its own body side on faster than it rose on it at two metres up for each metre covered (ADR-0067): it now rises at up to four, and still comes down at two.

### Consequences

The head stands only where neither way along what it meets is open, and in a corridor one cell wide pushed against its end.
Measured on the simulator: aimed anywhere from straight through a crate's middle to a metre past it, the head is past the crate within 101 frames, where aimed within 0.2 m it had stayed against it; feeling ahead it is past one to five frames sooner aimed within 0.7 m.
The speed taken in the part of the stick along an obstacle — FR-SNAKE-015's first rule, and the tests that measured it — is gone.
