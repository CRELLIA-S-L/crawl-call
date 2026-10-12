# ADR-0079 — An order becomes one cell to stand in, and discipline is what the order has to beat

- **Status:** superseded by ADR-0085
- **Date:** 2026-10-12
- **Related requirements:** FR-CMD-030, FR-CMD-040, FR-CMD-050, FR-CMD-060, FR-BOT-120, FR-BOT-130

## Superseded

By ADR-0085 on 2026-10-12. The order no longer becomes a cell: a commander names a part of the arena, and which cell of it a bot takes is the bot's own, by the same `worth` that already weighed cover, height and squadmates. What this decision got right and ADR-0085 keeps: the one hook the deliberation has for an order is `Situation.orderedZone`, scored by the obedience term and weighed against the bot's own reading by its discipline (FR-BOT-130).

## Context and problem statement

Until this change the commander was a call and an answer and nothing else: `CommanderDesk` asked, `CommanderDecision` came back, the match counted it and threw it away. Four requirements say what the answer is for — the squad's threat priority, its order, each soldier's role, each soldier's weights — and all four were `deferred`.

Three of the four are a matter of writing a value into state, and have no decision in them. The threat priority and the order are not: the specification says to set them "for use in its bots' deliberation" and names no mechanism, and the deliberation has exactly one hook for an order — `Situation.orderedZone`, scored by the obedience term since FR-BOT-090 was built and `nil` in play ever since, because nothing set it. How a priority from {enemy, snake, withdraw} and an order from {hold, flank, withdraw-to-zone, disperse, destroy-cover} reach a utility function is this decision.

FR-BOT-130 comes with it, because it is the formula the obedience term was always meant to have: it says the order's term is weighted by the bot's discipline and "the local term" by one minus it, and which term is the local one is not written anywhere.

## Considered options

For the threat priority:

1. Rank the kinds of target — a priority names which kind wins when both are in view.
2. Scale what each kind is worth by a new weight in the bot configuration.
3. Make the kind the priority does not name unavailable as a target at all.

For the order:

1. One cell per bot, computed at each deliberation step from where that bot stands and what it knows.
2. One cell for the whole squad, computed once when the answer is applied.
3. An action of its own for each of the five orders, scored beside firing and fleeing.

For FR-BOT-130's local term:

1. The two actions the bot's own fear pays for — taking cover and running.
2. Every term except the order's.
3. The single best local action, scaled after the scores are in.

For a soldier the answer passes over:

1. It keeps the role and the weights it had.
2. Its role and weights are cleared.
3. The whole answer is rejected as malformed.

## Decision outcome

**The priority ranks, option 1.** The function already had one priority in it and it worked this way: FR-BOT-120 returns the snake inside the override distance outright rather than multiplying its score, so a second priority that scaled scores would be two mechanisms for one idea. It is also the only option that needs no new number: a multiplier is a tuning key, and a key invented here is a number no interface carries (IF-BOT-010). Option 3 was rejected on what the requirements say: a bot told to worry about the enemy with a snake in view has not stopped being able to see the snake, and FR-BOT-120 obliges it to fire at one that comes close.

The ranking narrows the candidates rather than returning one of them, which keeps the hysteresis of FR-BOT-140 inside the kind the commander named — a bot told to worry about the enemy still does not swap between two enemies every step.

**The order becomes one cell per bot, option 1.** A squad-wide cell would put the whole crew in one place, which is the opposite of what *disperse* asks for and would make *hold* mean "walk to where the squad's middle is"; and a cell computed when the answer arrives would be stale for the rest of the interval, which is seven seconds of a firefight. Option 3 — an action per order — is the expensive one: five new actions to score against each other, five sets of weights to tune, and the obedience term left with nothing to score.

**The local term is cover and flight, option 1.** Those two are what a bot's own reading of the danger buys, and they are what contradicts an order to stand somewhere. Option 2 would have discipline damping the medic's healing and the reload, neither of which contradicts anything. Option 3 is the same arithmetic one layer later — the maximum of a scaled set is the scaled maximum — with the scaling moved out of the term it belongs to.

