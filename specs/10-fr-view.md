# Functional requirements — view and input

The camera, the input abstraction with its two schemes, and what the player must be able to read off the screen.
Source: concept §3 (view and controls), §2 (readability of sides and states, what the style opens mechanically).
The input intents the game logic consumes are IF-VIEW-010.
First-person view is out of the vertical slice (concept §3) and has no requirement.

## Camera

### FR-VIEW-010 — A perspective camera pitched between 50 and 60 degrees

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [IF-VIEW-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SceneView.swift]
tests: [Tests/CrawlCallTests/ScenePlanTests.swift]
created: 2026-09-21
```

While a match is running, the system **shall** render the arena through a perspective camera whose pitch below the horizontal is between 50 and 60 degrees and whose yaw does not change.

**Rationale.** Concept §3: the main camera is perspective, 50–60° from above as in the references, not strict isometry, fixed angle.
A fixed yaw is what lets height and sight lines be learnt once (concept §2, "space is exact").

### FR-VIEW-020 — The camera follows the head

```yaml
status: implemented
verification: D
derives_from: [FR-VIEW-010]
depends_on: [FR-SNAKE-010, IF-VIEW-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SceneView.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/ScenePlanTests.swift]
created: 2026-09-21
```

While a match is running, the system **shall** keep the snake's head within the central region of the frame the view configuration defines, moving the camera as the head moves.

**Rationale.** Concept §3: the camera follows the snake.

### FR-VIEW-140 — A floor above the head is drawn see-through

```yaml
status: implemented
verification: D
derives_from: [FR-VIEW-010]
depends_on: [FR-MAP-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SeeThrough.swift, Sources/CrawlCall/Map/SceneBuilder.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/SeeThroughTests.swift]
created: 2026-09-22
```

While the snake's head is on a floor that another floor stands above, the system **shall** draw the map modules of every floor above the head's see-through, so that the floor the head is on, and whatever stands on it, read through them.

**Rationale.** Concept §3 asks for multi-level maps — floors, stairs, balconies — and for a camera whose angle and yaw never change, and says nothing about what the player sees when one stands over the other.
The stage-1 blockout is that case: its balcony lies between the camera and the floor beneath it, and a fixed yaw leaves no way to look past it, so the floor the snake is on, the stair up to the balcony and whatever stands under it are not on screen at all.
Concept §2 asks that height be read off the camera from above, and a floor that reads as a lid over the level below is that promise broken.
See-through rather than gone, because the floor above is information too — where it ends, where its stair is, what is standing on it — and it is the map's modules that give way, so a creature on the upper floor stays as visible as the floor under it.
What see-through means was settled by looking: a wireframe of the module's own triangles was tried on the device on 2026-09-22 and rejected — the balcony read as a net and the crate standing under it was lost in it — and the shipped look is the whole module drawn at low opacity, which leaves both the balcony's shape and what is beneath it readable.

### FR-VIEW-150 — Nothing between the camera and the snake stays solid

```yaml
status: implemented
verification: D
derives_from: [FR-VIEW-010]
depends_on: [FR-SNAKE-010, FR-VIEW-020, IF-VIEW-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SeeThrough.swift, Sources/CrawlCall/Map/SceneBuilder.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/SeeThroughTests.swift]
created: 2026-09-22
```

While a match is running, the system **shall** draw as see-through every map module that hides any part of the snake from the camera, or stands within the see-through margin of the view configuration of doing so, for as long as it does.

**Rationale.** The camera's angle and yaw never change (FR-VIEW-010) and the camera follows the head (FR-VIEW-020), so a wall that leans over the snake near the edge of the frame cannot be stepped around: the player's own body is behind it and nothing they do moves it.
The alternative is a map without walls, and a wall is what a map is assembled from (FR-MAP-100) — the arena reads as a place because it has sides.
This is the rule FR-VIEW-140 applies to a floor above the head, widened to whatever is in the way. The two are separate requirements because they answer differently: a floor above hides a whole room and goes see-through wholesale, while a wall is only ever in the way while the snake is behind it, and a wall that stayed see-through afterwards would cost the arena its shape.
What is measured to is the head and every segment, because a tail the player cannot see is a tail they cannot place, and placing it is the game (concept §4).
The body is a body and not a point: a wall that hides half a segment hides it, and a fade that began only once the centre went behind the wall would begin after the player had already lost sight of the thing they are steering. The margin beyond that is the same argument taken one step further — it buys the fade time to happen before it is needed — and it is a number settled by eye, which is why it is in the view configuration and not here.

## Input

### FR-VIEW-030 — Game logic reads intents, not device events

```yaml
status: implemented
verification: I
derives_from: []
depends_on: [IF-VIEW-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Game.swift, Sources/CrawlCall/Input/Intent.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/GameTests.swift]
created: 2026-09-21
```

The game logic **shall** consume only the input intents IF-VIEW-010 defines, never keyboard, mouse or touch events directly.

**Rationale.** Concept §3: the input abstraction is laid down from day one; the two schemes are designed separately, not adapted from one another, and that is only possible if the logic does not know which one it is talking to.

### FR-VIEW-040 — macOS scheme: keyboard and mouse

```yaml
status: deferred
verification: D
derives_from: [FR-VIEW-030, CON-PUB-010]
depends_on: [IF-VIEW-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Where the game runs on macOS, the system **shall** produce every intent IF-VIEW-010 defines from the keyboard and the mouse.

**Rationale.** Concept §3: keyboard and mouse on macOS.
Direction and ability activation from keys, the pointed position from the mouse; the bindings are configuration, the intents are the contract.

### FR-VIEW-050 — iOS scheme: touch

```yaml
status: implemented
verification: D
derives_from: [FR-VIEW-030, CON-PUB-010]
depends_on: [IF-VIEW-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Input/TouchScheme.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/TouchSchemeTests.swift]
created: 2026-09-21
```

Where the game runs on iOS, the system **shall** produce every intent IF-VIEW-010 defines from touch, the movement direction coming from swipes and held while the finger stays down.

**Rationale.** Concept §3: touch on iOS — swipes, holding a direction.
iPhone is the primary target (concept §15), so this scheme is not the port of the other one.

## Readability

### FR-VIEW-060 — Squad affiliation is readable at a glance

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a bot is on screen, the system **shall** show its squad through its body colour, the silhouette of its equipment and the colour of its tracers, all three agreeing.

**Rationale.** Concept §2: the player decides whom to eat from the balance of power, and if the sides are confused the whole strategic layer fails; three channels because one of them is always occluded or out of frame.

### FR-VIEW-070 — Archetype is readable from the silhouette

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-BOT-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a bot is on screen, the system **shall** make its archetype identifiable from its silhouette alone — headgear and weapon — at the game camera's distance.

**Rationale.** Concept §8, §2.2: the silhouette is distinct by headgear and weapon; six silhouettes, not twelve, because both squads share the set.
The player chooses whom to eat by archetype (FR-SNAKE-110), so this has to be read before the bite.

### FR-VIEW-080 — Wounded and separated bots stand out

```yaml
status: deferred
verification: D
derives_from: [FR-VIEW-060]
depends_on: [FR-BOT-020, IF-VIEW-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a bot is wounded or farther from every squadmate than the straggler distance of the view configuration, the system **shall** mark it visibly as such.

**Rationale.** Concept §2: the third category — the wounded and the stragglers — must stand out too; they are what the snake waits for.

### FR-VIEW-090 — Panic is visible on the bot

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-BOT-030, IF-VIEW-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a bot's panic weight exceeds the visible-panic threshold of the view configuration, the system **shall** show it through the bot's pose and an effect above its head.

**Rationale.** Concept §2: a character literally looks panicked, so the commander's weights get a visual expression and the player sees who is about to break.

### FR-VIEW-100 — Eating is staged as comedy

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-SNAKE-090]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While the snake is consuming a bot, the system **shall** show the bot swallowed whole — a bulge travelling down the body, boots protruding from the mouth — without dismemberment or blood.

**Rationale.** Concept §2: in stylisation eating stops being a problem — funny and without gore; F-030 is the boundary this serves.

### FR-VIEW-110 — The snake squashes and stretches

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-SNAKE-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While the snake moves, the system **shall** deform its body — flattening in a passage narrower than the body, stretching under acceleration, swelling with each consumption.

**Rationale.** Concept §2: squash and stretch is the snake's home ground.
Three deformations, one continuous act of drawing the body; a test of "the body deforms" that checked only one would not be this requirement.

## Interface

### FR-VIEW-120 — The HUD is drawn in the diorama style

```yaml
status: deferred
verification: I
derives_from: []
depends_on: [IF-VIEW-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Every HUD element **shall** be drawn as a rounded, light-coloured plate carrying a bold rounded typeface or an icon legible at phone size, with no slanted, bevelled or military-styled plate anywhere in the interface.

**Rationale.** Concept §2: the interface in the same aesthetic as the world — rounded light plates, a bold rounded typeface, large readable icons; a military HUD with slanted plates argues with the style (ADR-0002).
Inspected against these four properties; a separate style guide was considered and not written, since the properties are the guide (Q-160, closed 2026-09-21).

### FR-VIEW-130 — The arena is lit as bright daylight

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-VIEW-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SceneView.swift]
tests: [Tests/CrawlCallTests/ScenePlanTests.swift]
created: 2026-09-22
```

While a match is running, the system **shall** light the arena with a single bright daylight source casting soft shadows, with enough ambient light that no surface facing away from it reads as black.

**Rationale.** Concept §2 names the light as part of the style, not as a technical detail: "bright daylight, soft shadows, a saturated palette. No gloom." A diorama is read by its shapes, and shapes are read by their shading.
It is also what makes a blockout judgeable at all: an unlit scene renders as flat fields of one colour, so a floor, a wall and a crate become indistinguishable and every `D` judgement about a map — whether a corridor is a trap, whether a balcony overlooks the room — has nothing to look at.
The number of lights is one on purpose: a single source is what casts a readable shadow direction, and the thermal budget of a phone rendering a match is not the place to discover that three were affordable (NFR-PERF-010).
