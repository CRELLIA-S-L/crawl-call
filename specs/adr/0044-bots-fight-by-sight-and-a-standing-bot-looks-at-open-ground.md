# ADR-0044 — Bots fire at an enemy's eyes, hide from where its eyes were, and a standing bot looks where it knows open ground

- **Status:** accepted
- **Date:** 2026-09-26
- **Related requirements:** FR-BOT-060, FR-BOT-140, FR-BOT-280, FR-BOT-320, FR-BOT-330, FR-BOT-340, FR-VIEW-300, FR-BOT-220

## Context and problem statement

On 2026-09-26 the maintainer asked for the squads to fight, and for bots not to stand looking at a wall. Asked how far the war should go, they chose fire at an enemy, death, and cover from the enemy, with target choice under hysteresis; asked what "not turning their backs to the walls" meant, they chose a standing bot not looking into a wall, leaving where it chooses to stand alone.
Each needed a way chosen: where a line of fire runs to and from, what counts as one target when the snake's nearest part moves, what a dead bot still does, how an enemy watches a cell, and how a bot finds where to look.

## Considered options

For the way a standing bot looks:

1. Over what the bot knows: the building's outline and the cells it has seen, a cell not yet seen counted open.
2. Over the true map.
3. Towards the danger it remembers, whatever stands in the way.

## Decision outcome

Option 1: a bot acts on what it knows (FR-BOT-220), and a cell it has not seen is the likeliest to hold something worth seeing, which is the free-space assumption of ADR-0032 read the other way round. Option 3 would have a bot stare at the wall between it and a snake it cannot see through that wall.

### How it works

**Fire at an enemy.** A line of fire runs from the shooter's eyes to the enemy's, at the eye height the two share (ADR-0022): what shows over a wall lower than that height can be fired at, as it can be seen. A bot fires only at an enemy it sees now, as it fires only at a snake it sees now (ADR-0043). The damage is dealt at once to the bot hit — until 2026-09-30, since when a round flies and strikes what is in its way (ADR-0063); a shot at a bot is drawn as a shot at the snake is, and is not counted a hit on the snake.

**One target.** Firing at the snake is one target wherever on the snake the bot aims, since the nearest part moves as the snake does; firing at a bot is one target per bot. Of the targets in view the best is taken, except that the one the bot was firing at is kept while nothing else is worth more by the hysteresis margin (FR-BOT-140).

**The dead.** A bot with no health left is a body: it is given no turn to think, walks, turns and looks round no more, tells its squad nothing and hears nothing, and is stepped over rather than pushed. A bot that sees a body where it knew an enemy drops the enemy and records it fallen, with when, and its squad hears of the death after the delay, as of anything else (FR-BOT-310). A body lies where it fell, drawn on its back with its feet where it stood.

**Hiding from an enemy.** A cell is watched by an enemy when the enemy's eyes, where it was last seen, have a line to where the bot's eyes would be, standing in the cell: an enemy fires at a head, and a head shows over what a snake's line to the ground would not cross. The rest is the cover search of FR-BOT-118 unchanged, with the danger taken as the nearest of the snake and the enemies the bot knows.

**Where a standing bot looks.** When a bot stops, it measures how much open ground lies ahead of it, stepping out a quarter cell at a time until a cell outside the building's outline, or one it has seen and nobody can stand in. With 1.5 m or more it keeps its facing; with less, it takes, of sixteen ways round it, the one with the most open ground, the nearest to its facing among equals. The way is chosen once as it stops and kept until it walks or fires again.
A bot pushed aside by another (FR-BOT-300) no longer turns to face the push: only a bot walking turns to face where it goes (FR-BOT-280).

### Consequences

A bot can now be killed by the other squad, and a match can end with no living bot through the war alone (FR-SCORE-150). The snake eats a body as it eats any bot not alive, the meal of a body the concept already has (FR-SNAKE-090).
Fire goes to the enemy's eyes only; a wall lower than the eyes hides nothing from a shooter, so on the blockout only crates, partitions and taller modules are cover from the enemy.
The enemy a bot hides from is where it was last seen, which with forgetting off stays where it was until it is seen again.
