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

While a match is running and the camera is not held by the user in debug mode (FR-TOOL-070), the system **shall** render the arena through a perspective camera whose pitch below the horizontal is between 50 and 60 degrees and whose yaw does not change.

**Rationale.** Concept §3: the main camera is perspective, 50–60° from above as in the references, not strict isometry, fixed angle.
A fixed yaw is what lets height and sight lines be learnt once (concept §2, "space is exact").
The exception is the maintainer's, asked for on 2026-09-24: a camera taken off the snake in debug mode is there to look at the arena from wherever the maintainer wants, tilted and turned, and a player never has it (ADR-0023). The camera goes back to this pitch and this yaw when it is given back to the snake.

### FR-VIEW-020 — The camera follows the head

```yaml
status: implemented
verification: D
derives_from: [FR-VIEW-010]
depends_on: [FR-SNAKE-010, IF-VIEW-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SceneView.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Config/Geometry.swift, Sources/CrawlCall/Config/EntityName.swift]
tests: [Tests/CrawlCallTests/ScenePlanTests.swift]
created: 2026-09-21
```

While a match is running, the system **shall** keep the snake's head within the central region of the frame the view configuration defines, moving the camera as the head moves, except where that would show ground beyond the arena, where the camera stops at its edge.

**Rationale.** Concept §3: the camera follows the snake.
The exception is what a match starts in: the blockout's first cell is a corner, and a camera obeying the region alone put sixty-one per cent of the screen outside the map, measured on the device on 2026-09-22. Ground beyond the arena was then nothing — there was no world there to draw — so a frame spent on it was a frame not spent on the room the player is in. A camera stopped at the edge lets the head leave the central region, which is the lesser of the two: the head is still on screen, and what surrounds it is the arena rather than the void.
Since 2026-09-24 there is a world around the arena (FR-MAP-140, ADR-0031), so the void is gone; the stop stays, as the maintainer agreed with the plan for it, because a frame spent on the island is still a frame not spent on the room, and the free camera of debug mode shows the island to anyone who wants to look.

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
code: [Sources/CrawlCall/View/SeeThrough.swift, Sources/CrawlCall/Map/Sight.swift, Sources/CrawlCall/Map/SceneBuilder.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/View/SeeThroughHole.metal, Sources/CrawlCall/Config/Geometry.swift, Sources/CrawlCall/Config/Resource.swift]
tests: [Tests/CrawlCallTests/SeeThroughTests.swift]
created: 2026-09-22
```

While a match is running, the system **shall** draw as see-through the part of every map module that lies across a line of sight from the camera to any part of the snake, or within the see-through margin of the view configuration of one, for as long as it does.

**Rationale.** The camera's angle and yaw never change (FR-VIEW-010) and the camera follows the head (FR-VIEW-020), so a wall that leans over the snake near the edge of the frame cannot be stepped around: the player's own body is behind it and nothing they do moves it.
The alternative is a map without walls, and a wall is what a map is assembled from (FR-MAP-100) — the arena reads as a place because it has sides.
This is the rule FR-VIEW-140 applies to a floor above the head, widened to whatever is in the way. The two are separate requirements because they answer differently: a floor above hides a whole room and goes see-through wholesale, while a wall is only ever in the way while the snake is behind it, and a wall that stayed see-through afterwards would cost the arena its shape.
What is measured to is the head and every segment, because a tail the player cannot see is a tail they cannot place, and placing it is the game (concept §4).
The body is a body and not a point: a wall that hides half a segment hides it, and a fade that began only once the centre went behind the wall would begin after the player had already lost sight of the thing they are steering. The margin beyond that is the same argument taken one step further — it buys the fade time to happen before it is needed — and it is a number settled by eye, which is why it is in the view configuration and not here.
The part and not the module (ADR-0020). On 2026-09-23 a partition standing in front of the snake, faded whole, showed as a hard-edged pale block a cell wide, when what the player needed cleared was the patch of it in front of the snake; a module is a cell of wall, and the unit that matters is the patch.
What clears is the part of the module around the line of sight, and not the neighbourhood of the snake: a fence of the kit cuts the line only within 0.56 m of the snake at the shipped pitch, but a 2 m partition cuts it from 1.4 m away and a stair from 2.1 m, and a hole kept to the snake's side would leave either standing solid between the camera and the snake. It is along the line, where it goes through the occluder, that the hole is cut — which is how a game whose camera cannot move does it — and along the line rather than around a stretch of it, because a steep line stays near a thin partition for a metre and more, and a sphere holding that stretch cleared the whole partition when it was first tried on the phone.
The same margin decides both that a module is in the way and how wide the cut around the line is, so the hole reaches at least as far as the reason for making it.

### FR-VIEW-155 — The ground around the head is kept in sight

```yaml
status: partial
verification: D
derives_from: [FR-VIEW-010]
depends_on: [FR-SNAKE-010, FR-VIEW-020, IF-VIEW-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SeeThrough.swift, Sources/CrawlCall/Map/SceneBuilder.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/View/SeeThroughHole.metal, Sources/CrawlCall/Config/Interface.swift]
tests: [Tests/CrawlCallTests/SeeThroughTests.swift, Tests/CrawlCallTests/WindowTests.swift]
created: 2026-09-23
```

While a match is running, for every map module that stands higher than the floor the head is on and not wholly beyond the head, measured across the ground away from the camera, the system **shall** draw as see-through the part of that module within the visibility radius of the view configuration around the head, for as long as the head is that near.

**Rationale.** FR-VIEW-150 keeps the snake itself visible, which is not the same as seeing where it is going: a wall that hides no part of the body still hides the metre in front of the head, and with the yaw fixed (FR-VIEW-010) there is no leaning around it.
Around the head and not along the whole snake, because what the tail needs is to be seen and what the head needs is room to be steered into.
Written beside FR-VIEW-150 rather than into it: that one says the snake is never hidden and stays true by itself; this one says the ground it is steered over is not hidden either.
The radius is a number settled by eye, which is why it is in the view configuration (IF-VIEW-020) and not here, and it is bounded by the argument that bounds FR-VIEW-150's margin: an arena whose walls are clear wherever the snake goes has stopped having a shape. It ships at 1.6 m, the radius the maintainer looked at in a throwaway build on 2026-09-23 and approved; the 2.5 m it was first written with was a guess made before anyone had seen a hole.
The window is a hole of that radius cut around the head in whatever stands there (ADR-0020). Its first form asked which floor cells a module hid, and a wall lying along the camera's line of sight hides a strip of floor for its whole length, so some of that strip was always inside the radius and the wall went see-through a cell at a time; narrowing the radius to a metre still cleared two cells that could hide nothing. Measured as a hole, the wall is cut open near the head and stands everywhere else.
Nothing that stands no higher than the floor the head is on is cut: the floor the snake stands on would open onto the void, which is what a throwaway build showed on 2026-09-23. The floor and not the head, because a head walking a stair has already changed floors and is a second's climb short of the surface, and measured against the head the balcony it is climbing onto would be cut open under it.
Beyond the head is where this stops, because a window taken in every direction at once puts a module behind the snake in front of the ground behind that, and clears it — which is the thing FR-VIEW-150 was fixed on 2026-09-23 for doing, returned at five times the radius. The two rules now say the same thing about direction: nothing beyond the snake was ever hiding it, or the ground it stands on, from a camera in front of it.
Beyond is measured across the ground and not by the plane the camera looks along: that plane is tilted by the pitch FR-VIEW-010 fixes, so the top of a waist-high fence standing behind the head falls on the camera's side of it and the rule it was meant to state says nothing at all. The margin takes no part in the measurement either — it is room to the side of a line, as in FR-VIEW-150 — or the ring of cells touching the head comes back through the door this closes.
The price is named rather than discovered: steering straight away from the camera, the module just ahead of the head stays solid and keeps the ground immediately behind it, which for the shipped fence at the shipped pitch is a little over half a metre. Seeing past that would be a different rule, and this one is the maintainer's of 2026-09-23.
The demonstration that verifies this, for whoever carries it out: steer the head up beside a wall that hides no part of the body — the part of that wall near the head goes clear and the rest of it stands, a wall the same distance behind the head stays solid, and nothing outside the radius changes. The frame captured off the device is what records the judgement (`specs/50-verification.md`).
Rebuilt as a hole on 2026-09-23.
This was met by accident before it was written. Until 2026-09-23 the margin of FR-VIEW-150 was applied around each point of the snake in every direction at once, which cleared the ring of cells touching it — including the ones behind it, which hide nothing — and read on screen as this requirement. FR-VIEW-150 never asked for that, and taking it away takes with it the thing the player had been steering by, which is why this is asked for on purpose.

**Switched off, 2026-09-25.** On the phone, with debug mode tinting each cut by its cause (FR-TOOL-260) and switching either off (FR-TOOL-270), the maintainer found that this window is what opened walls and crates beside the head that hide nothing (Q-260), and had it switched off in a match — not removed: the code and its tests stay, debug mode switches it back on, and it goes only once that is settled. `partial` while a match runs without it.

## Input
### FR-VIEW-030 — Game logic reads intents, not device events

```yaml
status: implemented
verification: I
derives_from: []
depends_on: [IF-VIEW-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Game.swift, Sources/CrawlCall/Input/Intent.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Config/Lighting.swift]
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
code: [Sources/CrawlCall/Input/TouchScheme.swift, Sources/CrawlCall/View/Controls.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Config/SymbolName.swift, Sources/CrawlCall/Config/Interface.swift]
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
code: [Sources/CrawlCall/View/Controls.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Config/Interface.swift]
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
status: implemented
verification: D
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/BotEntity.swift, Sources/CrawlCall/View/Figure.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/BotEntityTests.swift, Tests/CrawlCallTests/FigureTests.swift]
created: 2026-09-21
```

While a bot is on screen, the system **shall** show its squad through its body colour, the silhouette of its equipment and the colour of its tracers, all three agreeing.

**Rationale.** Concept §2: the player decides whom to eat from the balance of power, and if the sides are confused the whole strategic layer fails; three channels because one of them is always occluded or out of frame.

The silhouette of the equipment is the same in both squads — six silhouettes and not twelve (concept §8, FR-VIEW-070) — so what it carries of the side is its colour: the headgear, which is the part of the silhouette that names the archetype, is drawn in the squad's colour, like the body and like the line of every shot the bot fires (FR-VIEW-170). The three agree because they are one colour, taken from one place (ADR-0022).

### FR-VIEW-070 — Archetype is readable from the silhouette

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-BOT-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/Figure.swift, Sources/CrawlCall/View/BotEntity.swift]
tests: [Tests/CrawlCallTests/FigureTests.swift]
created: 2026-09-21
```

