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
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Snake/Surfaces.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/View/SnakeEntity.swift, Sources/CrawlCall/Config/Motion.swift, Sources/CrawlCall/Config/Geometry.swift]
tests: [Tests/CrawlCallTests/SnakeTests.swift, Tests/CrawlCallTests/GameTests.swift]
created: 2026-09-21
```

While a match is running, the snake's head **shall** move where the player steers it (FR-SNAKE-290), staying on the map's walkable surfaces — over ramps, stairs and drops from ledges — with no part of its body passing into anything the map places that is not walkable.

**Rationale.** The snake lives on the map's surfaces, not in free space: it crawls over geometry, steered rather than pathfound (concept §3, ADR-0016).
Everything the tail does for free — blocking corridors and stairs, becoming a liability in narrow passages, vertical play in both directions — follows from the head being bound to the surfaces.
Free flight was never on the table.
What is kept out of walls is the body and not the centre of the head: the body is 0.6 m across at the shipped radius on a grid of half a metre, and a head kept only to walkable cells sank into the wall beside it (ADR-0021).
Where the head may stand is still the navigation graph's to say — which floor, which stair, which ledge — and how close to a wall it may come is the geometry's.

### FR-SNAKE-015 — A blocked head slides along what stopped it

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-010]
depends_on: []
refines: [FR-SNAKE-010, FR-SNAKE-030]
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Config/Motion.swift]
tests: [Tests/CrawlCallTests/SnakeTests.swift, Tests/CrawlCallTests/OwnBodyTests.swift]
created: 2026-09-23
```

When the way the head is going would take it into what it cannot pass, the system **shall** move the head along that obstacle at the head's base speed, to the side the held direction leans to, or, where it leans to neither, on along the obstacle the way the head is already going along it, or, at rest against it, to the side with more room.

**Rationale.** The camera's yaw never changes (FR-VIEW-010) and the stick gives a direction in the frame's axes rather than the corridor's (FR-VIEW-050), so a thumb cannot be laid exactly along a wall; a head that stops dead on contact makes the control punish the precision it does not give.
The snake is steered rather than pathfound (ADR-0016), and a direction taken along the surface is what steering over one means.
What the head cannot pass is both of the refusals it already knows — a wall, and ground too far below to be dropped to (FR-SNAKE-220) — so the head slides along the lip of a hole exactly as it slides along a wall.
Nothing is said here of corners or of a direction pressed squarely into a wall, because nothing needs to be: a part that is zero is standing still, and a corner is this same rule applied to the second obstacle as well as the first.
FR-SNAKE-030 is narrowed by this and not broken: the base speed is still the one the configuration gives, and what a slide takes of it is the part the obstacle leaves. A head that slid at the whole of it from a square push would turn every wall into a rail.
**The way the head is going**, since 2026-09-30. Once the head turned on an arc (FR-SNAKE-290) the way it goes and the way held are two, and the slide was taken in the first (Q-470): a head going north along a wall, held into the wall and south, went on north. The maintainer, finding the snake running into things more often, chose the side and the speed of the held direction; where the stick is held away from the obstacle, the head turns away along it as the way it is going leads (ADR-0066).
**At the whole of its speed**, since later the same day, 2026-09-30: the snake still ran its nose into things, trees included, and the maintainer asked for something taken from real snakes, which do not push against what they meet but follow its outline. The head now goes along what it meets at its whole speed, and pushed squarely in it goes round to the side with more room; with the feel of FR-SNAKE-016 it starts round before it touches. Only where neither way along is open does it stand (ADR-0069). A head already going along what it meets keeps to that way when the stick leans to neither side, rather than weighing the room again — the maintainer agreed on 2026-09-30 — so that it does not turn back halfway along. The speed taken in the part along the obstacle, which the paragraphs above explain, is gone with that.


