# Functional requirements — bots

Archetypes, perception, utility-AI deliberation, time-based scheduling and interrupts, cover and height, destruction by bots.
Source: concept §8 (archetypes), §9.2–9.3 (deliberation, execution), §7 (bots destroy cover), §13 stages 1–3.
Per-frame execution for every bot is INV-BOT-010; that squads never remove bodies is INV-BOT-020; that both squads share one archetype set is INV-BOT-030.

## Squads and archetypes

### FR-BOT-010 — Six archetypes

```yaml
status: implemented
verification: I
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Archetype.swift]
tests: [Tests/CrawlCallTests/BotTests.swift]
created: 2026-09-21
```

The system **shall** provide exactly six bot archetypes: assault, heavy, sapper, scout, sniper and medic.

**Rationale.** Concept §8: the archetypes bind three systems at once — silhouettes, base personality weights and the ability the snake gains (FR-SNAKE-110).
Six is a number the player can learn; the set is the obligation, so this is one requirement and not six.

### FR-BOT-020 — Two squads at war

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-010, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Squads.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/BotTests.swift]
created: 2026-09-21
```

When a match starts, the system **shall** spawn two squads hostile to each other, each with the number of bots the match configuration sets, four by default.

**Rationale.** Concept §1: two warring squads are the strategic layer; §14: start with 4v4 because of thermal budget and readability.
Four per squad is the size of the vertical slice and there are no reinforcements (ADR-0010).

### FR-BOT-030 — Archetype sets base personality weights

```yaml
status: partial
verification: T
derives_from: [FR-BOT-010]
depends_on: [IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Bot.swift]
tests: [Tests/CrawlCallTests/BotTests.swift]
created: 2026-09-21
```

When a bot is spawned, the system **shall** initialise its personality weights — aggression, courage, discipline, panic, self-sacrifice — from its archetype's base weights in the bot configuration.

**Rationale.** Concept §8 table: assault aggression up; heavy discipline up, panic down; scout panic up; sniper discipline up; medic self-sacrifice up; sapper average.
The commander later adjusts these (FR-CMD-060); the archetype is where they start.
Courage joined the weights on 2026-09-25 (FR-BOT-090); the concept's table predates it, so each archetype's base courage is tuning, chosen when it is built. `partial` until the bot configuration carries it.

### FR-BOT-040 — One bot per squad holds the commander role

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a match starts, the system **shall** designate exactly one bot in each squad, of any archetype the match configuration allows, as the holder of the commander role, without marking it visually.

**Rationale.** Concept §9.4 and §14: eating the bot that holds the role collapses the squad (FR-CMD-120), and it is the player's main lever on the balance of the war.
A role rather than a seventh archetype, and no marker: the role-holder is found by listening — he is the one who speaks the orders (ADR-0011, FR-CMD-140).

## Perception and fire

### FR-BOT-050 — A bot notices the snake in view

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Perception.swift, Sources/CrawlCall/Bot/Knowledge.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Map/Sight.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Config/Geometry.swift, Sources/CrawlCall/Map/PieceIndex.swift, Sources/CrawlCall/Config/Utility.swift, Sources/CrawlCall/Config/Configurations.swift, config/bot.json]
tests: [Tests/CrawlCallTests/PerceptionTests.swift, Tests/CrawlCallTests/KnowledgeTests.swift, Tests/CrawlCallTests/PieceIndexTests.swift]
created: 2026-09-21
```

When any segment of the snake is within a bot's field of view and within the detection range of the bot configuration, the system **shall** record in that bot's knowledge where the segment was seen and when, the latest sighting of each segment replacing the one before.

**Rationale.** Concept §13 stage 1: bots see the snake, flee, shoot.
Known-to-a-bot is what deliberation (FR-BOT-080) and the interrupt on sight (FR-BOT-150) read.
Until 2026-09-25 the requirement set a mark that the snake was known, and a bot so marked was handed where every part of the snake truly was, from then on. The maintainer ruled that a bot acts on what it has seen (ADR-0032), so what a sighting leaves is where and when, and deliberation reads that (FR-BOT-220).
Since 2026-09-25 each part of the snake is told apart by its place from the head, and a part seen again replaces its own earlier sighting while the parts not seen keep theirs (ADR-0043).

