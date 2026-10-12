# ADR-0082 — A cut-off action is held against one slot, and the bot asks again at the next

- **Status:** accepted
- **Date:** 2026-10-12
- **Related requirements:** FR-BOT-167, FR-BOT-165, FR-BOT-170, FR-BOT-080, FR-BOT-360, FR-BOT-370, FR-SNAKE-040

## Context and problem statement

FR-BOT-167 was approved on 2026-09-22 and never built. Half of what it asks for was in the code and cited it: an action whose route comes back empty is spent, and the next slot chooses again. The other half — that the action is excluded from that slot — was not, and the comment at `Sources/CrawlCall/Bot/Execution.swift` claimed the requirement all the same.

Q-600 is why it was taken up now. The standstill it measured was a bot choosing the same unreachable thing at every slot for a whole match, and while the cause there was cover naming the cell the bot stood in (FR-BOT-119, ADR-0081), the shape of the loop is the one this requirement was written against.

Three things had to be decided: where the exclusion is kept, how the owed slot is granted, and whether a bot that is already standing on the cell its action names is "cut off".

## Considered options

1. The exclusion is kept on the bot, as the action itself, and read by the scoring.
2. The exclusion is kept on the match, as a set of bot-and-action pairs with the slot number it expires at.
3. The excluded action is not remembered at all: the goal is marked unreachable on the graph for a while, so nothing chooses it.

And for the slot:

4. A case is added to `Interrupt`, so the existing interrupt machinery grants the slot.
5. The match reads the bots that hold an exclusion and puts them ahead of the queue by the same route interrupts take, without being one.

## Decision outcome

Option 1 and option 5.

The exclusion is one `Action?` on the bot — `unreachable` — because that is the lifetime the requirement gives it: one slot, the bot's own. A set on the match (option 2) would need a slot counter to expire against and would have to be swept for bots that died; the field cannot outlive its bot.

Option 3 was tempting and wrong. The graph is shared by every bot and the snake, the cell is not the problem — the route from one particular bot is — and a cell marked unreachable for everybody would hide it from the bots that can reach it perfectly well.

Option 4 was refused because FR-BOT-170 enumerates seven events and says so deliberately: "splitting would destroy the claim that these are all of them". Being cut off is not one of the seven, and an eighth case in that enum would read as an amendment to a requirement nobody amended. The match instead unions the bots holding an exclusion into the same `ahead` set it builds from the interrupts, and gives them a step of their own when the clock gives none — the mechanism FR-BOT-170 brought, used by a second requirement without being claimed by it.

### How it works

`Execution.walk`, finding `Route.between` empty, writes the action into `bot.unreachable` and spends it. `Game.advance` puts every living bot holding an exclusion ahead of the queue, and runs a deliberation step for them even in a frame the clock gives no step to. `Execution.deliberate` clears the field as the slot is taken, so the exclusion is spent whether or not it changed the answer.

Two places read it, because an action can be offered from either of two lists. `Deliberation.scores` filters it out, which covers cover, flight, the ordered zone, firing and reloading. `Deliberation.quiet` drops it from the advance or the look, which is where it matters most: the cell nearest what a bot believes is found over the whole graph and can lie the other side of a wall (ADR-0059), while the cell it has not seen is walked to and cannot — so an advance is the motive that goes unreachable, and `scores` never offers it.

**Arriving is not being cut off.** A bot standing on the cell its action names has a route of no steps, not no route; it spends the action and holds nothing against the next slot. The comment that claimed FR-BOT-167 for that branch was wrong and now says what the branch is. This matters for an order to hold, which names the cell the bot stands in by design (ADR-0079): a bot holding ground re-chooses to hold ground, and that is obedience rather than a loop.

### Consequences

A bot cut off from what it was making for now chooses something else at the slot it earns, and may choose the same thing again at the slot after — which is the point, since the tail that cut the passage may be gone by then (FR-SNAKE-040).

**The branch cannot fire in a connected arena, and so is tested on a cut one.** Everything a bot makes for today is walked out over the graph and reachable by construction — cover, flight, the cell it has not seen, the ordered zone — and the one exception, the advance, aims at a cell found over the whole graph. In a match the squads are placed around the two cells farthest apart that the snake's start reaches (FR-BOT-350), so in a cut arena both squads land in the snake's own room and believe nothing about anywhere else. `UnreachableTests` therefore works on two rooms with no door between them, and says in its own words why there is no match-level test beside it. The day a tail can block a passage, that test is the one to extend.

The suite reads the whole of it from the two sides: that the failed action is remembered and spent, that arriving remembers nothing, that the advance and the scored actions are each left out of the slot earned, and that the slot spends the exclusion. Taking the behaviour out turns all four red.