### FR-SNAKE-016 — The head feels its way round what is ahead

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-015]
depends_on: [FR-SNAKE-015, FR-SNAKE-290, IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Motion.swift, Sources/CrawlCall/Snake/Surfaces.swift]
tests: [Tests/CrawlCallTests/OwnBodyTests.swift, Tests/CrawlCallTests/FlightTests.swift]
created: 2026-09-30
```

While the way the head is going leads into what it cannot pass within the feel distance of the snake configuration, and the held direction leads past it, the system **shall** turn the head towards the side it would pass it on, no tighter than the turning radius.

**Rationale.** The maintainer, 2026-09-30, choosing, with the head going round at its whole speed (FR-SNAKE-015), a snake that feels what is ahead, as a snake does with its tongue: the head starts round an obstacle before it touches it. Half a metre ahead, the maintainer's number.
The held direction leads past what is ahead where it is not held back behind the head; the side is the one it leans to along the obstacle, or, leaning to neither, the side the way the head is going glances off to (ADR-0069). Measured on the day, a head aimed at a point just past a crate got past it one to five frames sooner. What is felt is what stands on the ground, not the floors and steps it is walked on: the steps of a flight two ahead rise more than a step, and were at first felt as a wall, which made a flight hard to go up.
### FR-SNAKE-020 — Tail follows the head's path

```yaml
status: implemented
verification: D
derives_from: [FR-SNAKE-010]
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Snake/Surfaces.swift, Sources/CrawlCall/View/SnakeEntity.swift, Sources/CrawlCall/Config/Motion.swift]
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
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Motion.swift]
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
status: superseded
superseded_by: FR-SNAKE-055
verification: T
derives_from: [FR-SNAKE-020]
depends_on: [FR-SNAKE-015, IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Snake/Lunge.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Configurations.swift]
tests: [Tests/CrawlCallTests/OwnBodyTests.swift]
created: 2026-09-21
```

While a tail segment beyond the neck lies in the head's way, the system **shall** stop the head at that segment as at a wall, except while the head coils round a bot.

**Rationale.** Concept §4: the snake can lock itself in.
Split from FR-SNAKE-040 because blocking bots and blocking oneself can each be built and observed without the other, and the second is the one that makes narrow corridors a risk rather than only an advantage.
For the head this is collision, not the graph (ADR-0016): the head is steered, and what it runs into is geometry.
Built on 2026-09-30, when the maintainer found the snake folding in two as it was pulled back out of a corner: a slide along a wall turns the head at once, and the turning radius then brings it back beside its own body (ADR-0066). The neck — two segments behind the head by the snake configuration — is not in the way, since a head turning on its arc passes within a body's width of it; nor is the body while the head coils round a bot, since the ring lies against it (FR-SNAKE-280).
**Superseded** the same day, 2026-09-30: played on the phone, a snake that could not get past itself felt strange, "even if it is the snake canon", and the maintainer asked for it to crawl over itself as over an obstacle, over the top (FR-SNAKE-055, ADR-0067). The snake can no longer lock itself in, which leaves FR-MAP-080 standing on this requirement (Q-510).

### FR-SNAKE-055 — The head crawls over its own body

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-020]
depends_on: [FR-SNAKE-020, IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Snake/Lunge.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/View/SnakeEntity.swift, Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Motion.swift]
tests: [Tests/CrawlCallTests/OwnBodyTests.swift]
created: 2026-09-30
```

When the head's way crosses a tail segment beyond the neck, the system **shall** carry the head up and over that segment, its body resting on the segment's where the two cross, so that the body the head draws after it lies over its own.

**Rationale.** The maintainer, 2026-09-30, on the phone, after the tail had been made to stop the head (FR-SNAKE-050): a snake that cannot get past itself feels strange; it should crawl over itself as over an obstacle, over the top. It also ends the fold that started it all: a head pulled back out of a corner no longer lies down through its own body, and goes over it instead.
The neck — the segments the snake configuration names, two — is not climbed, since a head turning on its arc (FR-SNAKE-290) passes within a body's width of it; nor is the body while the head coils round a bot, since the ring lies against it (FR-SNAKE-280). How high and how smoothly is ADR-0067.


### FR-SNAKE-056 — What of the body lies on nothing comes down

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-055]
depends_on: [FR-SNAKE-055, FR-SNAKE-220]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/OwnBodyTests.swift]
created: 2026-09-30
```

While a part of the snake's body lies higher than the body under it, or than the ground where there is no body under it, the system **shall** bring that part down under the drop gravity of the tuning configuration until it rests on what is under it.

**Rationale.** The maintainer, 2026-09-30, on the phone: three layers of snake on itself are fine, but the snake could climb its own layers and then hang in the air once the layers under it had crawled away — "physics is needed". A part laid on the body keeps the height it was laid at; when the body under it goes on along its path, or is shot off the end of the tail, nothing held it up. It falls as the head falls off a ledge (FR-SNAKE-220), under the same gravity; it never rises by this. How is ADR-0068.
## Growth and damage

### FR-SNAKE-060 — Eating extends the tail

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-SNAKE-100, IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Game.swift, Sources/CrawlCall/Snake/Snake.swift]
tests: [Tests/CrawlCallTests/EatingTests.swift]
created: 2026-09-21
```

