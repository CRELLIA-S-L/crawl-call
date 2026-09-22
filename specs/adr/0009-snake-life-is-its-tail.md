# ADR-0009 — The snake has no health bar: its life is its tail

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-SNAKE-070, FR-SNAKE-170, FR-SNAKE-180, FR-SNAKE-210, IF-SNAKE-010

## Context and problem statement

Concept §5 takes damage off the tail in segments and never says what happens when no segments remain, whether the head has health of its own, or what the medic's ability restores (Q-010).
Three requirements could not be finished without an answer.

## Considered options

1. Head health points, with the tail as a buffer shot off first; the snake dies at zero head health.
2. No separate health: the snake dies when damage lands with no segments left to lose; it starts a match with a configured number of segments.
3. The snake cannot die; the match ends by score or by timer.

## Decision outcome

Option 2.
Segments already carry growth, abilities and the blocking of passages; making them the life as well gives the game one currency instead of two, and the concept's loop — long is strong but clumsy, short is nimble but empty — gains the term that pushes the player into danger: short is also close to death, and eating is survival.
Option 1 adds a second resource the player has to read and the HUD has to show, and lets a snake with no tail keep fighting, which is the least interesting snake there is.
Option 3 removes the stakes that make the bots' fire matter at all.

### Consequences

The medic's ability regrows segments rather than restoring "health" (FR-SNAKE-170); those segments carry no ability.
The heavy's armour reduces the damage that reaches the tail, and so the segments lost (FR-SNAKE-180) — unchanged in wording.
A match ends when the snake dies (FR-SCORE-140, ADR-0010).
No ceiling on the abilities carried beyond one per segment (Q-090): every ability rides a segment that fire can take, so length is exposure and the cap is the enemy's aim.
The starting segment count is a tuning number in the snake configuration; a snake that starts with none dies to the first bullet, so it will not be zero.
