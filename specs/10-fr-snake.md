# Functional requirements — snake

Movement over the map's walkable surfaces under the player's control, the tail spline, growth, eating, abilities gained from prey.
Source: concept §4 (snake mechanics), §5 (abilities from eating), §6.2 (eating takes time), §7 (destruction by the body).
Tunable numbers — speeds, durations, growth, damage-to-segments — are read from the snake configuration (IF-SNAKE-010) and are named here only where the concept fixes a relation between them.

## Movement

### FR-SNAKE-010 — Head stays on the map's walkable surfaces

```yaml
status: implemented
verification: D
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Snake/Surfaces.swift, Sources/CrawlCall/View/SnakeEntity.swift]
tests: [Tests/CrawlCallTests/SnakeTests.swift, Tests/CrawlCallTests/GameTests.swift]
created: 2026-09-21
```

While a match is running, the snake's head **shall** move in the direction the player holds, staying on the map's walkable surfaces — over ramps, stairs and drops from ledges — and never passing through walls or load-bearing geometry.

**Rationale.** The snake lives on the map's surfaces, not in free space: it crawls over geometry, steered rather than pathfound (concept §3, ADR-0016).
Everything the tail does for free — blocking corridors and stairs, becoming a liability in narrow passages, vertical play in both directions — follows from the head being bound to the surfaces.
Free flight was never on the table.

### FR-SNAKE-020 — Tail follows the head's path

```yaml
status: implemented
verification: D
derives_from: [FR-SNAKE-010]
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Snake/Surfaces.swift, Sources/CrawlCall/View/SnakeEntity.swift]
tests: [Tests/CrawlCallTests/SnakeTests.swift, Tests/CrawlCallTests/GameTests.swift]
created: 2026-09-21
```

While a match is running, the system **shall** lay the snake's tail along the path the head has travelled, vertical portions included, so that every tail segment rests on the surface the head crossed.

**Rationale.** Concept §4: the tail is a spline that repeats the head's path with all its vertical parts.
That the tail's mesh is regenerated every frame is how, not what, and is left to the code.