When the snake finishes consuming a bot, the system **shall** append to the tail the number of segments the snake configuration sets for that bot's archetype.

**Rationale.** Concept §1: the more the snake has eaten, the stronger it is and the harder it manoeuvres.
Growth per archetype rather than a flat number keeps the heavy the "fattest" target the concept §8 calls it.

### FR-SNAKE-070 — Damage removes segments from the end

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/ExecutionTests.swift]
created: 2026-09-21
```

When the snake takes damage, the system **shall** remove from the end of the tail one segment for every whole multiple of the damage-per-segment value of the snake configuration that the damage reaches, counting what earlier damage left over.

**Rationale.** Concept §5: damage shoots the tail off from the end, so losing length is losing concrete abilities, and shooting at the tail is a meaningful thing for a bot to do.
What earlier damage left over is counted because otherwise a weapon weaker than a segment is a weapon that does nothing: the shipped numbers are 2 damage a shot against 10 a segment, so under a rounding that forgot the remainder no bot could ever shorten the snake, however long it fired. The alternative — tuning every weapon to a whole number of segments — makes the tuning of one number depend on the other, and the concept's damage numbers are meant to be moved freely (§12).
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
status: implemented
verification: T
derives_from: []
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Eating.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/EatingTests.swift]
created: 2026-09-21
```

When the snake begins consuming a bot, the system **shall** keep the head stationary until that bot counts as consumed.

**Rationale.** Concept §6.2: the speed of consumption is the key parameter of the whole mechanic — instant eating makes "eat or leave" a free and therefore nonexistent choice.
How long it lasts depends on what is being eaten: a body takes the body eating duration of the snake configuration, live prey takes as long as its health lasts (FR-SNAKE-100).
A stationary snake is a visible and damageable one, which is the exposure the concept asks for; nothing here reduces damage during eating, so no separate requirement says the snake stays vulnerable.

### FR-SNAKE-100 — Live prey takes longer than a body

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-090]
depends_on: [IF-SNAKE-010]
refines: [FR-SNAKE-090]
conflicts_with: []
code: [Sources/CrawlCall/Snake/Eating.swift]
tests: [Tests/CrawlCallTests/EatingTests.swift]
created: 2026-09-21
```

While the snake consumes a bot that is alive, the system **shall** take the eating damage per second of the snake configuration out of that bot's health, the bot counting as consumed when no health is left.

**Rationale.** Concept §6.2: live prey resists and takes longer, and is worth more for it (FR-SCORE-020).
Resisting is what a second duration could not express: a bot with health left goes on shooting while it is being eaten, and the meal lasts exactly as long as its health does. That also makes the heavy the slowest meal without a number of its own — it is the fattest target the concept §8 calls it, and the rate is one number rather than one per archetype.
A body has no health and is eaten in the body eating duration of FR-SNAKE-090; the two cases are the same act and differ in what ends it.

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
status: implemented
verification: T
derives_from: [FR-SNAKE-070]
depends_on: [IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift]
tests: [Tests/CrawlCallTests/MatchEndTests.swift]
created: 2026-09-21
```

When the snake takes damage while its tail has no segments, the system **shall** kill the snake.

**Rationale.** ADR-0009: the snake's life is its tail — one currency for growth, abilities, blocking and survival.
The match starts with the segment count the snake configuration sets (IF-SNAKE-010), so the first bullet is never the last.
"While its tail has no segments" and not "when the last segment goes": the hit that empties the tail is paid for by that segment, and the one after it is the one with nothing left to pay.
The damage a hit does not pay for in full is banked (FR-SNAKE-070), and at an empty tail there is nothing to bank against — so the smallest weapon in the game kills a tailless snake as surely as the largest.

### FR-SNAKE-220 — A drop is a path, not a fall