While a bot is on screen, the system **shall** make its archetype identifiable from its silhouette alone — headgear and weapon — at the game camera's distance.

**Rationale.** Concept §8, §2.2: the silhouette is distinct by headgear and weapon; six silhouettes, not twelve, because both squads share the set.
The player chooses whom to eat by archetype (FR-SNAKE-110), so this has to be read before the bite.
The figures are put together from rounded primitives, as ADR-0002 has the whole game assembled, and which headgear and which weapon each archetype has is recorded in ADR-0022. That the six can be told apart at the camera's distance is what `D` judges on the screen; what the tests hold is that they are six different silhouettes.

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
code: [Sources/CrawlCall/View/BotEntity.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Config/EntityName.swift, Sources/CrawlCall/Config/Geometry.swift]
tests: [Tests/CrawlCallTests/BotEntityTests.swift]
created: 2026-09-21
```

While the snake is consuming a bot, the system **shall** show the bot swallowed whole — a bulge travelling down the body, boots protruding from the mouth — without dismemberment or blood.

**Rationale.** Concept §2: in stylisation eating stops being a problem — funny and without gore; F-030 is the boundary this serves.

**Partial, and how.** What is built is the half that says a meal is happening: the bot is drawn towards the head and shrinks as what is left of it does, and it is gone from the screen when it is gone from the match. The bulge travelling down the body and the boots at the mouth need a snake that is more than a chain of spheres: since ADR-0022 a bot is a figure with boots on it, drawn shrinking into the floor at the head, but there is no mouth for the boots to stick out of until the snake has one. What is already true is the part that matters for the boundary: whole, no dismemberment, nothing red.
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
code: [Sources/CrawlCall/Bot/Shot.swift, Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/View/ShotEntity.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Config/Drawing.swift, Sources/CrawlCall/Config/EntityName.swift]
tests: [Tests/CrawlCallTests/ShotTests.swift]
created: 2026-09-23
```

