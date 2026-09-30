# ADR-0067 — The head rides over its own body on a circle of a body's width

- **Status:** accepted
- **Date:** 2026-09-30
- **Related requirements:** FR-SNAKE-055, FR-SNAKE-050, FR-SNAKE-020, FR-SNAKE-280, FR-SNAKE-290, IF-SNAKE-010, FR-MAP-080

## Context and problem statement

On 2026-09-30 the tail was made to stop the head (FR-SNAKE-050, ADR-0066), and on the phone the same day the maintainer found that a snake that cannot get past itself feels strange, and asked for it to crawl over itself, over the top. A trial build did it; the maintainer kept it.
Open: how high the head goes and how it gets there, what is under it, and what follows it.

## Considered options

1. The head's height is where its body would rest on the body it crosses: over each part of the body past the neck within a body's width of it, level, the height on a circle of a body's width round that part's line, above that part; the highest of them. The trail keeps the height, so the body follows over.
2. A step up by a body's width wherever the two overlap.
3. Only the drawing rises; the head and tail the match knows stay on the ground.

## Decision outcome

Option 1: it is zero where the bodies only touch and a body's width right over the line, rising and falling with no step, which option 2 has. Option 3 would draw a snake over itself that the bots see and shoot through at the ground.

### How it works

- Each time the head moves, it looks at the tail past its neck — two segments by the snake configuration — as the line through its points. For each piece of that line within a body's width of the head, level, the height is that piece's height there less the ground's, plus the rest of a body's width round the line: √(w² − d²) for w the width and d the level distance. The head rides at the highest of them, and at the ground where there is none.
- A piece a floor away, more than two widths above or below, is not under the head.
- The head goes to that height no steeper than two metres up or down for each metre it covers, on the ground or up and down a climb or a drop. Crossing its body squarely it still rests on it by the time it is over its line, a body's width in from where it first touched; and a head that stops climbing — a coil, which does not climb — or starts again — steered off a meal it ended on its own body — goes down or up over the ground it covers rather than in one frame. Found in review the same day.
- The head's place is laid in the trail at that height, so the body the head draws after it goes over as well (FR-SNAKE-020), and a head crossing a crossing goes over both.
- The head is drawn at its height; the ground under it, what it can walk to and where it drops from are still the ground's, as before.
- A coil, which lays its ring against the body, does not climb it; the neck is not climbed, since a head turning on its arc passes within a body's width of it.

### Consequences

The snake cannot lock itself in any more: the trap corridors of FR-MAP-080, which rested on FR-SNAKE-050, have lost their reason (Q-510).
The bots see and shoot the body where it is, raised over itself.
The wall the tail was, and the slide along it, are gone with FR-SNAKE-050; ADR-0066 stands for the slide along walls and the coil's fall.