```yaml
status: implemented
verification: D
derives_from: [FR-SNAKE-010, FR-SNAKE-020]
depends_on: [IF-MAP-020]
refines: [FR-SNAKE-020]
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Snake/Surfaces.swift, Sources/CrawlCall/Config/Motion.swift, Sources/CrawlCall/Config/MapFormat.swift, Sources/CrawlCall/Config/Configurations.swift, config/tuning.json, Sources/CrawlCall/Game.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/SnakeTests.swift, Tests/CrawlCallTests/EatingTests.swift]
created: 2026-09-21
```

When the head is steered off a ledge no higher than the maximum drop of the tuning configuration, the system **shall** carry it down to the surface below along an arc — on across at the speed it walked off at, down under the drop gravity of the tuning configuration, and landing no farther on than the body can land clear — and lay the tail down the arc as a portion of the path, with no damage and no break in the tail.

**Rationale.** Concept §4: verticality works both ways — the snake cuts through drops the bots will not jump; a drop that hurt or severed the tail would take that away (Q-040, closed 2026-09-21).
A ledge higher than the maximum drop is fenced by geometry the head cannot pass, so it never goes over one; the tail's sag is rendering.
Along an arc, since 2026-09-25: the maintainer found on the phone that the snake fell off the side of the flight and off the balcony in a single frame. The game had never done otherwise off a ledge; the one-cell transition that led to the balcony before the flight replaced it was walked like a climb, and the first spike's snake, on a character controller under gravity, went off a ledge in an arc. A flight two cells wide under a body wider than one is easy to step off, so almost every way down had become a fall. Coming straight down at a speed of its own was tried first and turned down by the maintainer the same day: a jump off the balcony is an arc. How the arc is chosen is ADR-0040.

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
What it costs is equally already written: the segment takes its ability with it (FR-SNAKE-080), so the player trades concrete options for concealment. A second, opposite reason to do it — that a shorter snake blocked itself less (FR-SNAKE-050) — went on 2026-09-30, when the snake came to crawl over itself instead (FR-SNAKE-055).
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

### FR-SNAKE-260 — The snake crawls across a gap narrower than its body

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-220]
depends_on: [FR-SNAKE-010, IF-MAP-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Surfaces.swift]
tests: [Tests/CrawlCallTests/SnakeTests.swift]
created: 2026-09-25
```

Where the ground the snake crawls on has a gap narrower than its body, the system **shall** let the snake crawl across the gap at the ground's height, with no part of the snake falling into it.

**Rationale.** The maintainer, 2026-09-25, after the snake fell from the balcony wherever its head crossed a corner of a cell: the rule that the snake does not go where it does not fit holds for gaps in the floor and joints between cells as much as for gaps between walls, and it holds for every part of the snake, not only its head. Across, not stopped at, by the maintainer's choice: a gap too narrow to fall into is a gap to crawl over. A gap as wide as the body or wider is a ledge, dropped from as FR-SNAKE-220 says; leaping one is Q-410.
"Its body" is the tuning's body radius (IF-MAP-020).

### FR-SNAKE-270 — The snake lunges at what it would eat

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-SNAKE-010, FR-SNAKE-090, FR-SNAKE-220, IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Lunge.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Motion.swift]
tests: [Tests/CrawlCallTests/LungeTests.swift]
created: 2026-09-29
```

When the player asks to eat while a bot is within the lunge reach of the head and within the lunge angle of the way the head is going, the system **shall** hold the head for the wind-up and then move it towards that bot by the snake's movement rules, at the lunge speed on average and slowing to a stop, for no longer than crossing the lunge reach at that speed takes, beginning the coil of FR-SNAKE-280 if the head reaches a living bot, the meal if it reaches a body, and stopping where it is if it reaches neither or the bot goes outside the lunge angle of the way the head is going.