When a bot fires, the system **shall** draw a line from it to the point it aimed at, for the deliberation period of the bot configuration.

**Rationale.** Played on the device on 2026-09-23: bots were firing and the snake was losing segments, and nothing on screen said so — the only sign of being shot at was a tail that had grown shorter, which is a thing a player counts rather than feels. Danger that leaves no trace is danger nobody takes.
The line is what the model already has: a shot lands in the step it is fired (FR-BOT-060), there is no projectile to follow, and where it came from and where it went is the whole of what happened.
It lasts the deliberation period because that is the cadence of fire: one line a shot, gone by the time the next is due, so that the number of lines on screen is the number of shots being fired and not a decoration that accumulates.

### FR-VIEW-180 — The tail on screen is as long as the tail

```yaml
status: superseded
superseded_by: FR-VIEW-250
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
code: [Sources/CrawlCall/View/Controls.swift, Sources/CrawlCall/View/MatchEnd.swift, Sources/CrawlCall/Config/Interface.swift, Sources/CrawlCall/View/ChoicePlate.swift]
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
code: [Sources/CrawlCall/View/SceneView.swift, Sources/CrawlCall/Config/Lighting.swift]
tests: [Tests/CrawlCallTests/ScenePlanTests.swift]
created: 2026-09-22
```

