# ADR-0062 — The sway is laid on the drawn line's rings, by the ground the head has crawled

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-VIEW-330, FR-VIEW-250, FR-SNAKE-020, IF-VIEW-020

## Context and problem statement

FR-VIEW-330 has the drawn body sway to either side of its path, 5 cm, the wave belonging to the ground; the maintainer chose on 2026-09-29 that the head sway with it.
The tail the match keeps is a point every 0.6 m along the path (FR-SNAKE-020), and a wave of 1.2 m laid on those points would be two points a wave: nothing, or a zigzag. The body is drawn through them by a curve with three rings between points (FR-VIEW-250), a ring every 0.2 m.

## Considered options

1. Shift the rings of the drawn line: each by the sway at the ground under it, measured along the line from the head and from how far the head has crawled.
2. Lay down more points along the path for the drawing.
3. Move the tail the match keeps.

## Decision outcome

Option 1. Six rings a wave draw it, and the body keeps the triangles FR-VIEW-250 holds it to: nothing is added, only moved. Option 2 costs triangles for every point added. Option 3 is not drawing: shots, the coil and the tail's blocking read the tail, and the maintainer's words were that the snake sway, not that it move differently.

### How it works

- The snake counts how far its head has come along its path, climbs and drops included.
- A point of the drawn line a length back from the head is shifted level and square to the line by the amplitude times the sine of 2π times what the head has crawled less that length, over the wavelength: the same ground has the same shift whenever the body lies over it.
- The rings are built round the shifted line; the lengths along the body, for its taper and its skin, are the unshifted ones.
- The head is shifted as the line's end is, and turned by how the shift changes going forward, so that it points along the body's end. It is turned only where its way was read afresh — from the tail or a lunge's aim — and not where it keeps the way it faced the frame before, which was turned then: turned again every frame, the head of a snake that had not yet moved spun where it stood, found on the phone on 2026-09-30.
- The amplitude and the wavelength are the view configuration's (IF-VIEW-020): 5 cm and 1.2 m when this was built, 3.5 cm and 1.56 m since 2026-09-30 (FR-VIEW-330).

### Consequences

On a straight path the wave is the ground's exactly. On a bend the drawn line between the tail's points is not the path, only near it, and the wave slips along it by the difference — a few centimetres, under the amplitude.
Six rings a wave draw a sine as a polygon: its corners turn by about fifteen degrees at the crests, which a body 0.6 m wide hides.
The sway is only drawn: where the body stands for the match, within a hand's breadth of the drawing, is unchanged.