### FR-SNAKE-030 — Head speed comes from configuration

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-010]
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/SnakeTests.swift, Tests/CrawlCallTests/GameTests.swift]
created: 2026-09-21
```

While the head is moving, the system **shall** advance it at the base speed read from the snake configuration.

**Rationale.** Concept §12 leaves the final feel of snake speed to the human; a number in a config is what lets it be tuned without a rebuild.
That the base speed is lower than a bot's run speed is INV-SNAKE-020.

## Tail as an obstacle

### FR-SNAKE-040 — Tail blocks bots

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-020]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a tail segment occupies a cell of the navigation graph, the system **shall** treat that cell as impassable for bots.

**Rationale.** Concept §4: a long snake can cut off a squad's retreat.
A stair or corridor held by the body is the main spatial weapon the snake has, and the reason maps carry stairs the snake can block (FR-MAP-070).
On the grid this is a per-cell mark that follows the segments (ADR-0016).

### FR-SNAKE-050 — Tail blocks the snake's own head

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-020]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a tail segment lies in the head's way, the system **shall** stop the head at the segment as at a wall.

**Rationale.** Concept §4: the snake can lock itself in.
Split from FR-SNAKE-040 because blocking bots and blocking oneself can each be built and observed without the other, and the second is the one that makes narrow corridors a risk rather than only an advantage.
For the head this is collision, not the graph (ADR-0016): the head is steered, and what it runs into is geometry.

## Growth and damage

### FR-SNAKE-060 — Eating extends the tail

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SNAKE-100, IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the snake finishes consuming a bot, the system **shall** append to the tail the number of segments the snake configuration sets for that bot's archetype.

**Rationale.** Concept §1: the more the snake has eaten, the stronger it is and the harder it manoeuvres.
Growth per archetype rather than a flat number keeps the heavy the "fattest" target the concept §8 calls it.

### FR-SNAKE-070 — Damage removes segments from the end

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the snake takes damage, the system **shall** remove segments from the end of the tail, the number being the damage divided by the damage-per-segment value of the snake configuration, rounded down.

**Rationale.** Concept §5: damage shoots the tail off from the end, so losing length is losing concrete abilities, and shooting at the tail is a meaningful thing for a bot to do.
What happens when the tail has no segments left is FR-SNAKE-210 (ADR-0009).

### FR-SNAKE-080 — A removed segment takes its ability with it

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-070]
depends_on: [FR-SNAKE-110]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a tail segment is removed, the system **shall** discard the ability attached to that segment.

**Rationale.** Concept §5: abilities hang on segments, so loss of length is loss of specific options rather than an abstract penalty.

## Eating

### FR-SNAKE-090 — Eating takes time and holds the snake in place

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the snake begins consuming a bot, the system **shall** keep the head stationary for the eating duration of the snake configuration before the bot counts as consumed.

**Rationale.** Concept §6.2: the speed of consumption is the key parameter of the whole mechanic — instant eating makes "eat or leave" a free and therefore nonexistent choice.
A stationary snake is a visible and damageable one, which is the exposure the concept asks for; nothing here reduces damage during eating, so no separate requirement says the snake stays vulnerable.

### FR-SNAKE-100 — Live prey takes longer than a body

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-090]
depends_on: [IF-SNAKE-010]
refines: [FR-SNAKE-090]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the bot being consumed is alive, the system **shall** apply the live-prey eating duration of the snake configuration, which is greater than the body eating duration.

**Rationale.** Concept §6.2: live prey resists and takes longer, and is worth more for it (FR-SCORE-020).
The relation "greater than" is the concept's; the two numbers are tuning.

## Abilities from prey

### FR-SNAKE-110 — Consuming a bot attaches its archetype's ability to a segment

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SNAKE-060, FR-BOT-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the snake finishes consuming a bot, the system **shall** attach the ability of that bot's archetype to one of the segments appended for it.

**Rationale.** Concept §5: power comes from the act of eating, not from loot on the ground, which is what gives the player a reason to choose whom to eat.
One ability per bot, on one segment, is what makes FR-SNAKE-080 meaningful.

### FR-SNAKE-120 — An ability is consumed on use

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-110]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the player activates an ability, the system **shall** remove that ability from its segment.

**Rationale.** Concept §5: charges are single-use.
No ceiling beyond one per segment: the tail's exposure to fire is the cap (Q-090, closed 2026-09-21).

### FR-SNAKE-130 — Assault: dash

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-110]
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the player activates the assault ability, the system **shall** move the head at the dash speed of the snake configuration for the dash duration of the same configuration.

**Rationale.** Concept §5: catch a runner, close the distance.

### FR-SNAKE-140 — Sapper: breach a partition

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-110]
depends_on: [FR-MAP-030]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the player activates the sapper ability against a non-load-bearing partition in front of the head, the system **shall** set that partition to its debris state.

**Rationale.** Concept §5: new routes around corridors.
"Non-load-bearing" is not a restriction added here — INV-MAP-010 forbids breaking the load-bearing frame for every source of destruction, this ability included.

### FR-SNAKE-150 — Scout: see bots through walls

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-110]
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the player activates the scout ability, the system **shall** display the position of every living bot through map geometry for the duration the snake configuration sets.

**Rationale.** Concept §5: planning an ambush.

### FR-SNAKE-160 — Sniper: focus

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-110]
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the player activates the sniper ability, the system **shall** slow game time by the factor and for the duration the snake configuration sets, highlighting every bot in view meanwhile.

**Rationale.** Concept §5: "highlight, slow time — a precise lunge at distance".
Two effects, one activation, one duration: the highlight without the slowdown is not the ability the concept describes, so this is one obligation rather than two — noted because the standard's singularity test was applied and answered.

### FR-SNAKE-170 — Medic: regrow

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-110]
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the player activates the medic ability, the system **shall** append to the tail the number of segments the snake configuration sets for the medic ability, carrying no ability.

**Rationale.** Concept §5: surviving a bad encounter.
The snake has no health apart from its tail (ADR-0009), so healing is regrowth; the regrown segments carry nothing, or eating a medic would be worth two abilities.

### FR-SNAKE-180 — Heavy: temporary armour

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-110]
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the player activates the heavy ability, the system **shall** reduce damage taken by the snake by the armour factor of the snake configuration for the armour duration of the same configuration.

**Rationale.** Concept §5: survive focused fire.

### FR-SNAKE-190 — Heavy: faster destruction

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-110]
depends_on: [FR-SNAKE-200]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While the heavy ability is active, the system **shall** multiply the destruction damage dealt by the snake's body by the factor the snake configuration sets.

**Rationale.** Concept §5 lists "armour, destruction" for the heavy.
Split from FR-SNAKE-180 because armour and destruction speed can each be built and verified without the other; they share an activation and a duration.

## Destruction by the body

### FR-SNAKE-200 — The body destroys what it crosses

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-MAP-030, IF-MAP-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the snake's body passes through a destructible module, the system **shall** deal that module the destruction damage the tuning configuration sets for the snake's current length.

**Rationale.** Concept §7: the snake breaks cover with the weight and motion of its body, not with a button — crawled through a barricade, took it down; longer and heavier breaks more.

## Life

### FR-SNAKE-210 — The snake dies when hit with no tail left

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-070]
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the snake takes damage while its tail has no segments, the system **shall** kill the snake.

**Rationale.** ADR-0009: the snake's life is its tail — one currency for growth, abilities, blocking and survival.
The match starts with the segment count the snake configuration sets (IF-SNAKE-010), so the first bullet is never the last.

### FR-SNAKE-220 — A drop is a path, not a fall

```yaml
status: implemented
verification: D
derives_from: [FR-SNAKE-010, FR-SNAKE-020]
depends_on: [IF-MAP-020]
refines: [FR-SNAKE-020]
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Snake/Surfaces.swift]
tests: [Tests/CrawlCallTests/SnakeTests.swift]
created: 2026-09-21
```

When the head is steered off a ledge no higher than the maximum drop of the tuning configuration, the system **shall** let it fall to the surface below and lay the tail down the drop as a vertical portion of the path, with no damage and no break in the tail.

**Rationale.** Concept §4: verticality works both ways — the snake cuts through drops the bots will not jump; a drop that hurt or severed the tail would take that away (Q-040, closed 2026-09-21).
A ledge higher than the maximum drop is fenced by geometry the head cannot pass, so it never goes over one; the tail's sag is rendering.

### FR-SNAKE-230 — The snake bites off its own tail

```yaml
status: draft
verification: T
derives_from: [FR-SNAKE-060]
depends_on: [FR-SNAKE-070, FR-SNAKE-080, FR-SNAKE-240]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