While a match is running, the system **shall** light the arena with a single bright daylight source casting soft shadows, with enough ambient light that no surface facing away from it reads as black.

**Rationale.** Concept §2 names the light as part of the style, not as a technical detail: "bright daylight, soft shadows, a saturated palette. No gloom." A diorama is read by its shapes, and shapes are read by their shading.
It is also what makes a blockout judgeable at all: an unlit scene renders as flat fields of one colour, so a floor, a wall and a crate become indistinguishable and every `D` judgement about a map — whether a corridor is a trap, whether a balcony overlooks the room — has nothing to look at.
The number of lights is one on purpose: a single source is what casts a readable shadow direction, and the thermal budget of a phone rendering a match is not the place to discover that three were affordable (NFR-PERF-010).
Superseded on 2026-09-25 by FR-VIEW-250, when the maintainer had the snake drawn as one smooth body instead of a body at each point: the body passes through every point the tail lays down, so what this asked of the length stays asked there.

### FR-VIEW-190 — A finished match says so and starts again on a press

```yaml
status: implemented
verification: T
derives_from: [FR-SCORE-140, FR-SCORE-150]
depends_on: [FR-VIEW-120]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/MatchEnd.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/View/BotEntity.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Config/Interface.swift, Sources/CrawlCall/View/ChoicePlate.swift]
tests: [Tests/CrawlCallTests/MatchEndTests.swift]
created: 2026-09-23
```

While the match is over, the system **shall** draw, in place of the steering controls, a plate that names which of the two ends it was and carries one control that begins a new match in the same arena.

