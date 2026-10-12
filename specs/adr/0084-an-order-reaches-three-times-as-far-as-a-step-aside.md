# ADR-0084 — An order reaches three times as far as a step aside, and the reach is its own number

- **Status:** accepted
- **Date:** 2026-10-12
- **Related requirements:** FR-CMD-040, IF-BOT-010, FR-BOT-130, FR-BOT-190, FR-BOT-118

## Context and problem statement

ADR-0079 turned each of the commander's five orders into one cell for each bot to stand in, and gave that search the distance over which a squad is still one group — five metres — because it was the reach cover and flight were already found within and there was nothing else to use.

Q-610 measured what that costs. Five metres is a step aside: `flank` may not name a cell further from the enemy than the bot already stands, so inside five metres there is no going round anything; `withdrawToZone` resolves to the same cell flight would have chosen anyway; and a commander cannot say take the upstairs, leave the room or gather at the gate, because no cell it could name is far enough to mean any of them. An order that cannot move a squad is an order the squad obeys by standing still.

## Considered options

1. Keep the grouping distance, and widen the orders by giving each its own rule instead.
2. Give an order its own distance in the bot configuration, and set it wider than the grouping distance.
3. Let an order name a cell anywhere in the arena, and let the route decide what is reachable.

## Decision outcome

Option 2, with `orderReach` at fifteen metres against a grouping distance of five.

Option 3 was refused for the reason ADR-0058 gives: a destination chosen by distance across the map can be on the other side of a wall, and a bot that sets off for one and stops is the standing still concept §9.2 calls the signature stupidity. The walk outwards that makes a destination reachable by construction is bounded by a reach, so a reach there has to be.

Option 1 keeps one number for two jobs that are not the same job. Cover and flight are about the next wall; an order is about the next room. Reading both off `groupingDistance` meant that tuning how near a squad stays together silently retuned what a commander can ask for.

Fifteen metres is three times the grouping distance: far enough to name another part of the shipped arena, and short enough that a squad under one order does not string out across the island while FR-BOT-190 pulls it back together. It is a tuned number in the file where tuned numbers belong, and the test says what it must be greater than rather than what it is.

### How it works

`IF-BOT-010` reads `orderReach` from `config/bot.json`, and `Orders.reach` answers with it. The flank and disperse searches walk outwards to it. The ordered withdrawal is the one that needed more than a constant changed: it delegates to `Deliberation.away`, which is also how a bot flees the snake, so that function now takes the reach it is asked for and keeps the cover search as its default — an ordered withdrawal is given the order's reach, and flight from the snake is not (FR-BOT-118).

The flank rule itself is unchanged: a flanking cell may still be no further from the enemy than the bot already stands. At five metres that rule left nothing to choose; at fifteen it is what keeps a flank from being a retreat.

### Consequences

A commanded squad now moves when it is told to, and the obedience term has something to buy. Which also means a commander can now walk a squad into the open, which it could not before: the clamp on that is the bot's own discipline (FR-BOT-130) and its courage under danger (ADR-0074), both of which already stand between an order and a bot that thinks better of it.

One number in `config/bot.json` is new, and IF-BOT-010's enumeration of the distances it reads gains a fourth. Nothing else reads it.

The match this was measured in changed enough to make a test of the commander's events over-specified — it asserted that the list was empty after the carrying call, where a squad that is now moving under orders gets hit in the meantime. The test asserts what it meant to: the loss it watched is spent.
