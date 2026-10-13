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

### FR-BOT-350 — The squads start at opposite ends of the island

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-020]
depends_on: [IF-BOT-010]
refines: [FR-BOT-020]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Squads.swift]
tests: [Tests/CrawlCallTests/BotTests.swift]
created: 2026-09-29
```

When a match starts, the system **shall** place the two squads, one at each, around the two walkable cells that lie farthest apart across the ground among those the snake's start reaches outside its interrupt distance.

**Rationale.** The maintainer's wish of 2026-09-29: a match opens with the two squads apart, so the war begins with a crossing rather than with both squads in one corner.
Measured across the ground, since the ends of an island are where it is widest, not where the walk is longest.
Cells within the interrupt distance are excluded so that no squad begins the match alarmed.
Where a map will name each squad's area (Q-360), that area replaces this.
Which squad takes which end, and how each fills round it, is ADR-0056.

### FR-BOT-030 — Archetype sets base personality weights

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-010]
depends_on: [IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Bot.swift, config/bot.json]
tests: [Tests/CrawlCallTests/BotTests.swift]
created: 2026-09-21
```

When a bot is spawned, the system **shall** initialise its personality weights — aggression, courage, discipline, panic, self-sacrifice — from its archetype's base weights in the bot configuration.

**Rationale.** Concept §8 table: assault aggression up; heavy discipline up, panic down; scout panic up; sniper discipline up; medic self-sacrifice up; sapper average.
The commander later adjusts these (FR-CMD-060); the archetype is where they start.
Courage joined the weights on 2026-09-25 (FR-BOT-090); the concept's table predates it, so each archetype's base courage is tuning, chosen when it was built on 2026-10-11 from the table's behaviour column instead — the heavy guarded and slow holds at 0.8, the scout that runs stands at 0.3, the medic behind the others at 0.4, the assault that presses at 0.7, the sapper and the sniper average (ADR-0074).

### FR-BOT-040 — One bot per squad holds the commander role

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Squads.swift, Sources/CrawlCall/Bot/Bot.swift]
tests: [Tests/CrawlCallTests/BotTests.swift]
created: 2026-09-21
```

When a match starts, the system **shall** designate exactly one bot in each squad, of any archetype the match configuration allows, as the holder of the commander role, without marking it visually.

**Rationale.** Concept §9.4 and §14: eating the bot that holds the role collapses the squad (FR-CMD-120), and it is the player's main lever on the balance of the war.
A role rather than a seventh archetype, and no marker: the role-holder is found by listening — he is the one who speaks the orders (ADR-0011, FR-CMD-140).
Built on 2026-10-11 (ADR-0076): the role goes to the lowest-numbered bot of the squad whose archetype the configuration admits, and an empty list of eligible archetypes admits every one of them, since the list is there to exclude.
Nothing draws the flag, and nothing can: a figure is built from an archetype and never from a bot.

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
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-080]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Bot/Round.swift, Sources/CrawlCall/Config/Utility.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/ExecutionTests.swift, Tests/CrawlCallTests/ShotTests.swift, Tests/CrawlCallTests/WarTests.swift, Tests/CrawlCallTests/RoundTests.swift]
created: 2026-09-21
```

While a bot's chosen action is to fire and it has a line of fire to its target, the system **shall** send a round from the bot's eyes towards the point where the target is at that moment, at the round speed of the bot configuration.

**Rationale.** Concept §1: bots are fast, armed and organised.
A target may be an enemy bot or any segment of the snake — shooting at the tail is a meaningful action because of FR-SNAKE-070.
A line of fire leaves from the bot's eyes, the height it looks from (FR-BOT-050): what a bot can see over, it can shoot over, and a line of sight it could not fire along would be a bot that watches the snake and cannot touch it (ADR-0022).

**Fire at an enemy bot**, since 2026-09-26, when the maintainer asked for the squads to fight: a bot fires at an enemy it sees now, its line of fire running to the enemy's eyes (ADR-0044). Until then only the snake was fired at, the vertical slice asking for the snake and the hunt alone (concept §13 stage 1).
A shot goes off once per deliberation step rather than once per frame, so that the damage a second does not depend on the frame rate. No requirement gives a weapon a rate of fire; when one does, the cadence moves out of the deliberation period and into the bot configuration.

**A round flies**, since 2026-09-30. Until then a shot struck in the step it was fired, and a bot that moved was hit as surely as one that stood, so two bots stood face to face and fired until one fell. The maintainer asked for bots that avoid danger — fire from cover, or at least keep moving — and chose a round with a speed over a chance to hit: a round sent at where the target is now misses a target that has moved on, with nothing left to chance (ADR-0063). What the round strikes is FR-BOT-400's; where it stops, FR-BOT-405's.
At the shipped 25 m/s a round crosses the six metres most bots see in a quarter of a second, in which a bot moving across the line at the strafing speed (FR-BOT-430) is half a metre aside, more than the body radius from its middle to its side; nearer than 3.75 m it is struck moving or not.

### FR-BOT-400 — A round strikes the first body in its way

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-060]
depends_on: [FR-BOT-060, FR-BOT-320]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Flight.swift, Sources/CrawlCall/Bot/Round.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/RoundTests.swift, Tests/CrawlCallTests/WarTests.swift]
created: 2026-09-30
```

While a round is in flight, the system **shall** deal the damage per shot of the weapon that fired it to the first living bot of either squad, other than the one that fired it, or segment of the snake that its path crosses, and end its flight there.

**Rationale.** The maintainer, 2026-09-30, choosing what a miss does: it flies on and strikes whoever is in its way, the enemy, a squadmate or the snake. A round that could not strike a squadmate would make standing in a squadmate's line of fire free; FR-BOT-410 is the other side of it.
A bot is struck within the body radius of the tuning round the ground it stands on, up to its figure's height; the snake within the body radius round the line through its head and tail points (ADR-0063). A body — a bot with no health left (FR-BOT-320) — is not struck: it lies flat, below a round sent at a standing bot's eyes, and the flight leaves it out altogether (ADR-0063). The maintainer agreed on 2026-09-30 that the statement say "living".

### FR-BOT-405 — A round stops at what it meets

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-060]
depends_on: [FR-BOT-060, FR-MAP-220]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Flight.swift, Sources/CrawlCall/Map/Sight.swift, Sources/CrawlCall/Config/Configurations.swift]
tests: [Tests/CrawlCallTests/RoundTests.swift]
created: 2026-09-30
```

