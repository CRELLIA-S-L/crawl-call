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

While a match is running, the system **shall** keep the snake's head within the central region of the frame the view configuration defines, moving the camera as the head moves, except where that would show ground beyond the arena, where the camera stops at its edge.

**Rationale.** Concept §3: the camera follows the snake.
The exception is what a match starts in: the blockout's first cell is a corner, and a camera obeying the region alone put sixty-one per cent of the screen outside the map, measured on the device on 2026-09-22. Ground beyond the arena is nothing — there is no world there to draw — so a frame spent on it is a frame not spent on the room the player is in. A camera stopped at the edge lets the head leave the central region, which is the lesser of the two: the head is still on screen, and what surrounds it is the arena rather than the void.

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
code: [Sources/CrawlCall/View/SeeThrough.swift, Sources/CrawlCall/Map/Sight.swift, Sources/CrawlCall/Map/SceneBuilder.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/SeeThroughTests.swift]
created: 2026-09-22
```

While a match is running, the system **shall** draw as see-through every map module that hides any part of the snake from the camera, or stands within the see-through margin of the view configuration of doing so, for as long as it does.

**Rationale.** The camera's angle and yaw never change (FR-VIEW-010) and the camera follows the head (FR-VIEW-020), so a wall that leans over the snake near the edge of the frame cannot be stepped around: the player's own body is behind it and nothing they do moves it.
The alternative is a map without walls, and a wall is what a map is assembled from (FR-MAP-100) — the arena reads as a place because it has sides.
This is the rule FR-VIEW-140 applies to a floor above the head, widened to whatever is in the way. The two are separate requirements because they answer differently: a floor above hides a whole room and goes see-through wholesale, while a wall is only ever in the way while the snake is behind it, and a wall that stayed see-through afterwards would cost the arena its shape.
What is measured to is the head and every segment, because a tail the player cannot see is a tail they cannot place, and placing it is the game (concept §4).
The body is a body and not a point: a wall that hides half a segment hides it, and a fade that began only once the centre went behind the wall would begin after the player had already lost sight of the thing they are steering. The margin beyond that is the same argument taken one step further — it buys the fade time to happen before it is needed — and it is a number settled by eye, which is why it is in the view configuration and not here.

### FR-VIEW-155 — The ground around the head is kept in sight

```yaml
status: implemented
verification: D
derives_from: [FR-VIEW-010]
depends_on: [FR-SNAKE-010, FR-VIEW-020, IF-VIEW-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SeeThrough.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/SeeThroughTests.swift]
created: 2026-09-23
```

While a match is running, the system **shall** draw as see-through every map module that does not stand wholly beyond the head, measured across the ground away from the camera, and hides from the camera any part of the head's own floor within the visibility radius of the view configuration around the head, for as long as it does.

**Rationale.** FR-VIEW-150 keeps the snake itself visible, which is not the same as seeing where it is going: a wall that hides no part of the body still hides the metre in front of the head, and with the yaw fixed (FR-VIEW-010) there is no leaning around it.
Measured to the floor around the head and not to the whole snake, because what the tail needs is to be seen and what the head needs is room to be steered into.
Written beside FR-VIEW-150 rather than into it: that one says the snake is never hidden and stays true by itself; this one says the ground it is steered over is not hidden either.
The radius is a number settled by eye, which is why it is in the view configuration (IF-VIEW-020) and not here, and it is bounded by the argument that bounds FR-VIEW-150's margin: an arena whose walls are clear wherever the snake goes has stopped having a shape.
The floor is measured at the cells the map is laid in (IF-MAP-010): the window is the walkable cells of the head's floor whose centres fall inside the radius, which is what "part of the floor" means on a grid, and is how, not what.
Beyond the head is where this stops, because a window taken in every direction at once puts a module behind the snake in front of the ground behind that, and clears it — which is the thing FR-VIEW-150 was fixed on 2026-09-23 for doing, returned at five times the radius. The two rules now say the same thing about direction: nothing beyond the snake was ever hiding it, or the ground it stands on, from a camera in front of it.
Beyond is measured across the ground and not by the plane the camera looks along: that plane is tilted by the pitch FR-VIEW-010 fixes, so the top of a waist-high fence standing behind the head falls on the camera's side of it and the rule it was meant to state says nothing at all. The margin takes no part in the measurement either — it is room to the side of a line, as in FR-VIEW-150 — or the ring of cells touching the head comes back through the door this closes.
The price is named rather than discovered: steering straight away from the camera, the module just ahead of the head stays solid and keeps the ground immediately behind it, which for the shipped fence at the shipped pitch is a little over half a metre. Seeing past that would be a different rule, and this one is the maintainer's of 2026-09-23.
The demonstration that verifies this, for whoever carries it out: steer the head up to a wall that hides no part of the body and stand a pace short of it — that wall goes clear and stays clear while the head is beside it, the one the same distance behind the tail stays solid, and nothing outside the radius changes. The frame captured off the device is what records the judgement (`specs/50-verification.md`).
Built and covered by tests on 2026-09-23, and not yet demonstrated: what a radius is worth is a thing seen, and nobody has seen this one.
This was met by accident before it was written. Until 2026-09-23 the margin of FR-VIEW-150 was applied around each point of the snake in every direction at once, which cleared the ring of cells touching it — including the ones behind it, which hide nothing — and read on screen as this requirement. FR-VIEW-150 never asked for that, and taking it away takes with it the thing the player had been steering by, which is why this is asked for on purpose.

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
code: [Sources/CrawlCall/Input/TouchScheme.swift, Sources/CrawlCall/View/Controls.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/TouchSchemeTests.swift, Tests/CrawlCallTests/ControlsTests.swift]
created: 2026-09-21
```