The field of view is a cone round the way the bot faces (FR-BOT-280), as wide as the angle of the bot configuration (IF-BOT-010), since 2026-09-25: the maintainer asked that a bot see where it looks and not with the back of its head. Until then no bot had a facing, and it saw all round.
A bot looks from the eye height of the bot configuration (IF-BOT-010), which the shipped numbers put on the eyes of the figure it is drawn as (FR-VIEW-070), and what it looks at is the ground under each part of the snake. A module stops that line only where it stands higher than the line at the place the line crosses it: a fence lower than a bot's eyes hides a snake lying close behind it and not a snake across the room, by the same geometry the player's camera sees by, from lower down. Until 2026-09-24 sight was measured along the surface on purpose, as Q-240 settled it, because a bot was a box with no head and an eye height would have been a number measured from nothing; the figure is what gives the eye somewhere to be.

### FR-BOT-060 — A bot fires at its target

```yaml
status: partial
verification: T
derives_from: []
depends_on: [FR-BOT-080]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/ExecutionTests.swift, Tests/CrawlCallTests/ShotTests.swift]
created: 2026-09-21
```

While a bot's chosen action is to fire and it has a line of fire to its target, the system **shall** deal the target the damage per shot of the bot's weapon in the bot configuration.

**Rationale.** Concept §1: bots are fast, armed and organised.
A target may be an enemy bot or any segment of the snake — shooting at the tail is a meaningful action because of FR-SNAKE-070.
A line of fire leaves from the bot's eyes, the height it looks from (FR-BOT-050): what a bot can see over, it can shoot over, and a line of sight it could not fire along would be a bot that watches the snake and cannot touch it (ADR-0022).

**Partial, and how.** What is built is fire at the snake: a bot whose slot chooses to fire spends a round and deals its weapon's damage to the segment it aimed at. Fire at an enemy bot is not, because nothing yet chooses an enemy bot as a target — that needs the target hysteresis of FR-BOT-140 and a squad war the vertical slice does not ask for (concept §13 stage 1 is the snake and the hunt). The damage side is the same code the day a target is a bot.
A shot goes off once per deliberation step rather than once per frame, so that the damage a second does not depend on the frame rate. No requirement gives a weapon a rate of fire; when one does, the cadence moves out of the deliberation period and into the bot configuration.

### FR-BOT-070 — Heavy and sapper weapons destroy cover

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-060]
depends_on: [FR-MAP-030, IF-MAP-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a heavy's or a sapper's shot hits a destructible module, the system **shall** deal that module the destruction damage the tuning configuration sets for that weapon, while the weapon's destruction ammunition lasts.

**Rationale.** Concept §7: without bots that destroy, destruction is one-sided and a squad can dig in behind a wall and wait; the main scenario is squads taking the map apart fighting each other.
Ammunition is the regulator the concept names against a map that turns into wasteland by mid-match.

## Deliberation

### FR-BOT-080 — Action chosen by maximum utility

```yaml
status: partial
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Config/Utility.swift, Sources/CrawlCall/Config/Geometry.swift]
tests: [Tests/CrawlCallTests/DeliberationTests.swift]
created: 2026-09-21
```

When a bot receives a deliberation slot, the system **shall** select the action with the highest utility score among those available to it, the score being a function of:

- what the bot knows of the enemy;
- what the bot knows of the snake;
- the commander's order;
- the danger the bot is in;
- its health;
- its personality weights;
- what it has to fight with.

**Rationale.** Concept §9.2: every possible action gets a numeric utility; the maximum is chosen.
The inputs are named so that a test can vary each and observe the choice move; their weighting is tuning.
The list is the maintainer's, rewritten on 2026-09-25 when they settled what a bot knows (ADR-0032): each input is read from what the bot and its squad have perceived, never from the truth, and courage is a personality weight of its own (FR-BOT-090). `partial` because the build scores the snake alone as an enemy and a danger, knows no courage, and has nothing to fight with but a magazine; equipment beyond it is Q-310.

### FR-BOT-090 — Personality weights multiply utility

```yaml
status: partial
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-030]
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/DeliberationTests.swift]
created: 2026-09-21
```

When computing a bot's utility scores, the system **shall** apply the bot's personality weights as multipliers:

- panic, scaling threat terms up;
- courage, scaling the terms for facing danger — firing at it, holding ground under it — up;
- discipline, scaling hold-position terms up;
- aggression, scaling attack terms up;
- self-sacrifice, scaling protect-ally terms up.

**Rationale.** Concept §9.2: a bot with panic 0.8 overestimates the threat and runs; with discipline 0.9 it holds even when scared.
This is the only channel through which the commander's LLM output reaches per-frame behaviour.
Courage was added by the maintainer on 2026-09-25 as a weight of its own, not as the other side of panic: a bot can be frightened and stand its ground anyway, and the two pull on different terms — panic on the fear that sends it away, courage on the terms that keep it facing the danger. `partial` until courage is in the bot configuration (IF-BOT-010), set at spawn (FR-BOT-030) and read by the utility.

### FR-BOT-100 — Cover is valued by what is left of it

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-MAP-030]
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When scoring the action of taking a cover position, the system **shall** lower the score as the cover's remaining strength falls.

