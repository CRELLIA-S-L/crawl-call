# Functional requirements — snake

Movement over the navigation mesh, the tail spline, growth, eating, abilities gained from prey.
Source: concept §4 (snake mechanics), §5 (abilities from eating), §6.2 (eating takes time), §7 (destruction by the body).
Tunable numbers — speeds, durations, growth, damage-to-segments — are read from the snake configuration (IF-SNAKE-010) and are named here only where the concept fixes a relation between them.

## Movement

### FR-SNAKE-010 — Head moves on the navigation mesh

```yaml
status: deferred
verification: D
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a match is running, the snake's head **shall** move only along the navigation mesh of the map, including its vertical transitions — stairs, descents and drops from ledges.

**Rationale.** The snake lives on the surface graph of the map, not in free space: it crawls over geometry.
Everything the tail does for free — blocking corridors and stairs, becoming a liability in narrow passages, vertical play in both directions — follows from the head being bound to the mesh.
Free flight was never on the table.

### FR-SNAKE-020 — Tail follows the head's path

```yaml
status: deferred
verification: D
derives_from: [FR-SNAKE-010]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a match is running, the system **shall** lay the snake's tail along the path the head has travelled, vertical portions included, so that every tail segment rests on the surface the head crossed.

**Rationale.** Concept §4: the tail is a spline that repeats the head's path with all its vertical parts.
That the tail's mesh is regenerated every frame is how, not what, and is left to the code.

### FR-SNAKE-030 — Head speed comes from configuration

```yaml
status: deferred
verification: T
derives_from: [FR-SNAKE-010]
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
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

While a tail segment occupies a navigation-mesh passage, the system **shall** treat that passage as impassable for bots.

**Rationale.** Concept §4: a long snake can cut off a squad's retreat.
A stair or corridor held by the body is the main spatial weapon the snake has, and the reason maps carry stairs the snake can block (FR-MAP-120).

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

While a tail segment occupies a navigation-mesh passage, the system **shall** treat that passage as impassable for the snake's own head.

**Rationale.** Concept §4: the snake can lock itself in.
Split from FR-SNAKE-040 because blocking bots and blocking oneself can each be built and observed without the other, and the second is the one that makes narrow corridors a risk rather than only an advantage.

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
status: deferred
verification: D
derives_from: [FR-SNAKE-010, FR-SNAKE-020]
depends_on: [IF-MAP-020]
refines: [FR-SNAKE-020]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the head drops from a ledge no higher than the maximum drop of the tuning configuration, the system **shall** lay the tail down the drop as a vertical portion of the path, with no damage and no break in the tail.

**Rationale.** Concept §4: verticality works both ways — the snake cuts through drops the bots will not jump; a drop that hurt or severed the tail would take that away (Q-040, closed 2026-09-21).
A ledge higher than the maximum drop is simply not a navigation-mesh transition, so the head never goes over it; the tail's sag is rendering.
