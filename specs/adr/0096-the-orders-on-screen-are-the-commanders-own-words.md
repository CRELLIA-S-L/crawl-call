# ADR-0096 — The orders on screen are the commander's own words

- **Status:** accepted
- **Date:** 2026-10-14
- **Related requirements:** FR-VIEW-380, FR-VIEW-200, FR-VIEW-120, FR-VIEW-060, IF-VIEW-030, FR-CMD-030, FR-CMD-040

## Context and problem statement

The maintainer asked for a status line along the top of the screen: the red squad's orders on the left on a pink plate, the blue squad's on the right on a pale blue one. The reason it is worth building is the day before it was asked for — a match on the phone in which both squads stood still for two minutes, and nothing on screen could say whether they had been ordered to (Q-700, ADR-0095).

Two things had to be decided to build it, and each could have gone the other way.

## Decisions

**The order is shown in the words the commander answered with, and they are not translated.** `press north-east`, `hold middle`, `withdraw south side` — four order words and nine parts, as `CommanderDecision` holds them. FR-VIEW-200 asks for the game's text in the player's language, and its own rationale draws the line this falls on: what the fighters say is not text shown there, and the model's lines are a question of their own (Q-290). An order is of that kind — it is what the commander said, not what the game says.

The alternative was thirteen more entries in the catalog (IF-VIEW-030) and a translation of each. It was not taken for a reason beyond the work: the line is read against what the model answered, and a reader comparing a Russian plate with an English `press` in a bench reading or a frame record has to translate it back. The words around them — "no orders", "watch the %@" — are the game's own and are in the catalog.

**The plates are the squads' own colours, lightened, and not two new colours.** `BotEntity.colour(for:)` is what the bots are painted (FR-VIEW-060); the plate carries each 62% of the way to white, which is what makes the red squad's pink and the blue squad's pale blue while both stay the light, translucent plates the interface is made of (FR-VIEW-120). Two constants would have been one more place to change when a squad's colour moves, and a pink that no longer matched the bots would be a worse answer to "whose order is this" than no colour at all.

## Consequences

The line reads the match and nothing else, so it costs a match nothing: `SquadCommands` is already what the deliberation reads every slot. It takes no touches, so the thumb that steers still lands anywhere on the left half (FR-VIEW-050).

It answers the first half of Q-700 and leaves the second: a person watching the phone can now see what each squad was told, and nothing still writes those orders where a measurement could count them. The first reading it gave, within seconds of being installed: the red squad standing in the north-west, told to hold the north-west — which is the answer FR-BOT-660 was built for, now visible to anybody who looks.