**Rationale.** Concept §9.2: a disciplined bot stays behind a damaged wall, a panicking one runs for an intact one — which only happens if the score knows the wall is damaged.

### FR-BOT-105 — Cover is worth less against a wrecking weapon

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-100]
depends_on: [FR-BOT-070]
refines: [FR-BOT-100]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When scoring the action of taking a cover position, the system **shall** lower the score further when an enemy within range carries a cover-destroying weapon with ammunition left.

**Rationale.** Concept §9.2 names both the residual strength and the enemy's destroying weapon; they are two inputs a test varies separately, so two requirements.

### FR-BOT-110 — Height advantage enters position scoring

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-080]
depends_on: []
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When scoring a position, the system **shall** raise the score with the position's height above the snake's head.

**Rationale.** Concept §13 stage 2: bots use height — fire from above, retreat to floors the snake takes long to reach.
Without this term the verticality of a map is decoration, which is what H-020 measures.

### FR-BOT-115 — Distance along the snake's path enters position scoring

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-SNAKE-010]
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When scoring a position, the system **shall** raise the score with the length of the shortest navigation-graph path from the snake's head to it.

**Rationale.** Concept §13 stage 2: bots retreat to floors the snake takes long to reach — a different thing from being above it, since a balcony over the snake may be one ramp away.

### FR-BOT-118 — A bot flees to somewhere it can get to

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-200]
depends_on: [FR-MAP-020]
refines: [FR-BOT-200]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Map/PieceIndex.swift]
tests: [Tests/CrawlCallTests/DeliberationTests.swift, Tests/CrawlCallTests/PieceIndexTests.swift]
created: 2026-09-23
```

When a bot chooses to flee, the system **shall** send it to a cell the navigation graph can reach from the cell it stands in.

**Rationale.** Concept §9.2 calls standing still the signature stupidity, and a bot that sets off for a spot behind a wall and then stops is doing exactly that while looking decided.
Fleeing is the one action whose destination could be unreachable: a cover position is walked out over the graph and is reachable by construction, and an ordered zone comes from a commander (FR-BOT-040), while the spot to run to was chosen by how much ground it puts between the bot and the danger — a distance across the map, not along it.
This is not FR-BOT-167, which says what to do when a target turns out to be unreachable; it keeps most of those cases from arising, and both are needed once the tail can cut a passage (FR-SNAKE-040) and a route can disappear after it was chosen.

### FR-BOT-120 — Nearby snake overrides the commander's priority

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-CMD-030]
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the snake's head is within the override distance of the bot configuration from a bot, the system **shall** rank the snake as that bot's top threat regardless of the commander's threat priority.

**Rationale.** Concept §9.2: the commander sets the priority, the utility layer corrects it locally — a snake five metres away overrides any order.

### FR-BOT-130 — Discipline decides how far an order is kept

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-090]
depends_on: [FR-CMD-040]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a bot's local threat assessment contradicts the commander's current order, the system **shall** weight the order's utility term by the bot's discipline weight and the local term by one minus it.

**Rationale.** Concept §9.2: discipline determines how much a bot sticks to the order against the local situation.
The formula is the simplest one that makes discipline 1.0 mean "always the order" and 0.0 mean "never".

### FR-BOT-140 — Target choice has hysteresis

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-080]
depends_on: []
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

If the utility of a bot's current target and that of the best alternative differ by less than the hysteresis margin of the bot configuration, the system **shall** keep the current target.

**Rationale.** Concept §9.2 names the side effect to check on the prototype: a bot caught between two threats must not freeze on close scores, and names hysteresis as the probable fix.
Written as behaviour — no flapping under a margin — so that a test can show it.

## Scheduling

### FR-BOT-150 — Deliberation runs on a fixed step, not per frame

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Slots.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/ExecutionTests.swift]
created: 2026-09-21
```

