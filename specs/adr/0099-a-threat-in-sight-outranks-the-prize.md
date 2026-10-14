# ADR-0099 — A threat in sight outranks the prize

- **Status:** accepted
- **Date:** 2026-10-14
- **Related requirements:** FR-BOT-690, FR-BOT-620, FR-BOT-640, FR-BOT-650, FR-BOT-670, FR-BOT-680, FR-BOT-050, FR-BOT-060, FR-BOT-220, FR-SCORE-160

## Context and problem statement

The maintainer, on finding a threat of any kind: everything moves off the prize and onto removing the threat. It is the counterweight to the rule of the same day that put the prize on every bot's list from the first second (ADR-0097) — without it a bot walks past a firefight to fetch a box.

The danger in writing it was writing the old gate back. ADR-0097 had just removed a condition under which only a bot believing every enemy gone was offered the treasure, and "deal with the threat first" can be read as exactly that.

## Decisions

**What counts is what the bot sees now, not what it believes.** An enemy bot in view (FR-BOT-060) or a part of the snake in view (FR-BOT-050) takes both treasure motives off the list; a sighting from a minute ago that it has not been to leaves them on it. That is the whole difference from the removed gate: that one waited on a belief about the war, this one on nobody standing in front of the bot.

**The carrier is not spared.** While it sees a threat it stops making for the evacuation point and does what the rest of its list offers — cover, or running — with the prize still in its arms, which it cannot put down (FR-BOT-650). It has no hand for a weapon (FR-BOT-670) and no speed to outrun anything (FR-BOT-680), so hiding is what it has. A firefight should now read as the carrier going to ground and picking its load back up when the shooting stops.

**One condition, no new motive.** It is two lines in the scoring, which is what keeps the second act two motives and not a layer (concept §9.2).

## Consequences

A squad of one cannot finish the second act. The carrier cannot shoot, so a lone bot that picks the prize up can never clear the way it needs cleared (FR-SCORE-160), and the match runs until something else ends it. The end-to-end fixture that played the second act one a side was moved to two a side for exactly this reason, and the shipped match of six a side never meets it. A mode with small squads would.

What is not measured yet is whether a carrier near the edge of what it can see flickers — ducking and resuming as a distant enemy crosses its view. Nothing in the suite shows it; if it appears on the phone, the answer is the margin FR-BOT-140 already uses for targets.
