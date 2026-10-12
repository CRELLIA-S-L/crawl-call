# Functional requirements — commanders

The LLM layer: what a commander receives, what it returns, how often; the truce; what happens when the role-holder is eaten; bot speech.
Source: concept §9.1 (commanders), §9.4 (squad collapse), §13 stages 4–5, §14 (speech moderation), §15 (speech under thermal load).
The shapes of the commander's input and output are IF-CMD-010 and IF-CMD-020; the requirements below say what the fields mean and when they take effect.
That the LLM never drives per-frame execution is ADR-0003, not a requirement.

## The commander cycle

### FR-CMD-010 — One commander per squad

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/CommanderDesk.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/CommanderCallTests.swift]
created: 2026-09-21
```

While a match is running, the system **shall** run one commander per squad, each reasoning only from its own squad's view of the world.

**Rationale.** Concept §9.1: two independent commanders.
Independence is what lets one commander wrongly blame the enemy while the other knows better (concept §6.3).

### FR-CMD-020 — The commander is called on an interval

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-010]
depends_on: [IF-CMD-010, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/CommanderDesk.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Commander/SquadView.swift]
tests: [Tests/CrawlCallTests/CommanderCallTests.swift]
created: 2026-09-21
```

While a squad has a living role-holder, the system **shall** call its commander once per commander interval of the match configuration — between 5 and 10 seconds — with the squad's compressed world state as IF-CMD-010 defines it.

**Rationale.** Concept §9.1: every 5–10 seconds, a compressed state from the squad's point of view.
The interval stretches under thermal load (NFR-PERF-060), which is why it is configuration and not a constant.

### FR-CMD-025 — Each commander call is its own session

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-020, CON-CMD-010, CON-CMD-020]
depends_on: [IF-CMD-010]
refines: [FR-CMD-020]
conflicts_with: []
code: [Sources/CrawlCall/Commander/SystemModelCommander.swift, Sources/CrawlCall/Commander/CommanderDesk.swift]
tests: [Tests/CrawlCallTests/CommanderCallTests.swift]
created: 2026-09-22
```

When a commander is called, the system **shall** open a session carrying the instructions alone, use it for that one call, and carry the commander's previous decision to the next call inside the world state.

**Rationale.** A kept session was measured against a fresh one over thirty calls each, twice (ADR-0017): keeping it cost a mean of about 1150 input tokens against 402, answered in about 1.9 s against 1.6 s, and needed a rebuild rule to stay inside the 4096-token context of CON-CMD-010.
The cache a kept session earns does not pay for the transcript it carries.
A session of one call also cannot carry a refused exchange into the next one, which is what turned a single refusal into eighty-four consecutive failures (CON-CMD-020) — there is nothing to rebuild and nothing to poison.
Continuity costs about twenty tokens in the state (IF-CMD-010) instead of a transcript.
Built on 2026-10-11 (ADR-0077). Of the two halves, one is tested and one is not, and the difference is worth saying: that the previous decision reaches the next call *through the state* is what `CommanderCallTests` holds, by reading it back out of the prompt; that each call opens a session of its own is held by the adapter being the only thing that makes a session, and by the bench's measurement of what the alternative costs — a kept session was 1150 input tokens against 402, slower, and carried a poisoned exchange forward. No test can see a session.

### FR-CMD-027 — Every generation carries a response ceiling

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-025]
depends_on: [IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/SystemModelCommander.swift, Sources/CrawlCall/CrawlCallApp.swift, config/match.json]
tests: [Tests/CrawlCallTests/CommanderCallTests.swift]
created: 2026-09-22
```

When calling the model, the system **shall** pass the maximum response tokens of the match configuration — 80 by default, and never below what the answer's own structure needs.

