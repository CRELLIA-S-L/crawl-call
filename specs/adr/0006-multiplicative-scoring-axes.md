# ADR-0006 — Score is three multiplying axes, not a list of tricks

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-SCORE-010, FR-SCORE-030, FR-SCORE-050, FR-SCORE-060, INV-SCORE-010

## Context and problem statement

The score has to reward the game's intent — ambush over chase, keeping the war going, picking targets — without becoming a checklist.

## Considered options

1. Named bonuses — "ate from above", "ate two in a row".
2. Three independent axes — stealth, balance of power, target value — multiplied.

## Decision outcome

Option 2.
With named bonuses the player finds the two or three most profitable and farms them, and a system meant to reward variety becomes a checklist.
With multiplying axes the fine situations arise at the intersection by themselves: eating the leading squad's commander unseen genuinely takes preparation and risk.
Points come from eating, never from a death (INV-SCORE-010); a body scores at a lower base than live prey because live prey resists and takes longer.

### Consequences

Every axis needs its own observable input: witnessing (FR-SCORE-070), a definition of the leading squad (FR-SCORE-040), the role-holder (FR-BOT-040).
There is no artificial counterweight to stealth; the erosion of cover while the snake waits is the pressure (ADR-0010).
