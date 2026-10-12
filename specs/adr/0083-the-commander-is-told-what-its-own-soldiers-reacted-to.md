# ADR-0083 — The commander is told what its own soldiers reacted to, once each, and the call spends it

- **Status:** accepted
- **Date:** 2026-10-12
- **Related requirements:** IF-CMD-010, FR-BOT-170, FR-CMD-020, IF-CMD-060, FR-TOOL-170, CON-CMD-010

## Context and problem statement

IF-CMD-010 obliges the state to carry "the events since the previous call". `Game.dueCalls` built every state with an empty list from the day the commander was wired up, and nothing anywhere appended to it, so a commander could not tell between two calls whether its squad was winning, losing, had been fired at, or had lost anybody (Q-610). The requirement went to `partial` on 2026-10-12 to say so.

What the requirement does not say is *which* events, and that is a decision with a price: every word added to the state is input tokens against the 1000-token budget of the match configuration, and any change to the state's vocabulary voids every prompt measurement the project holds (FR-TOOL-170).

## Considered options

1. Losses and hits taken only — two clauses, nearly free.
2. Those, plus a magazine run dry, the snake coming near, and a squadmate seeing the snake take one of ours — what the frame already computes for the bots' own interrupts.
3. Those, plus a trend: ground gained or lost, who is firing at whom, health lost since the last call.

## Decision outcome

Option 2, and the rule behind it is what makes it the right size: **the commander is told what its own soldiers reacted to, and nothing else.**

The five events are exactly the interrupts of FR-BOT-170 that the game already finds every frame — a hit, an empty magazine, the snake within the interrupt distance, a meal witnessed — plus a soldier gone. So the state gains a line and the match gains no work, no new perception, and no new way of knowing anything: what the commander hears is what made its own bots stop and think.

Option 1 is cheaper and says too little: a squad whose last magazine has run dry and whose scout has just seen the snake eat somebody is in a situation, and "nobody was hit" describes none of it.

Option 3 needs state nothing keeps — positions at the previous call, a tally of hits given, who was shot at by whom — which is a bookkeeping layer of its own, and it is the one option that cannot be built from what the frame already has. It is left for the day somebody can show the commander decides better for it.

### How it works

`SquadHappenings` holds, per squad, the archetypes that were hit, ran out, witnessed a meal or went down, and whether the snake came near. `Game.advance` notes every interrupt the frame found — all of them, not only those the bots are still waiting to act on — and, from the line-up taken as the frame began, every soldier that was standing at its start and is not at its end. `Game.callCommanders` reads the lines into the state and clears that squad's, so the next call speaks of the interval since this one.

Four choices inside that are worth keeping:

**By archetype, not by bot.** The commander is told names, both squads field the same six, and a soldier hit five times between two calls is one soldier who took a hit.

**A body is one event, not one per witness.** `allyDied` interrupts every bot that saw it fall, and adding each would say the same loss four times; the loss is noted once, from the line-up, by whoever went down. So `allyDied` is the one interrupt that produces no line.

**The line-up is taken before the frame runs**, because a bot the snake finishes eating is gone from `bots` by the frame's end and its squad still has to be told.

**Cleared where the call is started, not where it is decided.** `dueCalls` is pure so that a test can read what the match decided without a task in the way (FR-CMD-020); reading it changes nothing, and the clearing lives in `callCommanders` beside the call itself.

### Consequences

A quiet seven seconds still produces the five lines the bench measured, so the common call is the call the measurement covers (FR-TOOL-170). A busy one adds a sixth line of at most five clauses, and the clauses are bounded by the crew: four names at most each.

The words are the measured ones and are checked against the same blocked list the rest of the state is: `gone missing`, `took a hit`, `ran out`, `the snake came near`, `saw the snake take one of ours`. The last of those began as "somebody" and was changed, because the project's own test reads the word `body` inside it — a crude check, and cheaper to satisfy than to argue with.

The state is bigger, which is the cheap direction: ADR-0078 measured the frames going to generated tokens, and these are input. The bench has not been re-run over the new state, and until it is, the prompt measurements cover a configuration the game no longer sends (FR-TOOL-170) — the one thing this change owes.

What the commander is told remains what its squad met. Nothing here reads the arena, so a commander still cannot be told what its soldiers did not see.