**Rationale.** A generation without a ceiling ran past 40 seconds in the spike, in both runs, when the schema was left out of the prompt (ADR-0017).
The ceiling costs nothing when the answer is the usual fifty tokens and bounds the one that is not; NFR-PERF-040 gives the commander one interval to answer, and this is what keeps a single call from spending it.
The floor is not a formality: measured at a ceiling of 20 the answer was cut off mid-structure and every call failed with a missing field, while at 80 the ceiling was never reached (47–55 tokens).
Built on 2026-10-11. The shipped number is no longer the eighty above: the structure IF-CMD-020 asks for measured 173 to 397 output tokens over twelve bench calls, so `maximumResponseTokens` is 500 — the measured worst and a quarter. That follows this requirement's own second clause and contradicts its first, which is Q-560.

### FR-CMD-030 — The commander sets the threat priority

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-020]
depends_on: [IF-CMD-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/SquadCommand.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/CommanderOrdersTests.swift]
created: 2026-09-21
```

When a commander's response arrives, the system **shall** set the squad's threat priority to the one the response names — the enemy squad, the snake, or withdrawal — for use in its bots' deliberation.

**Rationale.** Concept §9.1: the key decision with three sides on the map.
The local override near the snake is FR-BOT-120.
Built on 2026-10-12 (ADR-0079): the priority ranks the kinds of target rather than scaling what either is worth, which is how the one other priority in the deliberation already worked (FR-BOT-120).
Told to worry about the snake, a bot fires at a part of it in view over any enemy; told to worry about the enemy, the other way round; `withdraw` names nothing to fire at and leaves the ranking where it was.

### FR-CMD-040 — The commander issues an order

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-020]
depends_on: [IF-CMD-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/SquadCommand.swift, Sources/CrawlCall/Commander/Orders.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Bot/Execution.swift]
tests: [Tests/CrawlCallTests/CommanderOrdersTests.swift]
created: 2026-09-21
```

When a commander's response arrives, the system **shall** set the squad's current order to the one the response names — hold, flank, withdraw to a zone, disperse, or destroy the enemy's cover.

**Rationale.** Concept §9.1 lists these five orders.
Setting the order is the "new order" event of FR-BOT-170; how much a bot obeys is FR-BOT-130.
Built on 2026-10-12 (ADR-0079). Four of the five orders become one cell for each bot to be in — the hook the deliberation has always had and that nothing set in play — and the fifth, destroying the enemy's cover, names none until a bot can wreck a wall (FR-BOT-070).
The cell is searched for within the order reach of the bot configuration, which is three times the distance a squad stays together over: at the grouping distance it had first, an order could name no cell a squad would notice moving to (ADR-0084, Q-610).

### FR-CMD-050 — The commander assigns roles

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-020]
depends_on: [IF-CMD-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/SquadCommand.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/CommanderOrdersTests.swift]
created: 2026-09-21
```

When a commander's response arrives, the system **shall** assign each bot of the squad the role the response names for it — holding a stair, covering, distracting — or none.

**Rationale.** Concept §9.1: who holds the stair, who covers, who distracts.
A role is a bias in that bot's utility, the mechanism being tuning.
Built on 2026-10-12 (ADR-0079). A soldier the answer passes over keeps the role it had, which is IF-CMD-020's refusal to repair read on this side of the crossing: a role cleared because the model forgot to mention it is an order nobody gave.
What a role does to a bot's utility is still nothing: the bias is tuning and no interface carries it yet.

### FR-CMD-060 — The commander sets personality weights

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-020]
depends_on: [IF-CMD-020, FR-BOT-030]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/SquadCommand.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/CommanderOrdersTests.swift]
created: 2026-09-21
```

When a commander's response arrives, the system **shall** replace each bot's personality weights with those the response names for it, each clamped to the range the bot configuration allows for that archetype.

**Rationale.** Concept §9.1: the weights are the most important part — through them the LLM shapes behaviour without taking per-frame decisions.
Clamping keeps a commander from turning a heavy into a coward outright; the range is per archetype so that the silhouette keeps meaning what it looks like.
Built on 2026-10-12 (ADR-0079). The clamp reads `allowedRanges` of the bot configuration, which nothing had ever read; every range in the shipped file runs 0 to 1, so the clamp holds nothing back today, and the numbers that would make it bite are the maintainer's to set in the file (ART-070).

