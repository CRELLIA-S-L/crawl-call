# ADR-0005 — Two warring squads, not one

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-BOT-020, FR-SCORE-040, FR-SCORE-050, FR-SCORE-110, FR-SCORE-125, INV-BOT-030

## Context and problem statement

One squad hunted by a snake is a stealth game against a single opponent.
The concept wants the player to wait, read someone else's fight, and manage a balance of power.

## Considered options

1. One squad versus the snake.
2. Two squads at war with each other and with the snake.

## Decision outcome

Option 2.
While the squads are busy with each other the snake can wait and pick off the exposed; if one side wipes the other, the survivors turn on the snake as a group with nothing left to distract them — greed is punished by the situation without artificial rules.
A body left behind blames the enemy (FR-SCORE-120): the snake plants evidence and the war goes on — the strongest argument for two squads.
Two squads also give the voices their material: cross-squad bickering, truce offers aloud, accusations that the enemy set the thing loose.

### Consequences

Double the LLM load and more bots on screen, which is why the match starts at 4v4 (FR-BOT-020) and not 6v6.
Both squads share one archetype set (INV-BOT-030) so that the player learns six silhouettes, not twelve.
Whether watching a fight is more interesting than chasing is H-030, and its refutation removes this layer.