When a round's path meets map geometry, or the round has flown the round range of the bot configuration, the system **shall** end its flight without damage.

**Rationale.** A round that flew on for ever would strike a bot across the island that never saw the fight. Map geometry is what stops a line of sight (FR-MAP-220), because a line of fire is one (ADR-0022): what a bot sees over, a round flies over.
The range, 20 m at the shipped numbers, is over three times the six metres most bots see and over twice the sniper's nine, so a miss is still a danger to whoever stands behind the target, and short enough that a round is spent in under a second.

### FR-BOT-410 — A bot does not fire through a squadmate

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-400]
depends_on: [FR-BOT-400, FR-BOT-050]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/RoundTests.swift]
created: 2026-09-30
```

While a squadmate the bot sees stands within the body radius of its line of fire to its target, the system **shall** not have the bot fire.

**Rationale.** Once a round strikes whoever is in its way (FR-BOT-400), a squad in file would shoot itself to pieces. A squadmate it sees, because a bot acts on what it knows (FR-BOT-220): one it does not see is one it cannot know to be in the way.
A target with a squadmate in the way is no target: the bot fires at another, or does something else. The snake within the override distance is taken whatever else there is (FR-BOT-120), except that it is not fired at through a squadmate.

### FR-BOT-070 — Heavy and sapper weapons destroy cover

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-060]
depends_on: [FR-MAP-030, IF-MAP-020, FR-BOT-470]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a heavy's or a sapper's shot hits a destructible module, or a grenade detonates within its blast radius of one, the system **shall** deal that module the destruction damage the tuning configuration sets for that weapon, while the weapon's destruction ammunition lasts.

**Rationale.** Concept §7: without bots that destroy, destruction is one-sided and a squad can dig in behind a wall and wait; the main scenario is squads taking the map apart fighting each other.
Ammunition is the regulator the concept names against a map that turns into wasteland by mid-match.
The grenade joined on 2026-10-11, when the maintainer settled what a bot carries (FR-BOT-440): a grenade does not bring a wall down in one throw but weakens it, and enough of them break it.
That is FR-MAP-030's shape already — a module's damage accumulates and it steps from intact to damaged to debris — so the grenade needs no health of its own for cover, only a share of that accumulated damage.
Rounds from a primary or a sidearm still leave a module alone: destruction is the heavy's and the sapper's trait in concept §8, and FR-BOT-105, which prices cover by whether the enemy carries a wrecking weapon, stops saying anything if every rifle is one.

## Arms

### FR-BOT-440 — What a bot carries

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-010]
depends_on: [IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Arms.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Config/Configurations.swift, config/bot.json]
tests: [Tests/CrawlCallTests/ArmsTests.swift]
created: 2026-10-11
```

When a bot is spawned, the system **shall** give it the arms its archetype names in the bot configuration: one primary weapon, one sidearm, that archetype's number of grenades, and one knife.

**Rationale.** The maintainer, 2026-10-11, settling Q-310: until then a bot had a magazine and nothing else, and FR-BOT-080 named what it has to fight with as an input no code could read.
Four kinds, because each answers a different distance — the primary reaches furthest and hurts most, the sidearm is the lighter weapon beside it, the grenade crosses what a bot cannot shoot through, and the knife works at a touch (ADR-0075).
Which weapon an archetype carries and how many grenades it starts with is tuning and lives in the bot configuration beside the personality weights, so that two archetypes may carry different sidearms without either being named here.
One knife and not a number of them, because a thrown knife is gone (FR-BOT-520) and a bot that could throw six would never close with anything.

### FR-BOT-450 — A shot's numbers are the weapon's

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-060]
depends_on: [FR-BOT-440, IF-BOT-010]
refines: [FR-BOT-060]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Arms.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Config/Utility.swift, Sources/CrawlCall/Config/Configurations.swift, config/bot.json]
tests: [Tests/CrawlCallTests/ArmsTests.swift, Tests/CrawlCallTests/ExecutionTests.swift, Tests/CrawlCallTests/InterruptTests.swift]
created: 2026-10-11
```

When a bot fires, the system **shall** take the damage, the range, the time between shots and the magazine size of that shot from the weapon fired rather than from the bot's archetype.

**Rationale.** Today those numbers are the archetype's and a bot has one weapon, so where they live costs nothing; with two firearms on the same bot it is the whole of it, since a sidearm weaker and shorter-ranged than the primary cannot be described by numbers belonging to the bot.
The time between shots is on this list because FR-BOT-060's rationale parked it — "no requirement gives a weapon a rate of fire; when one does, the cadence moves out of the deliberation period and into the bot configuration" — and a sidearm that trades damage for rate of fire is what makes it worth moving (the maintainer, 2026-10-11).
What a bot sees is still the archetype's: how far it looks is about eyes, not about what it holds.

### FR-BOT-460 — Each weapon that reaches is an action of its own

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-440]
refines: [FR-BOT-200]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Action.swift]
tests: [Tests/CrawlCallTests/ArmsTests.swift]
created: 2026-10-11
```

When scoring actions for a bot, the system **shall** score using each weapon it carries that has ammunition left and whose range covers its target as an action of its own.

**Rationale.** FR-BOT-080 chooses by maximum utility, so which weapon to use is not a rule to write down but a set of actions to score: the primary at distance, the sidearm when the primary is empty or the target is close, the grenade at something a wall stands in front of, the knife at a touch.
A rule — "the primary where it reaches, the sidearm otherwise" — would be a second decision procedure beside the one the whole layer is built on, and the personality weights would stop reaching the choice.
This widens the floor FR-BOT-200 sets: the set a test can enumerate gains an entry per weapon where it had one for firing.

### FR-BOT-470 — A thrown grenade flies no further than its throw and waits out its fuse

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-440]
depends_on: [IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Blast.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Arms.swift, Sources/CrawlCall/Bot/Action.swift, Sources/CrawlCall/Game.swift, config/bot.json]
tests: [Tests/CrawlCallTests/GrenadeTests.swift]
created: 2026-10-11
```

When a bot throws a grenade, the system **shall** send it no further than that grenade's throw range and detonate it when its fuse time has passed.

**Rationale.** The two numbers the maintainer named on 2026-10-11: a grenade goes a short way and goes off after a delay.
The delay is what makes it answerable — a bot can leave the place, the snake can move on, and a grenade thrown where something stood is not a grenade that hits it.
The path it takes is not fixed here: that a thrown thing rises and falls is drawing, and what it meets on the way is the round's question already answered (FR-BOT-405).

### FR-BOT-480 — An explosion strikes every body within its blast

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-470]
depends_on: [FR-BOT-470, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Blast.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/GrenadeTests.swift]
created: 2026-10-11
```

