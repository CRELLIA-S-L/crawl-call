# ADR-0011 — The commander is a role on any bot, revealed by voice

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-BOT-040, FR-CMD-140, FR-CMD-120, INV-BOT-030, FR-VIEW-070

## Context and problem statement

Eating the bot that holds the commander role collapses the squad and is the player's main lever on the war (concept §9.4).
Concept §14 asks whether the commander is a seventh archetype with its own silhouette or a role assigned to any bot — which decides how easily the player finds him (Q-100).

## Considered options

1. A seventh archetype with its own silhouette.
2. A role on a bot of any archetype, shown by a visual marker.
3. A role on a bot of any archetype, with no marker: the role-holder is the one who speaks the squad's orders.

## Decision outcome

Option 3.
The concept's own rules point there: both squads share six silhouettes so the player learns six, not twelve (INV-BOT-030), and a seventh breaks that; a marker makes the most valuable target the easiest to find, which flattens the target-value axis (FR-SCORE-060) into "eat the icon".
Voice is the mechanism the game is built around: the role-holder's lines are the orders (FR-CMD-140), so a player who listens finds the commander, and a player who does not, does not.
That is a hunt, and it costs nothing to build that FR-CMD-140 was not already going to build.

### Consequences

The role is assigned at match start to a bot of any archetype (FR-BOT-040); the match configuration may exclude archetypes from it as tuning.
After the role-holder is lost nobody inherits the role — the squad collapses (FR-CMD-120), as the concept says.
FR-VIEW-070's silhouettes stay six.
The speech configuration carries an "order issued" event spoken by the role-holder; without it the decision has no mechanism.