**Rationale.** H-010 is measured by whether a first-time player keeps going past the second minute, and until now a match had no end at all; with FR-SCORE-140 and FR-SCORE-150 it has two, and an end that froze the screen with no way back would end the session along with the match.
Which of the two, because they are opposite results — the snake was shot down, or the snake ate the arena empty — and a plate saying only that it was over would leave the player to work out which of them they had just reached.
The same arena, because stage 1 has one map (concept §13) and a choice of levels is a menu, which the vertical slice does not build.
In place of the steering controls, because a stick that still answers after the snake is dead says the match is not over.
"A new match" is the whole of it and not only a new model: played on 2026-09-23, the first restart brought the bots the snake had eaten back the size the last bite had left them, because the drawing kept what the previous match had done to it. Whatever a match changes on screen, starting one puts back.

### FR-VIEW-200 — Text is shown in the player's language

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/TextKey.swift, Sources/CrawlCall/View/Localizable.xcstrings, Sources/CrawlCall/View/MatchEnd.swift, Sources/CrawlCall/View/Controls.swift, Sources/CrawlCall/View/ChoicePlate.swift]
tests: [Tests/CrawlCallTests/TextCatalogTests.swift]
created: 2026-09-24
```

When the game shows text to the player, other than an error line (FR-TOOL-200), the system **shall** show it in the first of the device's preferred languages that the game carries, and in English where it carries none of them.

**Rationale.** The maintainer asked on 2026-09-24 for the interface's text to be built for translation from the start, while there are still only a handful of lines to move.
The first of the preferred languages the game carries, because that is how the device already ranks what its owner reads, and a game that asked again would be answering a question the system has settled.
English as the fallback because it is the language the game is written in, and the only one it carries for now; a language is added by translating the catalog of IF-VIEW-030, not by changing this requirement.
What the fighters say is not text shown here: the model's lines, the pre-written ones and the instructions behind them are a question of their own (Q-290).
An error line is not either: it is a diagnosis for whoever fixes the build, searched for by its identifier, and a released build shows none — the screen that shows one appears only where the bundle cannot start. Translating it would split one identifier's message into as many wordings as there are languages. Found in review on 2026-09-24, when the launch screen was seen printing an error line verbatim.

### FR-VIEW-210 — On an iPad the game plays in the window it is given

```yaml
status: implemented
verification: T
derives_from: [CON-PUB-010]
depends_on: [FR-VIEW-050]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Config/Interface.swift, Sources/CrawlCall/View/SceneView.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/WindowTests.swift]
created: 2026-09-24
```

On an iPad, the system **shall** play in whatever size and orientation of window the player gives it, never smaller than the controls need.

**Rationale.** The maintainer asked on 2026-09-24 for the iPad to play full screen, and Apple's documentation for the installed SDK leaves no way to: "Because `UIRequiresFullScreen` is deprecated, you can no longer opt out of iPad multitasking and dynamic resizing", and in iOS 27 an app's supported orientations are "a preference provided to the system" that "will be ignored when your app is running in a resizable environment". The maintainer took what Apple's guidance for Metal games on iPadOS leaves: any window and any orientation for now, with the orientation locked while the game has the whole screen (FR-VIEW-220) and a pause when that changes (FR-VIEW-230).
Never smaller than the controls need, because a window too narrow for the stick and the eat button side by side is a match the player cannot steer.
The iPhone is untouched: it plays landscape, full screen, as before (FR-VIEW-050).

### FR-VIEW-220 — A game that fills an iPad's screen keeps its orientation

```yaml
status: implemented
verification: T
derives_from: [FR-VIEW-210]
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/GameHostingController.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/WindowTests.swift]
created: 2026-09-24
```

While the game fills an iPad's screen, the system **shall** request that the interface orientation be locked.

**Rationale.** A thumb on the stick tilts the device, and a scene that rotates under it turns the arena a quarter round in the middle of a chase. iPadOS grants the lock only while the scene is centred, as large as the screen and not covered by another, and withdraws it by itself when that stops being so (`prefersInterfaceOrientationLocked`, iOS 26), so the request is the whole of what the game can do and all it needs to.

### FR-VIEW-230 — A change of the orientation lock pauses the match

```yaml
status: implemented
verification: T
derives_from: [FR-VIEW-220]
depends_on: [FR-VIEW-190]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/MatchHost.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/View/ChoicePlate.swift]
tests: [Tests/CrawlCallTests/WindowTests.swift]
created: 2026-09-24
```

When the interface orientation lock is gained or lost on an iPad during a match the player has steered, the system **shall** pause the match and show, in place of the steering controls, a plate with one control that resumes it.

**Rationale.** The moment the lock comes or goes is the moment the scene's geometry changes under the player's thumbs — the window grows to the whole screen, shrinks back beside another app, or turns — and a match that ran on through it would be lost to a change the player did not make in the game. Apple's own example for games does this ("pauseIfNeeded(isInterfaceOrientationLocked:)"), and the maintainer asked for it on 2026-09-24.
A match the player has steered, because iPadOS grants the lock as the scene becomes active full screen — in the same millisecond, in the log of the first build on 2026-09-24 — so every launch would have opened on a paused match nobody had played; a match not yet steered has nothing to lose to the change. Coming back to a match from the background is a change like the others, and pauses it.
The plate is what makes the pause a pause rather than a freeze: the game could pause and had nothing to leave a pause by. It stands where the controls stood, drawn as the plate at the end of a match is (FR-VIEW-190), for the same reason — a stick that answers while the match is paused says it is not.

### FR-VIEW-240 — Drawn boxes have rounded edges

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-VIEW-170, FR-GREENHOLM-030]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/SceneBuilder.swift, Sources/CrawlCall/View/ShotEntity.swift, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Config/Drawing.swift]
tests: [Tests/CrawlCallTests/RoundedBoxTests.swift]
created: 2026-09-25
```