When a grenade detonates, the system **shall** deal its damage to every bot and every part of the snake within its blast radius, the thrower and its squadmates among them.

**Rationale.** The maintainer, 2026-10-11: any weapon hits your own.
For a round that has been true since FR-BOT-400 — it strikes whoever is in its way — and an explosion that made an exception for the squad would be the one weapon a bot could throw without care, which is the opposite of what a grenade is for.
What the blast does to a destructible module is FR-BOT-070's; what it does to a snake lying across it is FR-BOT-490's; and what keeps a bot from throwing it at its own squad is FR-BOT-500's.

### FR-BOT-490 — An explosion that covers more of the snake hurts it more

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-480]
depends_on: [FR-BOT-480, FR-SNAKE-070, IF-BOT-010]
refines: [FR-BOT-480]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Blast.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/GrenadeTests.swift]
created: 2026-10-11
```

When a grenade detonates with more than one part of the snake within its blast radius, the system **shall** raise the damage dealt to the snake by the per-part share of the bot configuration for each part beyond the first, and deal the raised amount once.

**Rationale.** The maintainer, 2026-10-11, choosing between two readings that were both on the table.
Damage once per part makes the grenade the answer to a long snake and takes away the bet the concept is built on, that length is the player's trade (§4); damage once makes a blast laid along the whole body worth no more than one at the tail tip.
A share for each part beyond the first sits between them: at the 15 to 20 per cent the maintainer named, a blast over five parts is worth about 1.6 to 1.8 blasts and never five.
Once, because the snake is wounded and not wounded five times: FR-SNAKE-070 takes the tail off by the raised amount in one act.
The share is tuning and lives in the bot configuration, where the grenade's other numbers are.

### FR-BOT-500 — A bot does not throw where it would catch a squadmate

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-480]
depends_on: [FR-BOT-480, FR-BOT-220]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/GrenadeTests.swift]
created: 2026-10-11
```

If a squadmate the bot sees stands within the blast radius of the place a bot aims a grenade at, the system **shall not** have the bot throw it.

**Rationale.** The other side of FR-BOT-480: once an explosion hits its own, a squad that fights as a group (FR-BOT-190) would take itself apart in the first firefight.
The same shape as FR-BOT-410 for a round, and the same reading of what a bot may act on — a squadmate it does not see is one it cannot know to be there (FR-BOT-220).
The thrower itself needs no rule: a place within its own blast is a place its own score already refuses, since the damage falls on it like anybody else.
It was "where it would throw" until 2026-10-13, when a grenade came to fly and bounce (FR-BOT-580, FR-BOT-590) and the place it is aimed at stopped being the place it goes off at. The aim is what it refuses, because the aim is what a bot can know: to refuse the landing it would have to fly every throw it scores before it makes it — a hundred and twenty steps of a sixtieth of a second, each asking the scene what it meets, against a deliberation budget of half a millisecond for everything (NFR-PERF-020).
So a grenade can bounce back onto a squadmate, which is of a piece with every other weapon in the game hitting whoever is in the way (ADR-0075, ADR-0092).

### FR-BOT-510 — A knife strikes what is within its reach

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-440]
depends_on: [FR-BOT-440, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Action.swift, Sources/CrawlCall/Bot/Arms.swift, config/bot.json, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/KnifeTests.swift]
created: 2026-10-11
```

While a bot's chosen action is to strike with its knife and its target is within the knife's reach, the system **shall** deal the knife's damage to that target.

**Rationale.** The maintainer, 2026-10-11: the knife works only very close, and hurts well for it.
It is the one weapon with no flight and no magazine, so it is what a bot has left when everything else is empty and something is already upon it — which is the case the snake makes most often.
No line of fire is asked for, because at the reach of an arm there is nothing to stand in the way.

### FR-BOT-520 — A thrown knife leaves the bot

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-510]
depends_on: [FR-BOT-510]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Action.swift, Sources/CrawlCall/Bot/Arms.swift, config/bot.json]
tests: [Tests/CrawlCallTests/KnifeTests.swift, Tests/CrawlCallTests/FigureTests.swift]
created: 2026-10-11
```

When a bot throws its knife, the system **shall** take the knife from what the bot carries, whether the throw struck or not.

**Rationale.** The maintainer, 2026-10-11: a knife reaches a little further thrown, and is spent by the throw.
That is what makes the throw a decision rather than a free extra range — a bot that threw has nothing for the next thing that closes with it, and the score of throwing has to carry that.
Nothing picks it up again: there is no gathering in this game, and a thrown knife is gone for the match.

### FR-BOT-540 — Each firearm that is not full is a reload of its own

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-425]
depends_on: [FR-BOT-440, FR-BOT-460, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Arms.swift, Sources/CrawlCall/Bot/Action.swift, Sources/CrawlCall/Config/Utility.swift, config/bot.json]
tests: [Tests/CrawlCallTests/ReloadTests.swift, Tests/CrawlCallTests/DeliberationTests.swift]
created: 2026-10-13
```

When scoring the actions open to a bot, the system **shall** score reloading each firearm the bot carries that is not full and has a spare magazine left as an action of its own.

**Rationale.** The maintainer, 2026-10-13: a reload is to cost time, and the time is the weapon's own — which a single act that fills everything a bot carries cannot have, since the primary's is to be the longer one.
So the reload takes the shape fire already has (FR-BOT-460): one action per weapon, and the chooser decides which magazine is worth filling now.
That a firearm with no spare magazine left is not offered at all belongs here rather than in a second sentence: there is nothing to reload it with, and an action with nothing to act on is not on the list.

### FR-BOT-550 — A reload takes the weapon's own time

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-540]
depends_on: [FR-BOT-540, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Bot/Arms.swift, Sources/CrawlCall/Game.swift, config/bot.json]
tests: [Tests/CrawlCallTests/ReloadTests.swift, Tests/CrawlCallTests/SkirmishTests.swift, Tests/CrawlCallTests/ExecutionTests.swift]
created: 2026-10-13
```

When a bot has chosen to reload a firearm and has chosen nothing else since, the system **shall** fill that firearm's magazine once that firearm's reload time has passed.

