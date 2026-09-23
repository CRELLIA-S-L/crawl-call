# ADR-0019 — One line test decides what hides the snake; the margin is room beside that line, not past its end

- **Status:** accepted
- **Date:** 2026-09-23
- **Related requirements:** FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, FR-BOT-050, FR-MAP-040, IF-VIEW-020
- **What the chosen modules look like:** ADR-0020 — this file decides which modules hide the snake, that one what becomes of them

## Context and problem statement

Three requirements ask the same question of the map's geometry and must not answer it differently, and a fourth deliberately does not ask it.
FR-VIEW-150 draws see-through whatever hides the snake from the camera; FR-VIEW-155 does the same for the ground around the head; FR-BOT-050 marks the snake known to a bot when nothing stands between them.
FR-VIEW-140 is the fourth: a floor standing over the head goes see-through by its level alone, wholesale, without any line being drawn, and it is named here so that a reader looking for it learns that it is not decided this way.
Each of the three is written as *what* must happen — "hides any part of the snake", "nothing between them" — and by `specs/README.md` a requirement is about what and not how, so none of them says how hiding is decided.
Left unwritten, the method existed only as code, and drifted from the words twice in one day: the margin was applied around the end of the line as well as beside it, so a wall standing behind the snake answered "in the way"; and the window of ground around the head was taken in every direction at once, so a wall behind the snake hid the ground behind itself and was cleared for it.
Both were found by the maintainer looking at the screen, not by any gate.

## Considered options

1. Leave the method in code alone, as an implementation detail below the specification's altitude.
2. Write the method into the requirements themselves, so that each says how its hiding is computed.
3. Record the method once, as a decision, and let the three requirements keep saying what they say.

## Decision outcome

Option 3.
Option 1 is what was in force and is what drifted; the words "within the margin of doing so" were the whole of the written record, and they do not say what the margin is measured from.
Option 2 puts geometry into three requirements that would then have to be kept in step with each other, and turns a requirement into a procedure, which `specs/README.md` refuses.

**The rule.** One of the six points below is not yet what the code does, and says so where it stands: point 6 waits on FR-MAP-040, which is still `deferred`. The rest is in force.

Given a box — a map module, by its centre and size — an eye, a point being looked at, and a margin in metres, the module hides that point when all of the following hold.

1. **The height cut-off.** If the eye is at or above the point, and the module's top is no higher than the point, the module does not hide it. Every place on a line that runs downward to the point is at least as high as the point, so nothing lower than the point can cross it. This is what keeps the floor slab the snake stands on — which touches the end of the line, and which the margin would otherwise reach into — out of the answer, for a camera looking down and for a bot looking across a room alike.
2. **The line.** The line runs from the eye to the point and stops a margin short of the point — unless the eye is nearer to the point than the margin is long, when it runs the whole way, there being no room to give back. It is a segment and not a ray: what lies past either end is not in the way, however well it lines up.
3. **The reach.** The module hides the point when it comes within the margin of that line. A distance, and therefore a ball: what the margin allows is the same in every direction, and the consequences below record what it cost to have written that as a cube for a day.
4. **The margin.** The margin is room beside the line and never room past its end. It is the body's own radius — a wall that hides half a body hides it — plus whatever the caller adds so the fade begins before it is needed. The view passes `bodyRadius` plus the see-through margin of IF-VIEW-020; the bots pass nothing, so for them the question is the bare one of whether the geometry cuts the line.
5. **The points asked about.** The view asks for the head and every tail segment, because a tail the player cannot see is a tail they cannot place; a bot asks about the same points, keeping those within its own detection range, and stops at the first one it can see. FR-VIEW-155 asked in addition for the walkable cells of the head's own floor within its radius; since ADR-0020 it asks no line question at all, and a module near the head is cut open around the head instead. What this sentence still fixes for it is the exclusion of any module standing wholly beyond the head. Beyond is measured across the ground away from the camera, and the margin takes no part in that measurement. Across the ground, because the plane the camera looks along is tilted by the pitch FR-VIEW-010 fixes, and the top of a waist-high fence behind the head falls on the camera's side of that plane; without the margin, because the margin is room beside a line and a measurement that borrowed it would clear the ring of cells touching the head all over again.
6. **Debris.** When a module enters its debris state it stops being geometry this rule sees, so the same sentence covers a wall before and after it is broken. Nothing does this yet: FR-MAP-040 is `deferred`, and this point is what it will mean here when it is built.

**One rule and not two.** It lives in the map layer, with the geometry, rather than in the view or in the bots: the picture the player reads and the bots' eyes have to agree about what a wall is, and two implementations of one question eventually answer it differently — which is the failure this ADR is written after.

### Consequences

The three requirements stay as they are, saying what must happen; this file says how it is decided, and a change to the method changes this file rather than three statements.

What becomes harder: a reader of FR-VIEW-150 alone no longer has the whole story, and this file has to be found. That is the price of keeping geometry out of the statements.

**What point 3 replaced, and what it cost.** Until 2026-09-23 the code asked something else: it grew the module's box by the margin on each of the three axes and tested whether the line entered the grown box. What that adds around a box is a cube of side twice the margin, where point 3 asks for a ball of that radius: into a corner it reaches the margin times the square root of three, 0.779 m where the margin is 0.45 m, and upward it adds height the module has not got, which lengthens the shadow it casts down the camera's line. With the shipped numbers, a margin of 0.45 m and the kit's fence of 0.5 × 0.8 × 0.5 m, the fence was tested as though it were 1.4 × 1.7 × 1.4 m and its shadow at a pitch of 55 degrees grew from 0.56 m to 1.19 m. Measured over the cells around a head standing in the open, the two readings disagreed about three cells, all of them a metre and a half towards the camera, where the fence is 0.565 m from the line of sight straight ahead and 0.618 m to either side. The gaps depend on the camera's pitch and not on how far back it sits: at 8 m and at the match's 13.2 m they are the same to three decimal places.

The maintainer settled it on 2026-09-23 by bringing the code to point 3. How the distance is found is the code's business and not this file's; what this file fixes is that it is a distance. The cheap reading is kept in front of the exact one as a filter, because a box the line misses even when grown on every axis is further off than the margin in any direction, so nothing it rejects needed measuring.

**A second thing the margin cannot fix.** At the shipped body radius of 0.3 m the snake is 0.6 m across on a grid of 0.5 m, so a wall in the cell beside the head overlaps the body and genuinely hides part of it: the wall's box is 0.25 m from the line, and the body's radius alone is 0.3 m. Every wall the snake touches is therefore drawn see-through under any correct reading of point 3, and the halo that follows the snake around is not a flaw in this rule but the body being wider than the corridor. That is Q-230 in `specs/91-open-issues.md`, which is about the same number.