The system **shall** advance deliberation on a fixed-step accumulator of the deliberation period in the bot configuration, so that the number of deliberation slots per simulated second is the same at any frame rate.

**Rationale.** Concept §9.2: "one bot per frame" makes bots think twice as fast at 120 Hz and half as fast at 30, and difficulty then depends on the hardware.
Verifiable by running the same scenario at two frame rates and counting slots.

### FR-BOT-160 — Slots go by priority, not round-robin

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-150]
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Slots.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/ExecutionTests.swift]
created: 2026-09-21
```

When choosing which bot deliberates next, the system **shall** take the bot with the greatest product of deliberation steps since its last slot and importance, where the importance of a bot in combat or within snake range is at least three times that of an idle bot.

**Rationale.** Concept §9.2: a bot in combat or near the snake gets a slot 3–4 times more often than one patrolling an empty floor; the same rule gives AI level-of-detail for free — distant bots think about once a second.
The per-frame budget that bounds how many slots a frame hands out is NFR-PERF-020.
What is counted is deliberation steps and not frames, because this requirement derives from FR-BOT-150: a queue ordered by frames waited would put the frame rate back into the pace of thinking that FR-BOT-150 takes it out of, and two machines would hand the same bot different numbers of slots for the same second of play.

### FR-BOT-167 — An unreachable target sends the bot back to deliberation

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-165]
depends_on: [FR-BOT-080, FR-SNAKE-040]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

When the navigation graph holds no route to the target of a bot's chosen action, the system **shall** give that bot a deliberation slot with that action excluded until its next slot after.

**Rationale.** Being cut off is a designed event, not an edge case: the snake's tail makes a passage impassable (FR-SNAKE-040) precisely so that a squad loses its way out.
A bot that keeps asking for the route it cannot have is the "signature stupidity" concept §9.2 names — it must pick something else and pick it now.
Excluding only the failed action, and only until the slot after, keeps the choice honest when the tail moves away a second later.
Measured on the spike in its worst-case mode, about one path request in a hundred found no route — a rate that belongs to that arena's random targets rather than to the search, but enough to settle that this is an ordinary path and not an error path.

### FR-BOT-165 — At most one path is computed per frame

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-160, NFR-PERF-020]
depends_on: [FR-MAP-020]
refines: [FR-BOT-160]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Route.swift, Sources/CrawlCall/Bot/Execution.swift]
tests: [Tests/CrawlCallTests/ExecutionTests.swift]
created: 2026-09-22
```

When more than one bot needs a new path in the same frame, the system **shall** compute one path per frame in the order of the deliberation priority of FR-BOT-160 and leave the others on their current path until their turn.

**Rationale.** Measured on the spike (`materials/spike/README.md`): one A* path over a 48×32 grid costs 2–120 µs typically and up to ~1 ms for a far or unreachable target, so eight bots re-pathing in one frame — all fleeing the snake at once — cost 5 ms and the budget of NFR-PERF-020 is 0.5 ms.
The budget is met by spreading the requests, not by a faster search; eight frames of latency for the last bot is 133 ms, under a deliberation period.

### FR-BOT-170 — Interrupts grant a slot at once

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-160]
depends_on: [FR-BOT-050]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a bot takes damage, sees the snake within the interrupt distance of the bot configuration, sees an ally die, empties its magazine, loses the cover it occupies, witnesses an eating, finds a snake-marked body, or receives a new order, the system **shall** give that bot the next deliberation slot ahead of the queue.