### FR-CMD-070 — Awareness gates what the commander is told

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-020]
depends_on: [FR-SCORE-130, IF-CMD-010]
refines: [FR-CMD-020]
conflicts_with: []
code: [Sources/CrawlCall/Commander/SquadView.swift]
tests: [Tests/CrawlCallTests/CommanderCallTests.swift, Tests/CrawlCallTests/CommanderContractTests.swift]
created: 2026-09-21
```

While a squad's awareness is *calm*, the system **shall** omit the snake from that commander's input.

**Rationale.** Concept §9.1 and §6.3: on *calm* the snake does not exist for the commander.
On *alarm* the input carries the disappearances and not the snake; on *confirmed* it carries the snake — both are IF-CMD-010's business.

### FR-CMD-080 — The two commanders run out of phase

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-020]
depends_on: []
refines: [FR-CMD-020]
conflicts_with: []
code: [Sources/CrawlCall/Commander/CommanderDesk.swift]
tests: [Tests/CrawlCallTests/CommanderCallTests.swift]
created: 2026-09-21
```

The system **shall** schedule the two commanders' calls so that the start of one is at least half a commander interval from the start of the other.

**Rationale.** Concept §9.1, §15: phases are staggered so that two inferences never land in one frame.
Half the interval is the largest separation two periodic calls can keep.

## Truce

### FR-CMD-090 — A commander may propose a truce

```yaml
status: deferred
verification: T
derives_from: [FR-CMD-020]
depends_on: [IF-CMD-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Where the truce feature is enabled, when a commander's response proposes a truce, the system **shall** deliver the proposal to the other commander in its next input.

**Rationale.** Concept §9.1: "should we deal with the enemy against the common threat" is a judgement call, the rare case where an LLM is objectively more apt than utility AI.
Behind a feature switch because the concept enables it after stage 4 on live play; the data model carries it from the start.

### FR-CMD-100 — A truce stops fire between the squads

```yaml
status: deferred
verification: T
derives_from: [FR-CMD-090]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a commander's response accepts a pending truce proposal, the system **shall** suppress fire between the two squads until the truce ends.

**Rationale.** Concept §9.1: greed's natural punishment — eat too much too fast and they unite against you.

### FR-CMD-105 — A truce turns both squads on the snake

```yaml
status: deferred
verification: T
derives_from: [FR-CMD-090]
depends_on: [FR-CMD-100, FR-CMD-030]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a commander's response accepts a pending truce proposal, the system **shall** set both squads' threat priority to the snake.

**Rationale.** Concept §9.1: the truce exists "against the common threat"; a ceasefire that left each squad's priority on the other would be a pause, not an alliance.
Split from FR-CMD-100 because a ceasefire and a shared target can each be built and observed without the other; numbered beside it because they are one event.

### FR-CMD-110 — A truce is fragile

```yaml
status: deferred
verification: T
derives_from: [FR-CMD-100]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a truce is in effect, when a bot of either squad is hit by the other squad, or a bot's panic weight exceeds the truce-break threshold of the match configuration, or either commander orders a withdrawal, or either squad loses its role-holder, the system **shall** end the truce and restore the squads' hostility.

**Rationale.** Concept §9.1: fragile by construction — a stray hit, a panicking soldier or a retreat order breaks it; §9.4: collapse voids an active truce.
One act over an enumerated set of triggers.

## Squad collapse

### FR-CMD-120 — Losing the role-holder silences the commander

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-040]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/SquadCommand.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/CommanderCollapseTests.swift]
created: 2026-09-21
```

When the bot holding a squad's commander role is consumed or killed, the system **shall** stop calling that squad's commander for the rest of the match.

**Rationale.** Concept §9.4: the squad falls apart into uncoordinated executors.
A free consequence of the architecture and the player's main lever on the balance of the war.
Built on 2026-10-12 (ADR-0080). The match asks on every frame whether anybody living still holds the role, and a squad that has lost it is skipped where the calls are decided — said there rather than left to follow from the state being unbuildable, so that the rule is a rule.

### FR-CMD-125 — Losing the role-holder voids orders and roles

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-120]
depends_on: [FR-CMD-040, FR-CMD-050]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/SquadCommand.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/CommanderCollapseTests.swift]
created: 2026-09-21
```