**Rationale.** The maintainer, 2026-10-13: reloading the primary is to take longer.
A reload that takes no time is a free choice, and a free choice is no choice at all — the same argument eating stands on (FR-SNAKE-090), and the reason a bot with a dry rifle reloads instead of drawing anything it carries.
It does not hold the bot where it stands, as eating holds the snake: a bot can walk while it reloads and can be interrupted (FR-BOT-170), and a bot frozen for two seconds while the snake arrives is the standing still the concept calls the signature stupidity.
"Has chosen nothing else since" is the whole of it: a bot that ducks out, fires and ducks back has gained nothing and starts again, because a reload that survives being abandoned is free again by another road.

### FR-BOT-560 — A bot carries a limited number of spare magazines

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-540]
depends_on: [FR-BOT-550, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Arms.swift, Sources/CrawlCall/Bot/Execution.swift, config/bot.json]
tests: [Tests/CrawlCallTests/ReloadTests.swift]
created: 2026-10-13
```

When a bot's reload fills a firearm's magazine, the system **shall** take one spare magazine for that firearm from what the bot carries.

**Rationale.** The maintainer, 2026-10-13: the number of spare magazines is to be limited, and three may be enough.
What it buys is a fight that cannot go on for ever at the same cadence: a bot out of spares has a weapon it can empty once and then nothing but what else it carries (FR-BOT-440).
Nothing picks a magazine up again, for the reason a thrown knife is gone for the match (FR-BOT-520): there is no gathering in this game.

### FR-BOT-570 — A bot closes with what its weapon does not reach

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-460]
depends_on: [FR-BOT-440, FR-BOT-530, FR-BOT-090]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Action.swift, Sources/CrawlCall/Bot/Execution.swift]
tests: [Tests/CrawlCallTests/RushTests.swift]
created: 2026-10-13
```

When nothing a bot carries reaches a target it sees from where it stands, and a cell it can reach would bring that target within the range of a weapon it can still use, the system **shall** score moving to that cell as an action of its own.

**Rationale.** The maintainer, 2026-10-13: the choice between hiding to reload and drawing the pistol or the knife to run in should depend on the bot's courage.
This is the second half of that choice, and it is shaped like FR-BOT-460 rather than like an order to charge: each weapon that reaches is already an action of its own, and this is each weapon that *would* reach, scored by the same chooser.
A bot with a loaded primary is not a candidate, since its weapon reaches already, so this never turns a firefight at range into a rush. The bot it describes is the one with a dry rifle, a pistol good for six metres and an enemy at eight — and whether it goes depends on how brave it is (FR-BOT-090) and on what else there is to do.
The cell is subject to FR-BOT-530 like any other, so a bot never rushes to where a squadmate is already going.
The statement said "a weapon whose range does not cover its target" when it was written on 2026-10-13 and was narrowed to "nothing it carries reaches" the same day, while it was being built: a knife reaches an arm's length, so the looser words obliged a bot with a loaded rifle and an enemy three metres off to score running at it with a knife — and it chose to, which twelve tests of the firefight said at once. What the maintainer asked for is the bot that has nothing left, and that is what the words now say (ADR-0091).

### FR-BOT-580 — A thrown grenade flies the arc of a thrown thing

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-470]
depends_on: [FR-BOT-470, IF-MAP-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Blast.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Geometry.swift]
tests: [Tests/CrawlCallTests/FlightOfAGrenadeTests.swift]
created: 2026-10-13
```

While a thrown grenade is in the air with fuse left, the system **shall** carry it along a path falling under the tuning's gravity.

**Rationale.** The maintainer, 2026-10-13: a grenade is to be drawn, and it is to have the physics of a thrown thing.
Until now a grenade lay where it was aimed from the moment it was thrown (FR-BOT-470) and only burned its fuse, which is enough for the damage and nothing for the eye.
An arc also makes the throw range a real limit rather than a number: a throw leaves the hands at a speed, and a throw aimed further than that speed carries falls short.
The gravity is the one a falling thing is already given (IF-MAP-020), the same the snake falls under off a ledge (FR-SNAKE-220) — a second gravity in the same arena would be two answers to one question.

### FR-BOT-590 — A thrown grenade bounces off what it meets

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-580]
depends_on: [FR-BOT-580, FR-BOT-405, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Blast.swift, Sources/CrawlCall/Game.swift, config/bot.json]
tests: [Tests/CrawlCallTests/FlightOfAGrenadeTests.swift]
created: 2026-10-13
```

When a thrown grenade in the air meets a surface, the system **shall** turn its course back off that surface, keeping the share of its speed the grenade's restitution sets.

**Rationale.** The maintainer, 2026-10-13: bouncing off surfaces would be good.
A separate requirement from the arc above and not a second clause of it, because each can be built and read on its own: a grenade that falls and stops dead where it lands is a finished behaviour, and so is one that comes back off a wall.
What the step meets is read the way a round's is (FR-BOT-405), and the arena is a grid of axis-aligned modules, so the surface a step met is the cell boundary it crossed.
What it keeps of its speed is tuning and goes with the grenade's other numbers (IF-BOT-010); below a crawl the grenade is at rest and only burns fuse, which is what keeps a grenade from shivering in a corner for its whole fuse.