**Rationale.** Concept §9.2 lists these seven events; without them the snake eats a bot that keeps shooting the other way for another 100 ms.
One act over an enumerated set of triggers, as the standard's exit-code example: splitting would destroy the claim that these are all of them.

## Reaction to the snake

### FR-BOT-180 — Calm squads do not hunt the snake

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-SCORE-130, FR-BOT-120]
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a squad's awareness is *calm*, the system **shall** exclude the snake from its bots' target choice except where FR-BOT-120 applies.

**Rationale.** Concept §6.3: on *calm* the snake does not exist for the commander; a bot still reacts to a snake in its face.

### FR-BOT-190 — Alarmed squads keep together

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-SCORE-130]
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a squad's awareness is *alarm*, the system **shall** raise the utility of positions within the grouping distance of the bot configuration from a squadmate.

**Rationale.** Concept §6.3: on *alarm* the squad keeps together and checks corners.
Corner-checking is left to the commander's orders; keeping together is the observable behaviour a test can measure by distances.

### FR-BOT-210 — A whole bot is still afraid of the snake

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-050, IF-BOT-010]
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/DeliberationTests.swift]
created: 2026-09-23
```

When scoring a bot's flight from the snake, the system **shall** raise the score as the snake comes nearer, whatever health the bot has left.

**Rationale.** Concept §13 stage 1 lists what the stage has to show: the bots see the snake, run, shoot and deal damage. Running was the one of the four that could not happen at all — flight was scored as the fear of a wound already taken, which is nothing while the bot is whole, and nothing but the snake's mouth ever wounds a bot.
Concept §9.2 says a bot with panic 0.8 overestimates the threat and runs; a weight that multiplies zero leaves the personality visible in the configuration and absent on screen.
The fear of an unhurt bot is a number of the bot configuration (IF-BOT-010) rather than a constant here: how brave the squads are is the feel the maintainer tunes (§12), and it is the first number this requirement makes worth turning.
Observed on the device on 2026-09-23: the squads held their ground, and what movement there was read as stepping aside for a better shot.

## Repertoire

### FR-BOT-200 — The actions a bot can choose from

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-010]
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Action.swift, Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/DeliberationTests.swift]
created: 2026-09-21
```

When scoring actions for a bot, the system **shall** score at least these: fire at the current target, move to a cover position, move to an ordered zone, flee from the snake, reload, and — for a medic — heal a squadmate within reach.

**Rationale.** Concept §13 stage 1: bots see the snake, run, shoot; §8: the medic stays behind and heals; §9.2 names cover, line of fire and ammunition as inputs, which presuppose cover, fire and reload as actions.
One act over the minimum set; an archetype may add actions, and the set is the floor a test can enumerate.

## Knowledge

What a bot knows, and how it comes to know it (ADR-0032): what it has seen itself, from the start of the match on; what its squad has told it is in the next requirements of this section.
How a bot sees is FR-BOT-050's: a clear line from its eyes within the detection range.

### FR-BOT-220 — A bot acts on what it knows

```yaml
status: partial
verification: T
derives_from: []
depends_on: [FR-BOT-050, FR-BOT-230, FR-BOT-240, FR-BOT-250]
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Knowledge.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/KnowledgeTests.swift, Tests/CrawlCallTests/DeliberationTests.swift]
created: 2026-09-25
```

When scoring actions for a bot, the system **shall** read the snake, the enemy and the map only from that bot's knowledge.

**Rationale.** The maintainer's rule of 2026-09-25: a bot's movement must not rest on what the snake sees, since a bot is not the snake and cannot know it, nor on where anything truly is beyond what the bot has perceived (ADR-0032).
A test holds it by moving the snake or an enemy where the bot has not seen it and nobody has told it, and finding the choice unchanged.
The snake a bot flees from and hides from is where it last saw each part; it fires only at a part it sees now, since what it remembers is somewhere to be afraid of and not a target; the cells it may run or hide to are the cells it knows (ADR-0043).
`partial` because two readings of the map are still the truth's: the route to a chosen cell is found over the whole map, and whether a cell is cover is tested against the obstacles as they stand, seen or not. ADR-0032 replaces both — floods over the map as the squad knows it, and a lines-of-fire table — each to be written as its own requirement and put to the maintainer.
The enemy is recorded (FR-BOT-240) and read by no action yet, since none of FR-BOT-200 is aimed at an enemy bot. The order in which bots are given slots still reads how near the snake truly is (FR-BOT-160): that is when a bot thinks, not what it chooses.

