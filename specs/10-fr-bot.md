# Functional requirements — bots

Archetypes, perception, utility-AI deliberation, time-based scheduling and interrupts, cover and height, destruction by bots.
Source: concept §8 (archetypes), §9.2–9.3 (deliberation, execution), §7 (bots destroy cover), §13 stages 1–3.
Per-frame execution for every bot is INV-BOT-010; that squads never remove bodies is INV-BOT-020; that both squads share one archetype set is INV-BOT-030.

## Squads and archetypes

### FR-BOT-010 — Six archetypes

```yaml
status: draft
verification: I
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The system **shall** provide exactly six bot archetypes: assault, heavy, sapper, scout, sniper and medic.

**Rationale.** Concept §8: the archetypes bind three systems at once — silhouettes, base personality weights and the ability the snake gains (FR-SNAKE-110).
Six is a number the player can learn; the set is the obligation, so this is one requirement and not six.

### FR-BOT-020 — Two squads at war

```yaml
status: draft
verification: T
derives_from: []
depends_on: [FR-BOT-010, IF-BOT-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a match starts, the system **shall** spawn two squads hostile to each other, each with the number of bots the match configuration sets, four by default.

**Rationale.** Concept §1: two warring squads are the strategic layer; §14: start with 4v4 because of thermal budget and readability.
The final squad size is Q-020; whether reinforcements arrive is Q-030.

### FR-BOT-030 — Archetype sets base personality weights

```yaml
status: draft
verification: T
derives_from: [FR-BOT-010]
depends_on: [IF-BOT-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a bot is spawned, the system **shall** initialise its personality weights — aggression, discipline, panic, self-sacrifice — from its archetype's base weights in the bot configuration.

**Rationale.** Concept §8 table: assault aggression up; heavy discipline up, panic down; scout panic up; sniper discipline up; medic self-sacrifice up; sapper average.
The commander later adjusts these (FR-CMD-060); the archetype is where they start.

### FR-BOT-040 — One bot per squad holds the commander role

```yaml
status: draft
verification: T
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a match starts, the system **shall** designate exactly one bot in each squad as the holder of the commander role.

**Rationale.** Concept §9.4 and §14: eating the bot that holds the role collapses the squad (FR-CMD-120), and it is the player's main lever on the balance of the war.
Whether the role is its own archetype or is assigned to any bot is Q-100; this requirement holds either way.

## Perception and fire

### FR-BOT-050 — A bot notices the snake in view

```yaml
status: draft
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When any segment of the snake is within a bot's field of view and within the detection range of the bot configuration, the system **shall** mark the snake as known to that bot.

**Rationale.** Concept §13 stage 1: bots see the snake, flee, shoot.
Known-to-a-bot is what deliberation (FR-BOT-080) and the interrupt on sight (FR-BOT-150) read.

### FR-BOT-060 — A bot fires at its target

```yaml
status: draft
verification: T
derives_from: []
depends_on: [FR-BOT-080]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a bot's chosen action is to fire and it has a line of fire to its target, the system **shall** deal the target the damage per shot of the bot's weapon in the bot configuration.

**Rationale.** Concept §1: bots are fast, armed and organised.
A target may be an enemy bot or any segment of the snake — shooting at the tail is a meaningful action because of FR-SNAKE-070.

### FR-BOT-070 — Heavy and sapper weapons destroy cover

```yaml
status: draft
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
status: draft
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a bot receives a deliberation slot, the system **shall** select the action with the highest utility score among those available to it, the score being a function of distance to cover, health, the snake's position, line of fire and ammunition.

**Rationale.** Concept §9.2: every possible action gets a numeric utility; the maximum is chosen.
The inputs are named so that a test can vary each and observe the choice move; their weighting is tuning.

### FR-BOT-090 — Personality weights multiply utility

```yaml
status: draft
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-030]
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When computing a bot's utility scores, the system **shall** apply the bot's personality weights as multipliers: panic scaling threat terms up, discipline scaling hold-position terms up, aggression scaling attack terms up, self-sacrifice scaling protect-ally terms up.

**Rationale.** Concept §9.2: a bot with panic 0.8 overestimates the threat and runs; with discipline 0.9 it holds even when scared.
This is the only channel through which the commander's LLM output reaches per-frame behaviour.

### FR-BOT-100 — Cover is valued by what is left of it

```yaml
status: draft
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
status: draft
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
status: draft
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
status: draft
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-SNAKE-010]
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When scoring a position, the system **shall** raise the score with the length of the navigation-mesh path the snake's head would need to reach it.

**Rationale.** Concept §13 stage 2: bots retreat to floors the snake takes long to reach — a different thing from being above it, since a balcony over the snake may be one ramp away.

### FR-BOT-120 — Nearby snake overrides the commander's priority

```yaml
status: draft
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
status: draft
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
status: draft
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
status: draft
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The system **shall** advance deliberation on a fixed-step accumulator of the deliberation period in the bot configuration, so that the number of deliberation slots per simulated second is the same at any frame rate.

**Rationale.** Concept §9.2: "one bot per frame" makes bots think twice as fast at 120 Hz and half as fast at 30, and difficulty then depends on the hardware.
Verifiable by running the same scenario at two frame rates and counting slots.

### FR-BOT-160 — Slots go by priority, not round-robin

```yaml
status: draft
verification: T
derives_from: [FR-BOT-150]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When choosing which bot deliberates next, the system **shall** take the bot with the greatest product of frames-since-last-update and importance, where the importance of a bot in combat or within snake range is at least three times that of an idle bot.

**Rationale.** Concept §9.2: a bot in combat or near the snake gets a slot 3–4 times more often than one patrolling an empty floor; the same rule gives AI level-of-detail for free — distant bots think about once a second.
The per-frame budget that bounds how many slots a frame hands out is NFR-PERF-020.

### FR-BOT-170 — Interrupts grant a slot at once

```yaml
status: draft
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
status: draft
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
status: draft
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

## Repertoire

### FR-BOT-200 — The actions a bot can choose from

```yaml
status: draft
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-010]
refines: [FR-BOT-080]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When scoring actions for a bot, the system **shall** score at least these: fire at the current target, move to a cover position, move to an ordered zone, flee from the snake, reload, and — for a medic — heal a squadmate within reach.

**Rationale.** Concept §13 stage 1: bots see the snake, run, shoot; §8: the medic stays behind and heals; §9.2 names cover, line of fire and ammunition as inputs, which presuppose cover, fire and reload as actions.
One act over the minimum set; an archetype may add actions, and the set is the floor a test can enumerate.
