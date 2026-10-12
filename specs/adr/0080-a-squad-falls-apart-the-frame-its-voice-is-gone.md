# ADR-0080 — A squad falls apart the frame its voice is gone, and keeps the mood it was in

- **Status:** accepted
- **Date:** 2026-10-12
- **Related requirements:** FR-CMD-120, FR-CMD-125, FR-CMD-130, FR-BOT-040

## Context and problem statement

Eating the bot that speaks for a squad is the player's main lever on the war (concept §9.4) and the reason the role has no marker on the figure: it is found by listening to who gives the orders. Three requirements say what the loss does — no more calls, no order and no roles, and more panic in whoever is left — and all three were `deferred` because there was nothing to take away until ADR-0079 made an answer land.

What had to be decided is small and all of it is about edges: when a squad counts as fallen, how far the panic is raised, and what happens to a body.

## Considered options

For when a squad counts as fallen:

1. No *living* bot of the squad holds the role, and somebody of it is still alive.
2. No bot of the squad holds the role at all.
3. The role passes to another bot and a squad never falls.

For how far the panic is raised:

1. By the collapse increment, up to what the archetype allows for that weight.
2. By the increment, unbounded.
3. By the increment, held to 0 and 1 as a weight's natural range.

For the bodies:

1. A body keeps the weights it died with and loses its role with the rest.
2. A body is raised with the living.

## Decision outcome

**Fallen is option 1.** The holder's own body keeps the flag — FR-BOT-040 puts the role on a bot and nothing passes it on — so the question a frame asks is whether anybody *living* carries it, which is also exactly the question `SquadView` asks before building a state. Option 3 is a different game: a squad that appoints a new commander is one the player cannot break, and the concept's lever would be gone. The second half of the condition is the edge that matters: a squad with nobody left alive is not collapsing, it is finished, and there is nothing to take an order away from. Without it, the last frame of a wiped-out squad would read as a collapse in the record.

**The panic is held to the archetype's range, option 1.** `allowedRanges` is the only bound the configuration carries, FR-CMD-060 already holds the commander's own weights to it, and two bounds for one number would be two places to change it. Writing 0 and 1 into the code (option 3) would be a tuning number in a file where ART-070 does not allow one. Unbounded (option 2) would let two collapses in one match — which cannot happen, but the code would not say so — carry a weight past anything the rest of the game expects.

**A body keeps what it died with, option 1.** Nothing reads a dead bot's weights, so raising them is a number no one can see; its role goes with the rest because the state built for the next call lists what the squad was given, and a body still holding "hold the stair" would be an order nobody can carry out.

### How it works

`SquadCommands.collapses(_:among:)` asks the question and `SquadCommands.collapse(_:among:configuration:)` does the three things, once — the squad enters a set it never leaves, so a frame that finds the holder gone a second time changes nothing. The match asks on every frame, before it decides what to call, and the place where the calls are decided skips a fallen squad by name rather than relying on its state being unbuildable: the state would indeed be nil, and a rule that holds by accident is a rule that stops holding when the accident does.

### Consequences

**The commander layer now has a visible failure mode in play.** A squad whose voice is eaten keeps the weights its last answer gave it, with more panic in them, and goes on fighting without orders — which is the behaviour the concept asks for and the first thing in this layer that a player can cause on purpose.

**A match can now end with one squad under orders and one without.** Nothing else in the game treats the two differently, and nothing needs to: a squad under no command deliberates as it did before there were commanders.

**The test that proves it eats the role-holder**, through the game's own `begin(eating:)`, because a firefight does not do it in bounded time: ninety seconds of two squads shooting at each other took 110 points of health off eight bots and killed nobody, so a test that waited for a death in battle would be slow and would still not choose whose.