### FR-BOT-230 — A bot remembers the map it has seen

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-050, FR-MAP-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Perception.swift, Sources/CrawlCall/Bot/Knowledge.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/KnowledgeTests.swift]
created: 2026-09-25
```

When a cell of the map is within a bot's field of view and within the detection range of the bot configuration, the system **shall** record in that bot's knowledge what stands in the cell and when it was seen, the latest sighting replacing the one before.

**Rationale.** The maintainer, 2026-09-25: a bot learns the map as it sees it and, once it has seen it, remembers it (ADR-0032).
The same sight as the snake's (FR-BOT-050), so that a bot cannot know a cell it could not have seen; the latest sighting wins, so that a crate a bot saw fall to debris (FR-MAP-030) is debris in what it knows once it has seen that.
A bot looks round once a deliberation period (FR-BOT-150), at the near side of each cell just off its ground, so that a wall is seen by its face and a floor by its near edge (ADR-0043).

### FR-BOT-240 — A bot remembers the enemy it has seen

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-050]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Perception.swift, Sources/CrawlCall/Bot/Knowledge.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/KnowledgeTests.swift]
created: 2026-09-25
```

When an enemy bot is within a bot's field of view and within the detection range of the bot configuration, the system **shall** record in that bot's knowledge where the enemy was seen and when, the latest sighting of each enemy replacing the one before.

**Rationale.** The maintainer, 2026-09-25: movements of the enemy are learnt when a bot sees them and remembered (ADR-0032).
Apart from the map's cells because the two are built and tested apart; the snake's own sightings are FR-BOT-050's.
What a bot looks at is the enemy's eyes, the part of it that shows over cover first.

### FR-BOT-250 — What a bot knows at the start

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Squads.swift, Sources/CrawlCall/Bot/Knowledge.swift]
tests: [Tests/CrawlCallTests/KnowledgeTests.swift]
created: 2026-09-25
```

When a match starts, the system **shall** give each bot knowledge of the outline and floors of the building it fights in, of the ways between those floors, and of the area the enemy squad starts in, and of nothing else of the map, the enemy or the snake.

**Rationale.** The maintainer, 2026-09-25: a bot knows the map roughly at the start — the shape of the ground, the large buildings, roughly where the enemy squad is — and the rest as it sees it (ADR-0032).
The ways between floors are part of the building's shape: a bot that did not know them could plan no route to a floor it has not been on, since a cell it has not seen is taken as passable but a way up is not a cell.
The island around the arena is scenery and takes no part in play (FR-MAP-130), so the ground a bot fights on is the building.
The ways between floors are the cells of the flights of stairs; the enemy's area is the circle round the other squad's spawn cells, one cell wider than the farthest of them (ADR-0043).

### FR-BOT-260 — Forgetting is possible and off

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [IF-BOT-010, FR-BOT-050, FR-BOT-240]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Knowledge.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Configurations.swift, config/bot.json]
tests: [Tests/CrawlCallTests/KnowledgeTests.swift]
created: 2026-09-25
```

Where the bot configuration sets a time after which a sighting of the snake or of the enemy is forgotten, the system **shall** drop from a bot's knowledge each such sighting older than that time.

**Rationale.** The maintainer, 2026-09-25: nothing needs forgetting, but forgetting the snake and the enemy is to be possible (ADR-0032).
Where no time is set nothing is forgotten; the map is never forgotten, only replaced by what is seen later (FR-BOT-230).