### FR-BOT-610 — Each weapon's time between uses is its own

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-450]
depends_on: [FR-BOT-440, IF-BOT-010]
refines: [FR-BOT-450]
conflicts_with: []
code: []
tests: []
created: 2026-10-13
```

When a bot uses one of the weapons it carries, the system **shall** count the time until that weapon may be used again from that use alone, and not from the bot's use of any other weapon.

**Rationale.** The maintainer, 2026-10-13, on reading `now - lastShot >= knife.numbers.timeBetweenStrikes`: a bot should be an object with weapon slots, and a weapon an object carrying its own times.
FR-BOT-450 moved the numbers to the weapon and ADR-0086 said the guard was "the weapon's own time between shots"; the clock those numbers are read against stayed on the bot, one field for everything it carries, so firing the rifle pushed the knife's next strike away and striking pushed the rifle's next shot.
At a knife of one second that was a few frames; at the five seconds the knife is worth twenty damage for, it is the difference between a weapon and none — a bot that fires between strikes would never strike again.
It is a requirement and not a repair of one, because what is obliged here is where a clock lives, which no statement said: FR-BOT-450 names the numbers a shot is taken from and is silent about the time it is measured from.
The slot's own guard is not this clock and stays where it is (FR-BOT-170): one act per deliberation period is a property of deliberation, not of a gun.

### FR-BOT-600 — A weapon whose time has not come is not an action

```yaml
status: deferred
verification: T
derives_from: [FR-BOT-460]
depends_on: [FR-BOT-610, IF-BOT-010]
refines: [FR-BOT-460]
conflicts_with: []
code: []
tests: []
created: 2026-10-13
```

When scoring the actions open to a bot, the system **shall** leave out using a weapon whose time between uses has not passed since that weapon was last used.

**Rationale.** The maintainer, 2026-10-13: a ban on taking actions that are forbidden is certainly needed.
Until now a weapon on its own time was offered, chosen and then refused where it is carried out, and the bot stood for that slot: measured over a hundred and fifty seconds of the shipped arena, four strikes in five did nothing, and a bot at the reach of an arm stood in melee instead of firing. Taking the strike off the list instead moved those slots to the pistol — which had never been fired in a whole match — and pushed the first deaths from fifteen seconds to forty-two.
The project already says this of two other actions, which is why the sentence is one requirement and not a principle: a firearm with no round is not an action (FR-BOT-460), a reload with no spare magazine is not one (FR-BOT-540, "an action with nothing to act on is not on the list"), and a throw that would catch a squadmate is not one (FR-BOT-500). The weapon's time is the third case of the same thing and the only one that needs the match's clock in the score.
What it does not touch is the rush (FR-BOT-570): crossing the ground to where a weapon would reach is not a use of the weapon, and a knife that is cooling still reaches by the time the bot arrives.

## Deliberation

### FR-BOT-080 — Action chosen by maximum utility

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Arms.swift, Sources/CrawlCall/Bot/Blast.swift, Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Config/Utility.swift, Sources/CrawlCall/Config/Geometry.swift]
tests: [Tests/CrawlCallTests/ArmsTests.swift, Tests/CrawlCallTests/GrenadeTests.swift, Tests/CrawlCallTests/KnifeTests.swift, Tests/CrawlCallTests/DeliberationTests.swift]
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
The list is the maintainer's, rewritten on 2026-09-25 when they settled what a bot knows (ADR-0032): each input is read from what the bot and its squad have perceived, never from the truth, and courage is a personality weight of its own (FR-BOT-090).
All seven inputs are read: the enemy since the squads went to war on 2026-09-26, as a target and as a danger to hide from (FR-BOT-060, FR-BOT-330, ADR-0044); the fifth personality weight since 2026-10-11 (ADR-0074); and what a bot has to fight with since 2026-10-12, when the arms were built — a primary, a sidearm, grenades and a knife, each of them an action of its own with its own numbers behind it (FR-BOT-440, FR-BOT-460, ADR-0086, ADR-0087, ADR-0088).

### FR-BOT-090 — Personality weights multiply utility

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-030]
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/DeliberationTests.swift, Tests/CrawlCallTests/ReloadTests.swift]
created: 2026-09-21
```

When computing a bot's utility scores, the system **shall** apply the bot's personality weights as multipliers:

- panic, scaling threat terms up;
- courage, scaling the terms for facing danger — firing at it, holding ground under it — up, and the term for stepping out of it to reload down;
- discipline, scaling hold-position terms up;
- aggression, scaling attack terms up;
- self-sacrifice, scaling protect-ally terms up.

**Rationale.** Concept §9.2: a bot with panic 0.8 overestimates the threat and runs; with discipline 0.9 it holds even when scared.
This is the only channel through which the commander's LLM output reaches per-frame behaviour.
Courage was added by the maintainer on 2026-09-25 as a weight of its own, not as the other side of panic: a bot can be frightened and stand its ground anyway, and the two pull on different terms — panic on the fear that sends it away, courage on the terms that keep it facing the danger.
It multiplies firing, every target a bot has being something that can kill it, and the order's term by how near the danger has come — with nothing near, holding a position is obedience and discipline's alone (ADR-0074).
The maintainer added the reload on 2026-10-13, asking that the choice between hiding to fill a magazine and drawing what is left to run in should turn on how brave a bot is: it is the one term courage pulls *down*, and a share of it rather than the whole, so that a bot of whole courage still reloads when there is nothing better to do (FR-BOT-540, ADR-0090).

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
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: []
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Execution.swift]
tests: [Tests/CrawlCallTests/PositionTests.swift]
created: 2026-09-21
```

When scoring a position, the system **shall** raise the score with the position's height above the snake's head.

**Rationale.** Concept §13 stage 2: bots use height — fire from above, retreat to floors the snake takes long to reach.
Without this term the verticality of a map is decoration, which is what H-020 measures.
How the height is counted, and why it decides where a bot goes rather than how much it wants to, is ADR-0058.

### FR-BOT-115 — Distance along the snake's path enters position scoring

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-SNAKE-010]
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Execution.swift]
tests: [Tests/CrawlCallTests/PositionTests.swift]
created: 2026-09-21
```

When scoring a position, the system **shall** raise the score with the length of the shortest navigation-graph path from the snake's head to it.

**Rationale.** Concept §13 stage 2: bots retreat to floors the snake takes long to reach — a different thing from being above it, since a balcony over the snake may be one ramp away.
How the path is counted, from where the bot last saw the snake, is ADR-0058.

### FR-BOT-116 — An order's part of the arena raises what a position is worth

```yaml
status: implemented
verification: T
derives_from: [FR-CMD-040]
depends_on: [FR-BOT-080]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/DeliberationTests.swift, Tests/CrawlCallTests/CommanderOrdersTests.swift]
created: 2026-10-12
```

When scoring a position for a bot whose squad is under an order naming a part of the arena, the system **shall** raise the score the nearer the position lies to that part.

**Rationale.** The maintainer's rule of 2026-10-12: a commander is a strategist and says what matters and where, and the bots work out the tactics — who goes round from where, how to cover the enemy, where to look for cover.
This is the whole mechanism that rule needs. An order stops naming a cell for each bot (ADR-0079) and becomes a fourth term beside the height a position stands at (FR-BOT-110), its distance along the snake's path (FR-BOT-115) and its nearness to a squadmate (FR-BOT-190), so cover is still chosen by what is hidden, flight by what is far and the firing position by what it can see — and every one of them leans towards where the commander pointed.
"The nearer the position lies to that part" and not "a position in that part", because an order has to move a squad that is nowhere near it: a step towards the named quarter has to be worth more than a step away from it, from anywhere in the arena.
Written beside FR-BOT-110 and FR-BOT-115 because it is the same kind of term and belongs with them; the word the order carries and how it reaches the deliberation are FR-CMD-040's.
Built the same day: the deliberation is given the place itself rather than the word for it, and the term runs from a whole at that place to nothing at the arena's far corner, measured against the arena's own span so the same order means the same thing on any map.

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