Where the game runs on iOS, the system **shall** produce every intent IF-VIEW-010 defines from touch, the movement direction coming from a stick on the left of the screen and held while the finger rests on it, and the intent to eat from a button on the right.

**Rationale.** Concept §3: touch on iOS — holding a direction.
A stick and a button rather than gestures over the whole screen, because gestures collide: eating was a long press and steering a drag, and a thumb that pauses before it moves asks for a meal instead of a step. Tried on the device on 2026-09-23 and rejected there. Controls that occupy their own corners cannot be mistaken for one another, and the left-right split is what a thumb on each side of a phone reaches.
iPhone is the primary target (concept §15), so this scheme is not the port of the other one.

### FR-VIEW-160 — The eat button says whether there is anything to eat

```yaml
status: implemented
verification: D
derives_from: [FR-VIEW-050]
depends_on: [FR-SNAKE-090]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/Controls.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/ControlsTests.swift]
created: 2026-09-23
```

While a match is running, the system **shall** show the eat button as available exactly when the head has reached a bot it could begin eating.

**Rationale.** A control that does nothing looks broken. Tried on the device on 2026-09-23: the button was pressed with nothing in reach, nothing happened, and nothing on screen said why — the reading was "the button does not work", which is what any player would conclude.
Reach is a distance the player cannot see and would otherwise have to guess at; the button is where they are already looking when they want to eat, so that is where it is said.
"Exactly when" is the whole of it: a button that lit up hopefully would be the same lie in the other direction.

## Readability

### FR-VIEW-060 — Squad affiliation is readable at a glance

```yaml
status: partial
verification: D
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/BotEntity.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/BotEntityTests.swift]
created: 2026-09-21
```

While a bot is on screen, the system **shall** show its squad through its body colour, the silhouette of its equipment and the colour of its tracers, all three agreeing.

**Rationale.** Concept §2: the player decides whom to eat from the balance of power, and if the sides are confused the whole strategic layer fails; three channels because one of them is always occluded or out of frame.