The system **shall** draw every box that stands for a module, a shot or a bird with its edges and corners rounded to a radius of 0.03 m, or of a quarter of the box's smallest side where that is less, and each such box with no more than 400 triangles.

**Rationale.** The maintainer, 2026-09-25, looking at the blockout on the phone: square edges look sharp enough to cut oneself on (Q-400). Only the drawing is rounded: for the body, for sight and for the see-through a module is still its box (ADR-0034).
Each module is rounded on its own, so a wall of many cells and a flight of many steps show a groove between their pieces; the maintainer saw it on the phone the same day and kept it.
The water beyond the island is not rounded, because its slabs meet edge to edge and a rounded edge shows there as a seam. Neither are bots' figures, which ADR-0022 already rounds (Q-420).
The ceiling on triangles is what keeps RealityKit's own rounded box, 13 068 triangles at any size, out of the game (ADR-0037).

### FR-VIEW-250 — The snake is one smooth body

```yaml
status: implemented
verification: D
derives_from: [FR-SNAKE-060]
depends_on: [FR-SNAKE-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SnakeBody.swift, Sources/CrawlCall/View/SnakeEntity.swift, Sources/CrawlCall/Config/Drawing.swift, Sources/CrawlCall/GameSession.swift]
tests: [Tests/CrawlCallTests/SnakeBodyTests.swift, Tests/CrawlCallTests/GameTests.swift]
created: 2026-09-25
```

While the snake is on screen, the system **shall** draw it as one smooth body through the head and every point the tail lays down, resting on the surface under it, rounded at the head and narrowing towards the end of the tail, with no more than 64 triangles for each point of the tail and 256 besides.

**Rationale.** The maintainer, 2026-09-25: the snake is to look better, and the first of four steps is a body rather than a chain of balls. The concept draws the snake as a smooth tube tapering to its tail (concept §2.2, `render-01.jpg`) and its opening makes a spline body through `LowLevelMesh` the first of the spike's three checks; the spike built one, rebuilt every frame, and passed (ADR-0001).
Through every point the tail lays down, because a body that skipped some would show a snake shorter than the model's, which is what FR-VIEW-180 was written against: a snake that has eaten is drawn longer.
Resting on the surface: the balls it replaces stood with their centres at the ground's height, half inside it.
The ceiling on triangles is the lesson of ADR-0037: a mesh made in code has its cost set by numbers somebody chose, and a test holds them to it.
Judged on the phone, and measured there in frames, since the body is rebuilt every frame.