### FR-BOT-119 — A bot in cover stays in it

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-200]
depends_on: [FR-BOT-330]
refines: [FR-BOT-200]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/DeliberationTests.swift, Tests/CrawlCallTests/IdleTests.swift]
created: 2026-10-12
```

While nothing a bot knows of watches the cell it stands in, the system **shall** leave taking cover out of the actions available to it.

**Rationale.** A bot whose position already shields it from everything it knows of has no business looking for another wall: the maintainer's rule, given on 2026-10-12, and the reading of cover the specification had been missing.
It is also the way out of a standstill that was measured, not argued: the search walks outwards from the bot's own cell and that cell ranks first by nearness, so five bots of eight spent a whole match choosing to take cover where they already stood, at utilities of 0.072 to 0.167, which outscored nothing-at-all and so kept every other motive out of reach (Q-600).
"Somewhere else" would have been the wrong rule twice over — a bot trading a wall that holds for a wall that holds is the signature stupidity concept §9.2 names, and the search already skips a cell an enemy or the snake watches (FR-BOT-330), so a bot whose own cell is watched never gets that cell as the answer anyway. One rule covers both.
What still moves a bot out of cover is a threat or an order, neither of which this statement touches: flight is its own action, holding ground falls as the danger closes (FR-BOT-090, ADR-0074), and an ordered zone is scored by the obedience term whatever cover the bot is in (FR-BOT-130).
Built the same day (ADR-0081): the search asks of the bot's own cell the question it asks of every candidate and answers nothing where nothing watches it, so one rule serves both halves — no action where the bot is hidden, and a watched cell skipped as any other.
Measured from both ends: three tests in `DeliberationTests` pin the rule, and the second minute of a shipped-arena match went from 0 frames of walking and 0.0 m of movement to a squad that walks (`IdleTests`, Q-600). Removing the rule turns all four red.

### FR-BOT-120 — Nearby snake overrides the commander's priority

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-CMD-030]
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/SquadStateTests.swift, Tests/CrawlCallTests/CommanderOrdersTests.swift]
created: 2026-09-21
```

When the snake's head is within the override distance of the bot configuration from a bot, the system **shall** rank the snake as that bot's top threat regardless of the commander's threat priority.

**Rationale.** Concept §9.2: the commander sets the priority, the utility layer corrects it locally — a snake five metres away overrides any order.
It stood `partial` while there was no commander whose priority to override: the snake within the override distance was ranked above everything the bot itself would fire at, which is what overriding the priority meant with nobody giving one (ADR-0060).
Closed on 2026-10-12 with FR-CMD-030, and the override is now the thing it was written to be: the priority ranks the kinds of target, and a snake inside the distance wins ahead of it, told to worry about the enemy or not.

### FR-BOT-130 — Discipline decides how far an order is kept

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-090]
depends_on: [FR-CMD-040]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/CommanderOrdersTests.swift]
created: 2026-09-21
```

When a bot's local threat assessment contradicts the commander's current order, the system **shall** weight the order's utility term by the bot's discipline weight and the local term by one minus it.

**Rationale.** Concept §9.2: discipline determines how much a bot sticks to the order against the local situation.
The formula is the simplest one that makes discipline 1.0 mean "always the order" and 0.0 mean "never".
Built on 2026-10-12 (ADR-0079). The local term is the one the bot's own reading of the danger pays for — taking cover and running — and an order is in force where the squad's order named a cell this bot can reach: the order's term already carried the discipline, and what the change adds is the other half of the same scale on the two actions that contradict it.

### FR-BOT-140 — Target choice has hysteresis

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: []
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/WarTests.swift]
created: 2026-09-21
```

If the utility of a bot's current target and that of the best alternative differ by less than the hysteresis margin of the bot configuration, the system **shall** keep the current target.

**Rationale.** Concept §9.2 names the side effect to check on the prototype: a bot caught between two threats must not freeze on close scores, and names hysteresis as the probable fix.
Written as behaviour — no flapping under a margin — so that a test can show it.
Built on 2026-09-26 with fire at an enemy (FR-BOT-060), the first time a bot had two targets to be caught between. The snake is one target wherever on it the bot aims, since its nearest part moves as it does; each bot is one target (ADR-0044).

### FR-BOT-530 — A bot does not set out for a cell another bot holds or is making for

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-220, FR-BOT-300]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/CellClaimTests.swift]
created: 2026-10-13
```

When a bot chooses a cell to move to, the system **shall** leave out the cells a bot it sees stands in and the cells its own squad is already making for.

**Rationale.** The maintainer, 2026-10-13, watching what the squads had become: a bot choosing where to go must take account of the cells other bots hold and the cells other bots have already set out for, and not try to get into them.
Two sets and not one, because a bot acts on what it knows (FR-BOT-220): where a bot stands is something that can be seen, so an enemy in view holds its cell as much as a squadmate does, while where a bot is going is something only its own squad can know. An enemy remembered and not seen holds nothing — the memory is of a place it was.
One filter over the two cases rather than two requirements: what is claimed is the whole of what a cell search leaves out, and a search that honoured one set and not the other is the same bots walking into each other.
FR-BOT-300 is the other half of it, after the fact — a bot already walking stops against a bot standing where it is going (ADR-0064) — and this is what keeps it from setting out for that cell at all.
A body holds nothing: nothing in the game treats one as an obstacle, and only the living are pushed apart (FR-BOT-320).
Where the exclusions leave no cell at all the action is simply not on the list, as every action with nothing to act on is.

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
status: implemented
verification: T
derives_from: [FR-BOT-165]
depends_on: [FR-BOT-080, FR-SNAKE-040]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/UnreachableTests.swift]
created: 2026-09-22
```

When the navigation graph holds no route to the target of a bot's chosen action, the system **shall** give that bot a deliberation slot with that action excluded until its next slot after.