When the snake finishes biting off a segment, the system **shall** remove the segment at the end of the tail.

**Rationale.** A choice the game can already price without a new system: FR-BOT-050 counts the snake as noticed when *any* segment enters a bot's view, so length is already exposure — a long tail shows around the corner the head is hiding behind. Going short buys quiet.
What it costs is equally already written: the segment takes its ability with it (FR-SNAKE-080), so the player trades concrete options for concealment, and a shorter snake also blocks itself less (FR-SNAKE-050), which is a second, opposite reason to do it.
One segment per act, taken from the end, for symmetry with damage (FR-SNAKE-070) and because a segment is the unit an ability hangs on; a player who wants to be shorter repeats the act and pays each time.
The act itself — what starts it, what refuses it and how long it holds the snake — is FR-SNAKE-240; this requirement speaks of finishing so that the two cannot disagree about when the segment is gone, the same split as eating, where FR-SNAKE-060 appends on finishing and FR-SNAKE-090 holds the head from beginning.
Nothing in the concept proposes this — it is the maintainer's idea of 2026-09-22, which is why it is `draft` and why the mechanic it belongs to is the verticality-and-cover layer, not stage 1.
Approving it adds a shed intent to IF-VIEW-010, which today defines four.

### FR-SNAKE-240 — Biting off takes time and holds the snake in place

```yaml
status: draft
verification: T
derives_from: [FR-SNAKE-230]
depends_on: [IF-SNAKE-010, IF-VIEW-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

When the player issues the shed intent and the tail is longer than one segment, the system **shall** keep the head stationary for the shedding duration of the snake configuration, after which the snake has finished biting off a segment.

**Rationale.** The same shape as eating (FR-SNAKE-090), for the same reason: an instant act is a free one, and a free way to become unseen would be taken every time.
The trigger carries the refusal as well as the hold: a tail one segment long is not shed, because with no tail left the next hit kills (FR-SNAKE-210) and a control that deletes the player in one press is a trap rather than a choice.
The duration is what stops the loop of eat, shed, eat that FR-SNAKE-060 would otherwise pay for — no cooldown is needed when the act is a commitment made in the open, stationary and damageable.
Approving it adds a shedding duration to the keys IF-SNAKE-010 reads, beside the eating duration it already names.

### FR-SNAKE-250 — A severed segment leaves nothing behind

```yaml
status: draft
verification: T
derives_from: [FR-SNAKE-230]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

When a segment is removed by the snake's own act, the system **shall** take it out of the arena leaving no body, no obstacle and no pickup.

**Rationale.** The smallest rule that delivers the choice the mechanic is for, and a deliberate refusal of the larger one: the tail already blocks bots (FR-SNAKE-040), so a severed piece that stayed would be a wall the player places at will — a different mechanic, an order of magnitude larger, and one that changes what a map is.
Whether it should stay is not settled by argument but by five people: H-080 measures whether a piece left lying about is placed on purpose or used as cover, and this requirement is what holds until that reading exists.