**Partial, and how.** Two of the three channels are built: the body is drawn in its squad's colour, and so is the line of every shot it fires (FR-VIEW-170). The silhouette of the equipment is the third and waits on the archetype models (FR-VIEW-070) — a grey box has no equipment to show.

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
status: partial
verification: D
derives_from: []
depends_on: [FR-SNAKE-090]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/BotEntity.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/BotEntityTests.swift]
created: 2026-09-21
```

While the snake is consuming a bot, the system **shall** show the bot swallowed whole — a bulge travelling down the body, boots protruding from the mouth — without dismemberment or blood.

**Rationale.** Concept §2: in stylisation eating stops being a problem — funny and without gore; F-030 is the boundary this serves.

**Partial, and how.** What is built is the half that says a meal is happening: the bot is drawn towards the head and shrinks as what is left of it does, and it is gone from the screen when it is gone from the match. The bulge travelling down the body and the boots at the mouth need a snake that is more than a chain of spheres and a bot that is more than a box — they arrive with the models, not with this. What is already true is the part that matters for the boundary: whole, no dismemberment, nothing red.
Found by playing on 2026-09-23: with none of this, a meal was a bot standing still and then standing still for ever, because the view went on drawing a body the match had already removed.

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
Held over on 2026-09-23 until the game is drawn with something better than the blockout: on a chain of spheres two of the three would be deformations nobody can see, and the third has nothing to read, since the snake keeps one speed until the dash of FR-SNAKE-130 gives it a second.

### FR-VIEW-170 — A shot is drawn where it went

```yaml
status: implemented
verification: T
derives_from: [FR-BOT-060]
depends_on: [IF-BOT-010, FR-VIEW-060]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Shot.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/View/ShotEntity.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/ShotTests.swift]
created: 2026-09-23
```

When a bot fires, the system **shall** draw a line from it to the point it aimed at, for the deliberation period of the bot configuration.

**Rationale.** Played on the device on 2026-09-23: bots were firing and the snake was losing segments, and nothing on screen said so — the only sign of being shot at was a tail that had grown shorter, which is a thing a player counts rather than feels. Danger that leaves no trace is danger nobody takes.
The line is what the model already has: a shot lands in the step it is fired (FR-BOT-060), there is no projectile to follow, and where it came from and where it went is the whole of what happened.
It lasts the deliberation period because that is the cadence of fire: one line a shot, gone by the time the next is due, so that the number of lines on screen is the number of shots being fired and not a decoration that accumulates.

### FR-VIEW-180 — The tail on screen is as long as the tail

```yaml
status: implemented
verification: T
derives_from: [FR-SNAKE-060]
depends_on: [FR-SNAKE-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SnakeEntity.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/GameTests.swift]
created: 2026-09-23
```

While the snake is on screen, the system **shall** draw one body at every point the tail lays down.

**Rationale.** Found in play on 2026-09-23: a snake that had been shot down to nothing and then ate looked as though it had been restored to its starting length, and the truth was the other way round — the model had grown past that length and the screen could not show it. The bodies were made once, at the count the match starts with, and eating changed a number nobody could see.
FR-SNAKE-060 is then true and invisible, which is the worst of the two ways to be wrong: the player is shown a snake that stopped rewarding them for eating.
"Every point the tail lays down" and not "every segment the snake has": a tail longer than the trail behind it has nowhere to put its last segments, and where the model puts nothing the screen draws nothing.

## Interface

### FR-VIEW-120 — The HUD is drawn in the diorama style

```yaml
status: partial
verification: I
derives_from: []
depends_on: [IF-VIEW-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/Controls.swift, Sources/CrawlCall/View/MatchEnd.swift]
tests: []
created: 2026-09-21
```

Every HUD element **shall** be drawn as a rounded, light-coloured plate carrying a bold rounded typeface or an icon legible at phone size, with no slanted, bevelled or military-styled plate anywhere in the interface.

**Rationale.** Concept §2: the interface in the same aesthetic as the world — rounded light plates, a bold rounded typeface, large readable icons; a military HUD with slanted plates argues with the style (ADR-0002).
Inspected against these four properties; a separate style guide was considered and not written, since the properties are the guide (Q-160, closed 2026-09-21).

**Partial, and how.** What exists of the interface is the two controls FR-VIEW-050 asks for — the stick and the eat button — and the plate FR-VIEW-190 puts up when the match is over; all three are drawn to this requirement: rounded, light, translucent, with an icon or a bold rounded word. Nothing else of a HUD exists yet, so the requirement is met by everything there is and unmet by everything there is not.

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

### FR-VIEW-190 — A finished match says so and starts again on a press

```yaml
status: implemented
verification: T
derives_from: [FR-SCORE-140, FR-SCORE-150]
depends_on: [FR-VIEW-120]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/MatchEnd.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/View/BotEntity.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/MatchEndTests.swift]
created: 2026-09-23
```

While the match is over, the system **shall** draw, in place of the steering controls, a plate that names which of the two ends it was and carries one control that begins a new match in the same arena.

**Rationale.** H-010 is measured by whether a first-time player keeps going past the second minute, and until now a match had no end at all; with FR-SCORE-140 and FR-SCORE-150 it has two, and an end that froze the screen with no way back would end the session along with the match.
Which of the two, because they are opposite results — the snake was shot down, or the snake ate the arena empty — and a plate saying only that it was over would leave the player to work out which of them they had just reached.
The same arena, because stage 1 has one map (concept §13) and a choice of levels is a menu, which the vertical slice does not build.
In place of the steering controls, because a stick that still answers after the snake is dead says the match is not over.
"A new match" is the whole of it and not only a new model: played on 2026-09-23, the first restart brought the bots the snake had eaten back the size the last bite had left them, because the drawing kept what the previous match had done to it. Whatever a match changes on screen, starting one puts back.