**A soldier the answer passes over keeps what it had, option 1.** This is IF-CMD-020's refusal to repair, read on this side of the crossing: a role cleared because the model forgot to mention a name is an order nobody gave. Rejecting the whole answer (option 3) would throw away four correct soldiers for one missing one, and the response has already parsed into the shape the interface asks for.

### How it works

**Where an order sends a bot.** `Orders.zone` turns the squad's order into one cell for one bot, at each deliberation step, out of the cells that bot knows (FR-BOT-220) and can walk to within the distance over which a squad is still one group (IF-BOT-010) — the same reach and the same walk cover and flight are found by, so a destination is reachable by construction rather than by a check afterwards (FR-BOT-118, ADR-0058).

| order | the cell |
|---|---|
| hold | where the bot stands |
| flank | of the cells it can reach, the one furthest off the straight line to where it believes the enemy to be, and no further from the enemy than it already is |
| withdraw to a zone | the cell flight would choose from the nearest thing it is afraid of — `Deliberation.away`, unchanged |
| disperse | the cell furthest from its nearest squadmate, where that is further than where it stands |
| destroy the enemy's cover | none |

The fifth names no cell because no bot can wreck a wall: FR-BOT-070 is `deferred`. An order with no cell leaves the deliberation exactly as it was without a commander — no order on the list of actions, and the local terms undamped — which is the honest reading of an order the game cannot carry out. Each of the other four also names nothing where its own input is missing: flanking a crew nobody has seen, withdrawing from a danger the squad knows nothing of, dispersing a squad of one.

**What discipline does.** The order's own term was already `obedience × discipline × holding`, where `holding` is the courage term ADR-0074 added. What this change adds is the other half of the same scale: where an order names a cell, taking cover and running are multiplied by one minus the bot's discipline. Discipline 1.0 leaves nothing of the bot's own reading and it does what it was told; 0.0 leaves the order worth nothing and it never does; the shipped weights are in between, and the two sides move against each other as one number.

The snake inside the override distance is not damped by this, because FR-BOT-120 is about which target is ranked first and not about whether to hide: a disciplined bot holds its ground and shoots at what is on top of it.

**Where an answer reaches the match.** `SquadCommands.apply`, called from the frame that takes the answer off the desk and nowhere else. The threat and the order go to the squad; the role and the weights go to each soldier the answer names, by the name the state gave it (`SquadView.names`). A squad under no command deliberates exactly as it did before there were commanders, which is what keeps the commander optional rather than load-bearing.

### Consequences

**The obedience term runs for the first time.** It has been in the code since the squads were built and scored on `nil` in every match. With it, discipline and courage reach play through a second term each (ADR-0074), and what the shipped weights do to a firefight is now worth watching rather than reading.

**The clamp of FR-CMD-060 holds nothing back today.** Every `allowedRanges` entry in `config/bot.json` runs 0 to 1 for all six archetypes, so a weight the model names inside its own generation constraint is never moved. The mechanism reads the file, where a tuned value belongs (ART-070), and the numbers that would make it bite — a heavy that cannot be turned into a coward — are the maintainer's to set. The test covers the clamp against a configuration with a narrowed range, because against the shipped file it could not tell clamping from doing nothing.

**A role still does nothing to a bot's utility.** FR-CMD-050 obliges the game to assign it, and the bias a role is meant to be is tuning that no interface carries yet. The role is written on the bot, is read back into the next call's state, and is what FR-CMD-125 will void.

**Two new files belong to a part that is still a design.** `SquadCommand.swift` and `Orders.swift` sit in `Sources/CrawlCall/Commander`, which E-150 carries while it is `proposed`, so each adds a `carrier-unclaimed` warning — five more, 20 in all. They clear when E-150 is flipped to `built`, which is the last step of the commander plan and a person's act.