### FR-VIEW-260 — The snake's head has eyes that look where it goes

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-VIEW-250]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SnakeEntity.swift, Sources/CrawlCall/View/SnakeBody.swift, Sources/CrawlCall/View/LowPolySphere.swift, Sources/CrawlCall/Config/Drawing.swift, Sources/CrawlCall/Config/EntityName.swift]
tests: [Tests/CrawlCallTests/GameTests.swift, Tests/CrawlCallTests/SnakeBodyTests.swift]
created: 2026-09-25
```

While the snake is on screen, the system **shall** draw its head wider than its body, with two eyes on top that face the way the head last moved, the eyes in no more than 1024 triangles.

**Rationale.** The maintainer, 2026-09-25: the second of four steps to a better-looking snake. The concept's snake has a head that reads as a head, with big cartoon eyes on top (concept §2.2, `render-01.jpg`), and at the camera's height the eyes are what make it a character rather than a hose.
The way it last moved, because a head that has stopped still has somewhere it was going; and on top, because the camera looks down.
The ceiling is the lesson of ADR-0037 met again: RealityKit's own sphere is 8064 triangles at any size (Q-450), so the eyes are built from a sphere of the game's own, and a test holds them to it.
Judged on the phone.

### FR-VIEW-270 — The snake is green and spotted

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-VIEW-250]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SnakeSkin.metal, Sources/CrawlCall/View/SnakeEntity.swift, Sources/CrawlCall/View/SnakeBody.swift, Sources/CrawlCall/Config/Drawing.swift, Sources/CrawlCall/Config/Resource.swift]
tests: [Tests/CrawlCallTests/GameTests.swift, Tests/CrawlCallTests/SnakeBodyTests.swift]
created: 2026-09-25
```

While the snake is on screen, the system **shall** draw its body a saturated green, paler along its belly, with darker spots on its back and sides that stay where they are on the body as it moves.

**Rationale.** The maintainer, 2026-09-25: the third of four steps to a better-looking snake. The concept's snake is a bright green with darker spots and a sheen (concept §2.2, `render-01.jpg`), and a saturated palette is part of the style (concept §2).
Where they are on the body: a spot fixed to the world would slide along the snake as it crawled, and read as the ground showing through; one fixed to the body goes where the snake goes.
Paler along the belly because a cartoon animal is two-toned, and the camera, looking down, sees the belly only where the body rolls on its side down a drop.
Judged on the phone.

### FR-VIEW-280 — A meal is a swelling that travels down the body

```yaml
status: implemented
verification: D
derives_from: []
depends_on: [FR-VIEW-250, FR-SNAKE-090, FR-VIEW-100]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/Digestion.swift, Sources/CrawlCall/View/SnakeBody.swift, Sources/CrawlCall/View/SnakeEntity.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Config/Drawing.swift]
tests: [Tests/CrawlCallTests/DigestionTests.swift]
created: 2026-09-25
```

While the snake is eating, and after that for as long as the meal takes to pass along the body, the system **shall** draw a swelling on the body that grows behind the head as the prey goes in and then travels down the body to the end of the tail.

**Rationale.** The maintainer, 2026-09-25: the last of four steps to a better-looking snake. The concept names eating as what the style makes funny rather than grim — swallowed whole, a bulge along the body — and squash and stretch as the snake's own subject (concept §2).
Growing as the prey goes in, because the prey is drawn shrinking into the head at the same time (FR-VIEW-100), and the two together say where it went. Travelling on after the meal, at a pace of its own, so that the snake goes on carrying what it ate for a moment after it is free to move.
The swelling changes only how thick the body is along its length, so it adds no triangles to FR-VIEW-250's ceiling.
Judged on the phone.