**Rationale.** Being cut off is a designed event, not an edge case: the snake's tail makes a passage impassable (FR-SNAKE-040) precisely so that a squad loses its way out.
A bot that keeps asking for the route it cannot have is the "signature stupidity" concept §9.2 names — it must pick something else and pick it now.
Excluding only the failed action, and only until the slot after, keeps the choice honest when the tail moves away a second later.
Measured on the spike in its worst-case mode, about one path request in a hundred found no route — a rate that belongs to that arena's random targets rather than to the search, but enough to settle that this is an ordinary path and not an error path.
Built on 2026-10-12 (ADR-0082): the action is written onto the bot, which puts it ahead of the queue in the next frame — the route interrupts take, without being one of FR-BOT-170's seven events — and is spent by the slot it earns.
Two lists are filtered, because an action comes from either: the scored ones, and the advance or the look the quiet motives offer, which is where an unreachable goal actually arises (ADR-0059).
A bot standing on the cell its action names has arrived rather than been cut off: it holds nothing against the next slot, so an order to hold ground is obeyed again and not treated as a loop (ADR-0079).
The branch cannot fire in a connected arena — everything else a bot makes for is walked out over the graph — so it is verified on a map of two rooms with no door between them, and will be exercised in a match the day a tail can block a passage (FR-SNAKE-040).

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
status: partial
verification: T
derives_from: [FR-BOT-160]
depends_on: [FR-BOT-050]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Interrupts.swift, Sources/CrawlCall/Bot/Slots.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/InterruptTests.swift]
created: 2026-09-21
```

When a bot takes damage, sees the snake within the interrupt distance of the bot configuration, sees an ally die, empties its magazine, loses the cover it occupies, witnesses an eating, finds a snake-marked body, or receives a new order, the system **shall** give that bot the next deliberation slot ahead of the queue.

**Rationale.** Concept §9.2 lists these seven events; without them the snake eats a bot that keeps shooting the other way for another 100 ms.
One act over an enumerated set of triggers, as the standard's exit-code example: splitting would destroy the claim that these are all of them.
How each event is found, and why a slot ahead of the queue does not make a bot fire faster, is ADR-0057.
`partial` because three of the events have nothing to be found in yet: cover is not destroyed (FR-MAP-030), no body is marked by the snake (FR-SCORE-120) and nobody gives orders (FR-CMD-040).

## Reaction to the snake

### FR-BOT-180 — Calm squads do not hunt the snake

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-SCORE-130, FR-BOT-120]
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/SquadStateTests.swift]
created: 2026-09-21
```

While a squad's awareness is *calm*, the system **shall** leave the snake out of its bots' choice of action — what to fire at, what to hide or run from — except where FR-BOT-120 applies.

**Rationale.** Concept §6.3: on *calm* the snake does not exist for the commander; a bot still reacts to a snake in its face.
Leaving it out of the target alone had calm bots run from a snake they would not fire at, so that it could neither be hunted by them nor get near them (the maintainer, 2026-09-29, after trying both on the phone; ADR-0060).

### FR-BOT-190 — Alarmed squads keep together

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-SCORE-130]
refines: [FR-BOT-080]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Execution.swift]
tests: [Tests/CrawlCallTests/SquadStateTests.swift]
created: 2026-09-21
```

While a squad's awareness is *alarm*, the system **shall** raise the utility of positions within the grouping distance of the bot configuration from a squadmate.

**Rationale.** Concept §6.3: on *alarm* the squad keeps together and checks corners.
Corner-checking is left to the commander's orders; keeping together is the observable behaviour a test can measure by distances.
The positions are those a bot hides or runs to, and being near a squadmate decides which, as height and the snake's path do (ADR-0058, ADR-0060).

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
`partial` because three readings of the map are still the truth's: the route to a chosen cell is found over the whole map, whether a cell is cover is tested against the obstacles as they stand, seen or not, and so is the snake's path to a position (FR-BOT-115, ADR-0058). ADR-0032 replaces the first two — floods over the map as the squad knows it, and a lines-of-fire table — each to be written as its own requirement and put to the maintainer.
The enemy is recorded (FR-BOT-240) and, since the squads went to war on 2026-09-26, read by three actions — fired at where it is seen now, hidden from where it was last seen (FR-BOT-330), advanced on where it is believed to be (FR-BOT-360) — each from the bot's own knowledge and none from the truth. The order in which bots are given slots still reads how near the snake truly is (FR-BOT-160): that is when a bot thinks, not what it chooses.

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
tests: [Tests/CrawlCallTests/BotFacingTests.swift, Tests/CrawlCallTests/BotMotionTests.swift]
created: 2026-09-25
```

While a match is running, the system **shall** turn each bot, no faster than the turn speed of the bot configuration, to face the way it is walking, or while it fires the point it fires at, each bot starting the match facing the other squad.

**Rationale.** The maintainer, 2026-09-25: the second step of the bots' movement. A figure that never turns slides sideways and backwards, and a character that faces where it goes reads as going there.
A facing of the model's and not only the drawing's, because what a bot can see is to depend on it: its field of view (FR-BOT-050) is measured from where it faces.
No faster than a turn speed, so that a bot swings round rather than snapping; facing the other squad at the start, because the two are at war (FR-BOT-020) and the enemy is what a soldier watches for.
The way it is walking is the way its route goes beyond the cell it is in, not the way a frame moved it: a squadmate's push turned that this way and that, and a bot walking in a group twitched (ADR-0064).

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
Two bots that both want to stand where the other is would push each other back and forth for ever; seen on the phone on 2026-09-30, bots twitching on the spot in a fight. A bot passes a point of its route once it is over it, and stops against a bot standing on the cell it is making for (ADR-0064).

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

### FR-BOT-320 — A bot with no health left is a body

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-060]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Bot/Perception.swift, Sources/CrawlCall/Bot/Knowledge.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/WarTests.swift]
created: 2026-09-26
```

When a bot's health reaches zero, the system **shall** leave it where it fell as a body that takes no action, moves no more, is fired at by no bot and is not pushed aside by other bots.

**Rationale.** The maintainer, 2026-09-26: the squads fight, and a fight has dead (ADR-0044). The concept keeps the dead on the map: squads do not remove bodies, only the snake does (glossary, *body*; concept §6.2), and a body is what the snake eats when it eats a bot not alive (FR-SNAKE-090).
A bot that sees a body where it knew an enemy stops counting it an enemy, and its squad hears of the death as of anything else it sees (FR-BOT-310). What a body shows of how it died is FR-SCORE-110's, not built.

### FR-BOT-330 — A bot hides from the enemy as from the snake

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-240, FR-BOT-060]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Knowledge.swift]
tests: [Tests/CrawlCallTests/WarTests.swift]
created: 2026-09-26
```

