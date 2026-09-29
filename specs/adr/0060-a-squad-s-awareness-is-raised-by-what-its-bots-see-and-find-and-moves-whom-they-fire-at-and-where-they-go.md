# ADR-0060 — A squad's awareness is raised by what its bots see and find, and moves whom they fire at and where they go

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-SCORE-130, FR-SCORE-070, FR-SCORE-080, FR-SCORE-090, FR-SCORE-100, FR-SCORE-125, IF-SCORE-010, INV-BOT-020, FR-BOT-120, FR-BOT-180, FR-BOT-190

## Context and problem statement

On 2026-09-29 the maintainer asked for squads that act as squads, and chose to have a calm squad leave the snake alone now, before there is a commander, and to leave the commander's role (FR-BOT-040) for the commander's own work.
The requirements for a squad's awareness and what raises it were written before any of it was built, and leave open what "line of sight to the eating point" is, when a meal begins, what a squad knows of where a squadmate fell, and what the snake being "the top threat" means with no commander to set a priority.
Two of the ways to raise awareness have nothing to act on: a body shows the snake killed it (FR-SCORE-110, FR-SCORE-120) only where the snake kills without eating, and it never does.

## Considered options

1. Line of sight as the words say — nothing in the way, at any distance, in any direction.
2. Line of sight as a bot sees anything: within its detection range and field of view, with nothing in the way (FR-BOT-050).

## Decision outcome

Option 2. A witness is a bot that saw the meal; a bot that cannot see a snake at twenty metres or behind its back cannot see the snake eat there either, and the stealth the concept is built on — dragging prey out of sight, eating behind the ones who look the other way — is only there if witnessing is seeing.

### How it works

- A meal begins when the snake coils round a living bot (FR-SNAKE-280), or begins eating a body, and ends when the prey is gone. Its point is the prey's eyes where the meal began.
- A living bot other than the prey that sees the point from the beginning to the longer of the witness and late-arrival windows after the end is its witness, once a meal (FR-SCORE-070, FR-SCORE-080); both windows are followed as one, since a bot that has the point in sight within the late window also has it within the witness window, and the requirement that adds a case is whichever is longer.
- A witness's report reaches its squad after the report delay, if it is still alive then: eaten, it says nothing (FR-SCORE-100), and killed, it says nothing either, since a body does nothing (FR-BOT-320). A report sets the squad to *confirmed*.
- A squad knows where each of its bots stood when it fell or vanished, as its bots' positions are read from the truth elsewhere (FR-BOT-220, `partial`). A living bot of the squad within the inspection distance of that place with no body within it raises the squad to *alarm* (FR-SCORE-125); a body still there leaves the loss standing, since the snake may yet take it.
- No bot moves a body: walking and parting skip bodies, which is how INV-BOT-020 holds.
- Within the override distance the snake is the top threat: the target a bot fires at, ahead of every enemy bot and of the one it was firing at (FR-BOT-120). With no commander there is no priority to override; `partial` until there is.
- A calm squad's bots leave the snake beyond the override distance out of everything they choose — they neither fire at it nor hide or run from it (FR-BOT-180). The requirement first left it out of the target alone; calm bots then ran from a snake they would not fire at, and the suite's scenarios in which the snake reaches a bot failed with the override distance at 5 m. The maintainer tried the wider reading on the phone and had the requirement reworded on 2026-09-29.
- An alarmed squad's positions within the grouping distance of a squadmate are worth more by the `together` term weight, in the same worth that already ranks where a bot hides or runs (FR-BOT-190, ADR-0058).
- The scoring configuration reads only the two windows, the report delay and the inspection distance; IF-SCORE-010 is `partial` until scoring needs its values and multipliers.

### Consequences

The override distance was 6 m, the detection range of every archetype but the sniper, so a calm squad of four — which has no sniper — would have fired at the snake wherever it saw it. The maintainer set it to 5 m on 2026-09-29, the distance concept §9.2 names: a calm bot leaves a snake it sees between five and six metres off alone.
Once a squad is confirmed nothing lowers it, as FR-SCORE-130 has it; a match in which the snake is seen eating once is a hunt from then on.
