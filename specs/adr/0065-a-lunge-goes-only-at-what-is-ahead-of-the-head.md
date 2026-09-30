# ADR-0065 — A lunge goes only at what is ahead of the head, and misses what gets out from ahead

- **Status:** accepted
- **Date:** 2026-09-30
- **Related requirements:** FR-SNAKE-270, FR-SNAKE-290, FR-VIEW-160, IF-SNAKE-010

## Context and problem statement

On 2026-09-30 the maintainer found that a lunge still folded the snake: a lunge at a bot behind the head sent the head back through its neck, which the turning radius had stopped the stick from doing (FR-SNAKE-290, ADR-0061), since a lunge aims at once. Offered a lunge only at what is ahead, one that curves round no tighter than the turning radius, or both, the maintainer chose ahead only, within 90° to either side, and then within 60°.
Open: which way is ahead, and what happens to a bot that gets out from ahead once the lunge has begun.

## Considered options

1. Ahead is the way the head last moved, or before it has moved the way from its neck to it; a bot that gets out from ahead at any frame of the lunge, wind-up included, is missed where the head is.
2. Ahead is judged once, as the lunge begins, and the lunge then follows the bot wherever it goes.
3. The lunge goes on in the way it began, straight, whatever the bot does.

## Decision outcome

Option 1. Option 2 folds the snake again whenever the bot steps round the head during the lunge, which at a bot's speed and a lunge's reach it can. Option 3 makes the lunge a throw at a place rather than at a bot, which FR-SNAKE-270 does not say: the head goes towards the bot.

### How it works

- A bot is ahead where the level way from the head to it is within the lunge angle of the snake configuration of the way the head is going: the way it last moved across the ground (ADR-0061), or where it has not moved yet, from the first point of its tail to it. With neither, everything is ahead.
- The eat button lights (FR-VIEW-160), and the eat intent lunges, only for the nearest bot within reach that is ahead.
- Every frame of the lunge, before the head moves, the bot is asked again: one already within the bite once the wind-up is over is reached, wherever it stands round the head; one no longer ahead is missed, and the head stays where it is. The first was found in review the same day: a bot that stepped beside a head that had reached it got away.

### Consequences

The player turns the snake towards what it would eat, as a snake does, and the head turns at most 60° into a lunge.
A bot that dodges round the head while the snake winds up gets away.
