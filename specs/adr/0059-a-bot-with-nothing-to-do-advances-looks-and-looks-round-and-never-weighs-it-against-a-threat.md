# ADR-0059 — A bot with nothing to do advances, looks and looks round, and never weighs it against a threat

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-BOT-360, FR-BOT-370, FR-BOT-380, FR-BOT-080, FR-BOT-340, FR-BOT-220, FR-BOT-250

## Context and problem statement

Q-320: with nothing happening around it, a bot stood still. With the squads at the island's two ends (FR-BOT-350) that meant a match in which the squads never met.
The maintainer settled three motives on 2026-09-29 — advance on the enemy, go to see what it has not seen, look round towards where a threat may be — each for a bot whose every other action scores nothing.
Left open: how the two ways of going somewhere are chosen between, what a bot does on reaching a place its knowledge sent it to and finding nobody, and how looking round sits with FR-BOT-340, which turns a bot that stops from the wall before it.

## Considered options

1. The quiet motives as actions with scores of their own, set below every other action's.
2. The quiet motives outside the scoring: tried only when the best of the scored actions scores nothing.
3. A timer: a bot that has chosen nothing for a while goes.

## Decision outcome

Option 2. It is the requirements' own condition, and it makes "never outweighs a threat" true by construction rather than by a margin that tuning could close: a threat is something that scores.
Option 1 needs a score below every other and above nothing, which a far snake's flight — worth next to nothing — would still beat or lose to by accident.
Option 3 leaves a bot standing while nothing happens, which is what Q-320 is about.

### How it works

- Advance or look: a bot goes on at the enemy by its aggression and goes to look by what is left of it, the advance where they are equal; where only one has somewhere to go, that one; where neither, it stands.
- Where the enemy is believed to be: the latest sighting of an enemy bot, its own or its squad's, ties to the lower id; or else the enemy's starting area. It goes to the walkable cell nearest that point; one it cannot get to is spent at routing, and the next slot chooses again.
- Finding a place empty: a bot within two cells of where an enemy was last seen, not seeing it now, records it as not found at that time; that sighting, and any no later, is believed no more, its own or told by the squad. A bot inside the enemy's starting area drops it. Without this a bot would stand for good where the enemy had been.
- Looking: the nearest cell along the walk, on any floor, that the bot does not know.
- Looking round: the way a bot turns to as it stops is its first look (FR-BOT-340); once every look-round interval after, a bot with no action turns to a new way — outside the half of its field of view it looks over now, among the ways with 1.5 m of open ground before it, or all of them where none has — the way nearest a threat counting twice what the turn away from its last look counts. Threats are where it last saw the snake or an enemy, and the enemy's starting area while it holds it. With a threat known, a bot looks at it every other turn; with none, it looks one way and back.

### Consequences

The squads now meet without the snake, and the bots go wherever they have not seen, one by one: a squad spreads out as it goes. Keeping it together is FR-BOT-190.
Everything a bot goes to is read from its knowledge, but the route there and the cell nearest a point are found over the whole graph, as the other routes are (FR-BOT-220, `partial`).