### FR-BOT-270 — A bot walks straight where it can

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-MAP-020, FR-MAP-025]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/BotPathTests.swift]
created: 2026-09-25
```

When a bot walks to a destination, the system **shall** take it in a straight line between points of its route wherever the bot's body can pass between them over level ground, rather than from cell to cell.

**Rationale.** The maintainer, 2026-09-25: the bots' movement is to look better, and the first of its steps. A route found over the grid runs from cell to cell, joined side by side (FR-MAP-020), so a bot going anywhere but along a row or a column walked a staircase or an L. ADR-0016 had promised that paths would be smoothed over cell corners so that bots do not walk in staircases; the code never did it.
The body the bot passes with is the one FR-MAP-025 makes common to the snake and the bots, so that a shortcut never takes a bot through a gap the grid would not.
Over level ground only: up a flight or down a step the route keeps to its cells, whose heights are the steps' (FR-MAP-150). How the line is found is ADR-0042.

### FR-BOT-280 — A bot turns to face where it goes

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-270, FR-BOT-060, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Squads.swift, Sources/CrawlCall/View/BotEntity.swift, Sources/CrawlCall/Config/Utility.swift, Sources/CrawlCall/Config/Configurations.swift, config/bot.json]
tests: [Tests/CrawlCallTests/BotFacingTests.swift]
created: 2026-09-25
```

While a match is running, the system **shall** turn each bot, no faster than the turn speed of the bot configuration, to face the way it is walking, or while it fires the point it fires at, each bot starting the match facing the other squad.

**Rationale.** The maintainer, 2026-09-25: the second step of the bots' movement. A figure that never turns slides sideways and backwards, and a character that faces where it goes reads as going there.
A facing of the model's and not only the drawing's, because what a bot can see is to depend on it: its field of view (FR-BOT-050) is measured from where it faces.
No faster than a turn speed, so that a bot swings round rather than snapping; facing the other squad at the start, because the two are at war (FR-BOT-020) and the enemy is what a soldier watches for.

### FR-BOT-290 — A bot gathers speed and slows to a stop

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-270, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Config/Configurations.swift, config/bot.json]
tests: [Tests/CrawlCallTests/BotMotionTests.swift]
created: 2026-09-25
```

While a match is running, the system **shall** bring each bot up to its run speed and down again at the acceleration of the bot configuration, coming to rest where its route ends.

**Rationale.** The maintainer, 2026-09-25: the fifth step of the bots' movement. A bot that is at full speed in its first frame and stopped dead in its last moves like a cursor, not a body.
Only how fast the speed is reached changes, not the speed: a bot runs as fast as its archetype runs, so the chase the snake is built around is the same (INV-SNAKE-020). A bot that stops walking for another action — to fire — stops at once, since it has no route left to roll along.

### FR-BOT-300 — Bots do not pass through one another

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-MAP-025, FR-MAP-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift]
tests: [Tests/CrawlCallTests/BotMotionTests.swift]
created: 2026-09-25
```

While a match is running, the system **shall** keep any two bots on the same floor at least two body radii apart, moving neither onto ground no bot can stand on.

**Rationale.** The maintainer, 2026-09-25: part of the fifth step of the bots' movement. Two figures standing inside each other read as a mistake, and a squad that walks through itself is not a squad of bodies.
Two body radii, the radius FR-MAP-025 makes common to the snake and the bots. Each bot of a pair that has come too close gives way by half of what they overlap, where it can stand; a bot the snake is eating does not move (FR-SNAKE-090), and the other gives way by all of it.

### FR-BOT-310 — A squad hears what its bots have seen after a delay

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-050, FR-BOT-230, FR-BOT-240, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Knowledge.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Configurations.swift, config/bot.json]
tests: [Tests/CrawlCallTests/KnowledgeTests.swift]
created: 2026-09-25
```

When a bot has seen the snake, an enemy bot or a cell of the map, the system **shall** add that sighting to the knowledge of every other bot of its squad once the share delay the bot configuration sets for that squad has passed since the sighting, a later sighting of the same thing winning over an earlier one.

**Rationale.** The maintainer, 2026-09-25: what a bot sees reaches its squad after a delay (ADR-0032). A squad whose bots cannot warn one another is not the squad the concept is built on; one that knows at once what its first witness knows leaves the witness's report worth nothing (FR-SCORE-090).
One delay per squad, so that the two squads can be made to differ. The squads pass their records on once a deliberation period, so a report arrives up to one period after its delay (ADR-0043).
A collapsed squad shares nothing more (ADR-0032); squad collapse is not built, and this requirement says nothing about it until it is.