When scoring cover for a bot, the system **shall** count a cell as watched where the eyes of an enemy bot, where the bot last saw it, have a line of sight to the bot's eyes standing in that cell, as well as where the snake it knows of sees into the cell.

**Rationale.** The maintainer, 2026-09-26, choosing the war with cover in it: a bot fired at hides (ADR-0044). To the eyes, because an enemy fires from its eyes at a head (FR-BOT-060), which shows over a wall lower than both; the snake's line runs to the ground, as it did.
Where the bot last saw the enemy, because a bot acts on what it knows (FR-BOT-220).

### FR-BOT-340 — A standing bot does not look at a wall

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-280, FR-BOT-250, FR-BOT-230]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/WarTests.swift]
created: 2026-09-26
```

When a bot stops with less than 1.5 m of open ground before it, as far as it knows, the system **shall** turn it to the way round it with the most open ground before it.

**Rationale.** The maintainer, 2026-09-26: bots are not to stand looking at a wall. A bot that faces where it last walked (FR-BOT-280) arrives at cover facing the wall it hides behind, and a bot sees only within its field of view (FR-BOT-050), so it would stand blind.
As far as it knows: open ground ends at the building's outline (FR-BOT-250) and at a cell it has seen that nobody can stand in (FR-BOT-230); a cell it has not seen is open, and is what is worth looking at (ADR-0044). Three cells, 1.5 m, is more than a wall at arm's length and less than a corridor's length.

## Under fire

What a bot does about the rounds coming its way: fire from beside cover where there is some, and keep moving where there is none (ADR-0063).

### FR-BOT-420 — A bot fires from beside cover

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-060, FR-BOT-330, FR-BOT-220]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Bot.swift]
tests: [Tests/CrawlCallTests/SkirmishTests.swift]
created: 2026-09-30
```

When a bot chooses to fire and, within the cover search distance, there is a cell from which it has a line of fire to its target and next to which a cell is hidden from every enemy and the snake it knows of, the system **shall** have it fire from the nearest such cell.

**Rationale.** The maintainer, 2026-09-30: bots stood before one another and fired point-blank, where anybody sensible avoids the danger and fires from cover. Hidden is FR-BOT-330's watched turned round, so that the cell a bot fires from is one step from the cell it would hide in; the search distance is cover's, the grouping distance, because cover further off is somebody else's.
A bot that stepped behind the cover to reload (FR-BOT-425) comes out again to fire from where it did, at what it was firing at as it last knew it, and fires once it sees it (ADR-0063).

### FR-BOT-425 — A bot reloads behind cover

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-420]
depends_on: [FR-BOT-420]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Bot/Deliberation.swift]
tests: [Tests/CrawlCallTests/SkirmishTests.swift]
created: 2026-09-30
```

When a bot firing from beside cover reloads, the system **shall** move it into the hidden cell next to where it fired from.

**Rationale.** The maintainer, 2026-09-30, choosing cover, and movement where there is none: a bot fires from the edge of the cover and ducks behind it to reload.
Until 2026-10-13 the magazine was full the moment the bot stood in the hidden cell, because a reload took no time of its own and one done before the step behind would have left nothing to step behind for (ADR-0063).
A reload now takes the weapon's own time (FR-BOT-550), so the cell is where the bot waits it out rather than where the filling happens, and what this requirement asks for is the move and nothing about the moment: ADR-0090 supersedes that part of ADR-0063.

### FR-BOT-430 — A bot with no cover beside it fires on the move

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-420, FR-BOT-290]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Utility.swift]
tests: [Tests/CrawlCallTests/SkirmishTests.swift, Tests/CrawlCallTests/BotFacingTests.swift]
created: 2026-09-30
```

While a bot fires and FR-BOT-420 finds it no cell, the system **shall** move it across its line of fire at the strafing speed of the bot configuration, turning back after the strafing interval of the bot configuration or where it cannot go on.

**Rationale.** The maintainer, 2026-09-30: with no cover, a bot should at least move. Across the line, because a round flies at where its target was (FR-BOT-060): 2 m/s takes a bot half a metre aside in the quarter second a round crosses six metres. Turning back every second keeps it near where it chose to fight, and makes where it will be less plain to whoever fires at it.

## With nothing to do

### FR-BOT-360 — An idle bot advances on the enemy

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-240, FR-BOT-250]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Knowledge.swift, Sources/CrawlCall/Bot/Action.swift]
tests: [Tests/CrawlCallTests/IdleTests.swift]
created: 2026-09-29
```

While every other action available to a bot scores nothing, the system **shall** send the bot towards where it believes the enemy squad to be: the latest place it saw or was told of an enemy bot, or, where it knows of none, the enemy's starting area (FR-BOT-250).

**Rationale.** The maintainer on 2026-09-29: with the squads starting at opposite ends of the island (FR-BOT-350), squads that stand still never meet, and the war the concept is built on does not happen without the snake. Q-320.
Nothing else scoring is what keeps a motive for the quiet from ever outweighing a threat, which Q-320 asked for; how an advance and a look (FR-BOT-370) are chosen between, and what a bot does on finding a place empty, is ADR-0059.

### FR-BOT-370 — An idle bot goes to see what it has not seen

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-230]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Deliberation.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Action.swift]
tests: [Tests/CrawlCallTests/IdleTests.swift]
created: 2026-09-29
```

While every other action available to a bot scores nothing, the system **shall** send the bot to the nearest cell it can reach that is not in its knowledge of the map (FR-BOT-230).

**Rationale.** Q-320 names idle curiosity; the cells a bot has not seen are what its knowledge gives curiosity to read (ADR-0032).

### FR-BOT-380 — A bot standing idle looks round

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-080]
depends_on: [FR-BOT-050, FR-BOT-340, IF-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Bot/Bot.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/IdleTests.swift]
created: 2026-09-29
```

While a bot stands with every other action scoring nothing, the system **shall** turn it to face a new direction once every look-round interval of the bot configuration, favouring the directions in which its knowledge places a possible threat: where it last saw or was told of the snake or an enemy bot, and the enemy's starting area.

**Rationale.** Q-320: a bot that stands still should not look like a statue; turning changes what its field of view takes in (FR-BOT-050), so looking round is also how a standing bot notices.
The maintainer added on 2026-09-29 that a bot looking round gives its attention to where, by what it knows, a threat may come from.
It keeps to the ways with open ground before it, as FR-BOT-340 has a standing bot do (ADR-0059).