When the bot holding a squad's commander role is consumed or killed, the system **shall** clear the squad's current order and every bot's role.

**Rationale.** Concept §9.4: coordination disappears.
Split from FR-CMD-120 because a squad could stop receiving new orders and still act on the old one, and that is a different squad from one with none.
Built on 2026-10-12 (ADR-0080). The order goes and every role goes with it, the body's included; what the bots keep is their weights, which is FR-CMD-130.

### FR-CMD-130 — Collapsed bots keep their last weights, with more panic

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-120]
depends_on: [FR-BOT-030]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/SquadCommand.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/CommanderCollapseTests.swift]
created: 2026-09-21
```

When a squad loses its role-holder, the system **shall** raise each surviving bot's panic weight by the collapse increment of the bot configuration, leaving its other weights at their last values.

**Rationale.** Concept §9.4: last known weights stay, panic grows.
A commander's last mood outlives him, which is why eating a commander mid-retreat is different from eating one mid-assault.

## Speech
Built on 2026-10-12 (ADR-0080). The panic is raised up to what the archetype allows, which is the bound FR-CMD-060 holds the commander's own weights to and the only one the configuration carries; a body is not raised, since nothing reads a dead bot's weights.

### FR-CMD-140 — Bots speak on events

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [IF-CMD-030]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a speech event of the speech configuration occurs for a bot — among them an order issued, spoken by the role-holder; witnessing an eating; a squadmate vanishing; a truce being proposed or broken; the enemy being blamed; a body being found — the system **shall** generate and play a line for that bot from the event, the bot's current weights and the instructions of IF-CMD-050.

**Rationale.** Concept §1: the voices are what sells the game; §13 stage 5 lists the material two squads add — cross-squad bickering, truce offers aloud, accusations that the enemy "set that thing on us".
The event list lives in configuration because the concept's list is illustrative, not closed; "order issued" is the one event that must be there, because it is how the player finds the commander (ADR-0011).

### FR-CMD-150 — Speech is rate-limited and queued

```yaml
status: deferred
verification: T
derives_from: [FR-CMD-140]
depends_on: []
refines: [FR-CMD-140]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When speech events arrive faster than the speech rate cap of the speech configuration, the system **shall** queue them in arrival order and drop the oldest queued event once the queue exceeds its configured length.

**Rationale.** Concept §15: lines have a frequency ceiling, a queue, and are discarded under overload.
Dropping the oldest rather than the newest keeps a line about what just happened.

### FR-CMD-160 — Every line passes a content filter

```yaml
status: deferred
verification: T
derives_from: [CON-PUB-080]
depends_on: [FR-CMD-140]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a line has been generated, the system **shall** pass it through the content filter of IF-CMD-060 before playing it, replacing a line the filter rejects with a pre-written line for the same event.

**Rationale.** Concept §14: App Store guideline 1.2 treats real-time generated content as user-generated — filtering is required; what it admits is IF-CMD-060, the same list the instructions carry (ADR-0017).
Replacement rather than silence: a bot that says nothing at the moment it was eaten is the one bug the player will notice.

### FR-CMD-165 — A refused generation falls back to a pre-written line

```yaml
status: deferred
verification: T
derives_from: [FR-CMD-140, CON-CMD-020]
depends_on: [IF-CMD-030]
refines: [FR-CMD-140]
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

When a generation does not return a complete answer, whatever the reason, the system **shall** play a pre-written line for the same event and speaker, and start the next call from a session that does not carry the failed exchange.

**Rationale.** CON-CMD-020: the model refuses about one call in ten about this game's own subject, and a failed exchange left in the session's transcript makes every later call fail too — in the spike one refusal was followed by eighty-four failed calls, to the end of the run.
So a refusal is an ordinary event with an ordinary answer, not an error path.
"Whatever the reason" rather than a list, because the list was wrong: a response ceiling set too low truncates the answer and the framework reports a missing field — neither a refusal nor a guardrail nor a timeout (`materials/spike/README.md`), and a fallback that enumerated the three would have let it through.