**Rationale.** The maintainer, 2026-09-29: eating begins at some distance from the prey, and the snake throws itself at it, still as a cartoon. A bot runs faster than the snake crawls (INV-SNAKE-020), so a meal that waited for the head to touch its prey was a meal only of the slow and the dead; the concept already counts on a lunge, since the sniper ability is "a precise lunge at distance" (FR-SNAKE-160).
The maintainer chose the numbers and the rules: a reach of 1.5 m, three cells; a lunge that can miss, when the prey gets away or behind something in the lunge's time; the head going by the snake's movement rules, sliding along what stops it and going off a ledge as it would crawling (FR-SNAKE-010, FR-SNAKE-220); and a wind-up before it.
Reaching the bot is the head's body plus half a cell, the distance the meal began at before; off a ledge the lunge ends, since nothing is eaten in the air. How it is built is ADR-0052.
**Ahead only**, since 2026-09-30: a lunge at a bot behind the head sent the head back through the neck and folded the snake in two, which the turning radius (FR-SNAKE-290) had stopped the stick from doing. The maintainer chose a lunge only at what is ahead, over a lunge that curves round, first within 90° to either side of the way the head is going and then, the same day, within 60°; a bot that gets out from ahead during the lunge is missed (ADR-0065).
Slowing to a stop since the maintainer's second look on the phone the same day: at a steady speed the head stopped dead, which read as a twitch.

### FR-SNAKE-280 — The snake coils round a living bot before eating it

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-270]
depends_on: [FR-SNAKE-010, FR-SNAKE-020, FR-SNAKE-090, FR-SNAKE-100, IF-SNAKE-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Snake/Coil.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Motion.swift]
tests: [Tests/CrawlCallTests/CoilTests.swift, Tests/CrawlCallTests/LungeTests.swift]
created: 2026-09-29
```

When the snake's lunge reaches a living bot, the system **shall** move the head once round that bot, by the snake's movement rules, over the coil time the snake configuration sets, holding the bot in place except to shove it, no faster than the shove speed and no further than the shove reach the same configuration sets, to where the body can go round it, and then begin the meal.

**Rationale.** The maintainer, 2026-09-29, on the phone: the lunge alone was not expressive, and the snake should throw itself at its prey, coil round it once and swallow it; a body is simply eaten. Asked, the maintainer chose a coil that is the head's real movement, with the body lying round the bot because it follows the head's path (FR-SNAKE-020), and not a picture over a body that stays where it was; the bot shoved out of a corner where the ring does not fit, "not in one frame, of course"; the coil adding its time to the meal's rather than taking it from it; and the bot shooting back meanwhile as it does while it is eaten (FR-SNAKE-100).
The ring's radius is two bodies, the head's and the bot's side by side; how the room is found is ADR-0053.


### FR-SNAKE-285 — A coil that goes off a ledge takes the bot down with it

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-280]
depends_on: [FR-SNAKE-280, FR-SNAKE-220, FR-SNAKE-090]
refines: [FR-SNAKE-280]
conflicts_with: []
code: [Sources/CrawlCall/Game.swift, Sources/CrawlCall/Snake/Coil.swift]
tests: [Tests/CrawlCallTests/CoilTests.swift]
created: 2026-09-30
```

When the head goes off a ledge while it coils round a bot, the system **shall** carry the bot down with the head and begin the meal where the head lands.

**Rationale.** The maintainer, 2026-09-30, on the phone: a bot on a stair could not be eaten. The ring round a bot is two bodies wide, and a flight is one cell: the head going round went off the flight's side, fell, and no meal begins in the air (FR-SNAKE-220). Asked, the maintainer chose the snake coiling round the bot and falling with it, swallowing it, over skipping the coil or a ring over the void.

### FR-SNAKE-290 — The head turns on an arc

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-010]
depends_on: [IF-SNAKE-010]
refines: [FR-SNAKE-010]
conflicts_with: []
code: [Sources/CrawlCall/Snake/Snake.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/Config/Configurations.swift]
tests: [Tests/CrawlCallTests/TurnTests.swift]
created: 2026-09-29
```

While the head moves, the system **shall** turn it towards the direction the player holds no tighter than an arc of the turning radius of the snake configuration.

**Rationale.** The maintainer, 2026-09-29: a head that takes any direction at once folds the snake in two, which does not look like a snake. A lunge and a coil steer the head themselves and are not held to it (FR-SNAKE-270, FR-SNAKE-280).
The radius at the body's centre line is the maintainer's: 0.5 m at first, and 0.35 m since 2026-09-30, when the snake turned too wide on the phone. Turning round takes a way 1.3 m wide, twice the radius and the body's 0.6 m, so the snake still does not turn round in a one-metre doorway. How the turn is taken is ADR-0061.
