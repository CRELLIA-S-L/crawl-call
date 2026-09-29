# Open issues

Discrepancies between the specification and the code, unfinished work, unresolved questions.
Each entry states what diverged, where it was found, and what decision is needed.
Entries are removed once the maintainer decides which side is right and the fix lands.

Entries are numbered `Q-NNN` in tens so that a requirement's rationale can name one; a number is never reused.
Sixteen questions were opened on 2026-09-21 by the decomposition of the concept and fourteen were settled the same day; each settlement is an ADR, so a closed number is found by searching `specs/adr/` for it: Q-010 and Q-090 in ADR-0009, Q-020 and Q-030 and Q-050 and Q-060 in ADR-0010, Q-070 and Q-080 in ADR-0013, Q-100 in ADR-0011, Q-110 in ADR-0014, Q-130 in ADR-0012, Q-150 in ADR-0015; Q-040 became FR-SNAKE-220, Q-140 a sentence in NFR-PERF-010's rationale and Q-160 FR-VIEW-120.
Q-220 — what lies under a wall when a cell holds one module — was opened and settled the same day it was found: the floor is implied under every cell whose module is not walkable (FR-TOOL-020), and a hole is what a map declares on purpose (FR-MAP-110, `draft`).
Two more were opened and settled on 2026-09-22 by the maintainer: Q-190 — whether a severed tail segment stays in the arena — became H-080, and Q-200 — the hypothesis the shedding requirements rest on — became H-070, both in `grounds/10-h-mechanics.md`; a question that turns into a measurement is closed here and answered there.
One more was opened and settled on 2026-09-23, when the kit's wall came down to a fence: Q-240 — whether a bot sees over what the player sees over — became the second paragraph of FR-BOT-050's rationale, which ADR-0022 rewrote on 2026-09-24 when bots got eyes to look from.
Q-230 — the head kept to walkable cells by its centre while its body, wider than a cell, sank into the wall beside it — was opened on 2026-09-22 and settled on 2026-09-24 by ADR-0021: the body is kept out of walls by their geometry. The entry offered a finer grid as one way out and had it backwards; the ADR says why.
Q-210 — whether the game targets iPadOS — was settled on 2026-09-24 by the maintainer: it does, CON-PUB-010 names iPadOS 27, and the target builds for iPhone and iPad alike (`TARGETED_DEVICE_FAMILY = 1,2`); the macOS half was never a divergence, only a sequence, and FR-VIEW-040 still brings it.
Q-270 — the world around the arena, agreed and then built — was closed on 2026-09-25, when the maintainer judged the island, its sky and its birds on the phone and found them good; the sky showed grey-blue there rather than the configured blue, which the maintainer left as it is for now, and Q-350 holds why and what could change it.
Q-400 — the corners of every drawn primitive are sharp — was opened and settled on 2026-09-25: the maintainer had every drawn box rounded as a trial, looked at it on the phone, and kept it, grooves between neighbouring modules included; it became FR-VIEW-240, and ADR-0037 holds what it cost and why RealityKit's own rounded box was not used. The bots' figures went on to Q-420.
Q-420 and Q-450 — the bots' figures and the shrubs drawn with RealityKit's own rounded box and sphere, tens of thousands of triangles each — were settled on 2026-09-29 by ADR-0046, when the frame rate on the phone fell and the figures were found to be four fifths of the scene's triangles: both are drawn with the game's own shapes, the figures at their own radii.
What remains is what a decision inside the repository cannot close.

### Q-120 — The name is chosen; the search that clears it is not done

- **Found:** concept §14, §17.6; CON-PUB-090.
- **What diverged:** the maintainer settled the name as "Crawl Call: Chomp Company" on 2026-09-22, deliberately ahead of the trademark search rather than after it. The reason the search was asked for stands: "Chomp" is taken in apps (a children's app, a Google Play game, a UK studio), and "Crawl Call" — the half that carries the mark — has not been searched at all.
- **Decided:** on 2026-09-21 the order was search first, name after. On 2026-09-22 the maintainer reversed it and named the game, which changes what the search decides — no longer which name to take, but whether this one survives. A professional search in classes 9 and 41, EU first, is still commissioned before any public announcement, the name appears nowhere outside the repository until then (CON-PUB-090), and registration, if it clears, is by the company (ADR-0007).
- **Still needed:** the search itself — an action outside the repository, in classes 9 and 41, EU first, on "Crawl Call" before the full string. The entry closes when the result is recorded here.
  If it does not clear, what changes is not only the name: the code short name `CrawlCall` — the Xcode target, the source folder and the tail of the bundle identifier — goes with it, which is the cost of having named the game first.

### Q-170 — A hypothesis on bounded waiting, for the maintainer to write

- **Found:** ADR-0010 declines an artificial counterweight to stealth and relies on cover erosion (concept §7) to bound how long a player waits.
- **What diverged:** whether waiting stays bounded in play is a claim about players, and the grounds register's standard reserves writing a hypothesis — population, threshold, owner — to the person who will measure it.
- **Proposed text, not written:** *H-060 — Waiting stays bounded without a timer.* Class III; population: playtesters of the stage-3 build; refuted if `proportion > 0.40 at n >= 5` of sessions contain a single stretch of inaction longer than three minutes while prey is reachable; expires with the stage-3 playtest; impact: if refuted, ADR-0010 gains the decaying multiplier it declined.
- **Still needed:** the maintainer writes it into `grounds/10-h-mechanics.md`, or declines it and says so here.

### Q-180 — The thermal degradation factor

- **Found:** IF-BOT-010; NFR-PERF-060, NFR-PERF-070.
- **What diverged:** the threshold has a default the spike measured — `serious`, which a twenty-minute run on the iPhone 16 Pro never reached — but the factor by which the commander intervals stretch once it is crossed has none. The concept asks for the mechanism (§15) and names no number, and the spike never entered the state the factor applies to, so nothing in the repository measures it.
- **Still needed:** a number from the maintainer, or a session long enough to reach `serious` on the baseline device and read what interval keeps the frame rate. Until then `config/match.json` carries whatever value the build ships and the requirement is unverifiable against a default.

### Q-250 — The frame rate has been looked at, not measured

- **Found:** NFR-PERF-010; the Metal performance HUD on 2026-09-24.
- **What diverged:** NFR-PERF-010 is verified by `A`, which `specs/50-verification.md` defines as an unattended run along a fixed route with the telemetry pulled from the device afterwards. What exists is a look. On 2026-09-24, after ADR-0020's hole shader went in, the game was launched on the iPhone 16 Pro with the Metal performance HUD: at the match's start it read 59.99 frames per second, a GPU time of 6.86 ms and a frame interval of 16.67 ms, against the 13.3 ms a frame on that phone is held to. In play the maintainer saw a couple of spikes on the HUD's graph, too brief to tie to anything on screen.
- **Decided:** the maintainer judged it good enough for now, on 2026-09-24. A look is not a measurement, so NFR-PERF-010 stays `deferred`.
- **Still needed:** an autopilot that drives the snake along a fixed route, so that a run is the same run twice. The rest of the game's own instrument exists since 2026-09-24: the frame record — every frame's interval, the time of each phase of the game's step and the events in it (FR-TOOL-230), written when a match ends, the app leaves the foreground or it is terminated (FR-TOOL-240) — and the run tool that takes it off the device and names the slowest frames (FR-TOOL-250). Its first run on the iPhone 16 Pro, twenty seconds with nobody playing, recorded 1230 frames with one late — the second, at 70.6 ms, as the match started — and the game's own step under 0.3 ms a frame. Three minutes of the maintainer's own play on the same phone, with the snake eating seven bots, recorded 10 877 frames with two late, both as the match began, and the game's own work at most 3.1 ms in any phase of a frame (ADR-0030). A reading by `A` also needs the route, so NFR-PERF-010 stays `deferred`.

### Q-260 — The see-through of the walls around the snake does not sit right with the maintainer yet

- **Found:** FR-VIEW-150, FR-VIEW-155; the maintainer on the phone on 2026-09-24, after ADR-0021.
- **What diverged:** nothing in the specification; the build does what FR-VIEW-150 and FR-VIEW-155 ask. The maintainer found the see-through of the walls around the snake somewhat off, and put it off for later. Two things cut a wall near the snake open. The line of sight: a wall within the body's radius plus the see-through margin of IF-VIEW-020 — 0.3 + 0.15 = 0.45 m — of a line from the camera to any part of the snake (ADR-0019, ADR-0020); since ADR-0021 a wall the body touches on the camera's side or on either flank is 0.3 m from the head's centre and within that, while one the body touches from behind is not, the line stopping that margin short of the head (ADR-0019, point 2). And the window around the head: any module within the visibility radius, 1.6 m, that is not wholly beyond the head and stands higher than the floor the head is on (FR-VIEW-155).
- **Still needed:** on 2026-09-25 the maintainer narrowed it: what is off is walls and crates beside the head opened though they hide nothing. Two cuts can do that — the line of sight of FR-VIEW-150, a cylinder about each line from the camera to a part of the snake, and the window of FR-VIEW-155, a sphere of the visibility radius around the head, 1.6 m (`config/view.json`) — and a module both reach is cut with one sphere holding the two (ADR-0020). Debug mode tints each cut by its cause and switches either off (FR-TOOL-260, FR-TOOL-270), and with them on the phone the maintainer found that it is the window. A match runs without it since 2026-09-25 (FR-VIEW-155, `partial`); it is kept, switched back on in debug mode, until the maintainer is sure it can go — or chooses a smaller radius, or a window kept to the side of the head that faces the camera. The cylinder over-cuts too, but near the camera rather than beside the head: a cut that shows the snake need only be as wide, where it passes a module, as the snake looks from there, a cone from the camera to the snake rather than a cylinder.

### Q-280 — The parameters of the drawn models wait for a rework before ART-070 reaches them

- **Found:** ART-070; `Sources/CrawlCall/View/Figure.swift`, on 2026-09-24.
- **What diverged:** the figure a bot is drawn as (ADR-0022) is built from a table of parts — each a box, a sphere or a cylinder with its size, centre and paint — written as literals in `Figure.swift`: 167 numbers other than 0, 1, 2 and 0.5, more than half of all such literals under `Sources/` by a count taken that day. Neither home ART-070 offers fits them: a name for every box size says nothing the table does not, and moving the table to `config/` makes a drawn shape a tuning file with an interface requirement to describe it. The maintainer decided on 2026-09-24 that how the drawn models are parameterised is to be reworked as a whole, and the figure simplified rather than moved as it stands, so bringing their numbers to ART-070 now would be work thrown away. After the pass of 2026-09-24 these parameters are all that is left outside ART-070 in `Sources/CrawlCall/`: the figure in `Figure.swift`; the colours, materials and sizes in `SnakeEntity.swift`, `BotEntity.swift` — the smallest an eaten body shrinks to among them — and `ShotEntity.swift`; the modules' materials in `SeeThrough.swift`; and the hole shader, `SeeThroughHole.metal`, whole — its two tuned constants and the arithmetic around them, since where a shader keeps a named value is part of the same question.
- **Still needed:** a discussion of how a drawn model is parameterised and of a simpler figure — fewer parts, proportions that follow from a few named ones — the first one taken up once the ground rules of ART-070 are settled. Until then the model parameters are left as they are, even where a change touches their file; the rest of the code is brought to ART-070 as a change touches it.

### Q-290 — What the fighters say is not translated

- **Found:** FR-VIEW-200; the maintainer on 2026-09-24, when the interface was set up for translation.
- **What diverged:** nothing yet; the game carries English alone. FR-VIEW-200 covers the text the interface shows and deliberately leaves out speech: the lines the model generates, the pre-written lines of IF-CMD-030, and the instructions of IF-CMD-040 and IF-CMD-050 that make the model speak. Translating those is not a matter of a catalog: the model has to be asked to speak the player's language, every measurement ADR-0017 rests on was taken with English instructions, and FR-TOOL-170 carries none of them across a change to the configuration.
- **Still needed:** a decision on whether the fighters speak the player's language, and if they do, the instructions in each language measured again by the unattended run, the pre-written lines translated, and the content list of IF-CMD-060 written for each language. Taken up when the game carries a second language.

### Q-300 — Xcode's AppIntents tool warns about a framework the game does not use

- **Found:** ART-080; the build log on 2026-09-24.
- **What diverged:** every build prints `appintentsmetadataprocessor … warning: Metadata extraction skipped, no AppIntents.framework dependency found`, once per target. ART-080 asks for a build with no warning. The notice is Xcode's own build phase saying there is nothing for it to do, since the game does not link AppIntents; no build setting of the project was found that turns it off — `xcodebuild -showBuildSettings` lists none for the phase — and linking a framework the game does not use to quiet a notice would be a dependency added for nothing, which ART-040 asks an ADR to justify and none could.
- **Still needed:** nothing from inside the repository. The entry stands, as ART-080 allows, until a version of Xcode stops printing it or offers a setting for it; FR-TOOL-220 does not list it among the build's warnings because it names no file or setting of the project.

### Q-310 — What a bot has to fight with beyond a magazine is not decided

- **Found:** the maintainer on 2026-09-25, listing what a bot weighs in choosing an action (FR-BOT-080), among it the arms it has — rounds, grenades and the like.
- **What diverged:** nothing yet. The concept and the specification give a bot a weapon with a magazine and nothing else; grenades appear in neither. FR-BOT-080 names what a bot has to fight with as an input, and today that is its rounds alone.
- **Still needed:** a decision on the equipment a bot carries — grenades, and what else — what each does in the arena, to the snake, to cover (FR-MAP-030) and to the other squad, and how much of it a bot has; then its requirements, its numbers in the bot configuration (IF-BOT-010) and its actions beside those of FR-BOT-200.

### Q-320 — A bot with nothing happening around it stands still

- **Found:** the maintainer on 2026-09-25, while settling what a bot weighs in choosing an action (ADR-0032).
- **What diverged:** nothing in the specification: with no enemy, no snake, no order and no danger in what it knows, no action that moves a bot scores anything — reloading and healing a squadmate still can — and a bot stays where it is. The maintainer wants motives that keep an idle bot alive to the player — idle curiosity, for one — so that bots do not simply stand in place when nothing is going on.
- **Still needed:** what those motives are and what a bot does under them — wandering, looking round, drifting towards something it has not seen — with how they rank against the rest of FR-BOT-080's inputs, since a motive for the quiet must never outweigh a threat; then a requirement for each. The knowledge a bot keeps (ADR-0032) gives curiosity something to read: the cells it has not yet seen.

### Q-330 — A way straight up for towers and lookouts waits for destruction

- **Found:** the maintainer on 2026-09-25, replacing the stair that went straight up in one cell with a flight of steps (ADR-0033).
- **What diverged:** nothing: no map has a way straight up any more. The map format keeps its `transition` line for one (IF-MAP-010), and the graph and the snake still follow such a line.
- **Still needed:** whether vertical ladders come back to reach sniper points — towers, lookouts — and how they look and are climbed; taken up after the snake's destruction of buildings is settled (FR-MAP-030), since a tower is first of all something the snake can bring down.

### Q-340 — A bot's posture: standing, kneeling, lying

- **Found:** the maintainer on 2026-09-25, to be laid down for the future.
- **What diverged:** nothing yet; a bot is always standing. The maintainer wants a bot to choose its posture: standing — fast, the widest view, the least accurate fire; kneeling — middling speed, a middling view, fire better than average; lying — very slow, a low or narrow view, very accurate fire, and no grenades.
- **Still needed:** the numbers of each posture in the bot configuration (IF-BOT-010), and three things the specification does not have yet. Fire has no accuracy: a shot with a line of fire hits (FR-BOT-060), so accuracy needs a model of a miss first. A bot's eyes are one height (FR-BOT-050), and a posture lowers them — and lowers what the others see of the bot, so that a lying bot is hidden by cover a standing one is not. And a view that is narrow needs a direction to be narrow around, which a bot does not have. Grenades are Q-310. Then how posture enters the choice of action (FR-BOT-080), and the figure drawn for each (FR-VIEW-070).

### Q-350 — Greenholm's sky shows grey-blue, not the blue it is configured with

- **Found:** the maintainer on the phone, 2026-09-25, through the free camera of debug mode; measured the same day on the simulator with the camera tilted to 10 degrees, its lowest (ADR-0031).
- **What diverged:** FR-GREENHOLM-020 asks for a daylight sky, and the sky shows as a pale grey-blue. The picture is applied — painted pure red, the sky came out red, 0.89, 0.13, 0 — and its colour space is honoured: repainted in linear light, it came out the same to the third decimal. What washes it is RealityKit's default tone mapping, which runs over the whole frame and pulls light, saturated colours towards grey. About 14 degrees above the horizon, near the top of that frame, the configured gradient is about 0.73, 0.83, 0.95 and the screen shows 0.70, 0.78, 0.84 — its blue and green held down, the colour pulled grey; at the horizon it is 0.80, 0.88, 0.96 and shows 0.75, 0.80, 0.85. `ToneMappingComponent` (iOS 27.0) on the camera changes it: an exposure of −1 darkens the sky and leaves it as grey, 0.53, 0.61, 0.68 at the top; a flat curve — toe, shoulder and angle all zero — gives the sky its blue, 0.77, 0.87, 0.96 at the top and 0.84, 0.90, 0.97 at the horizon, and washes out everything else: the shore goes white, the water a sharp cyan, the walls, grass and stairs pale. The match camera never shows the sky, so a match is not touched by any of it (ADR-0031).
- **Still needed:** the maintainer left it as it is on 2026-09-25 and chose among three when it is taken up: give the sky, in `config/setting/greenholm.json`, deeper and more saturated colours that land on the intended ones after the tone mapping, which changes the sky and nothing else and is settled by eye; tune the tone mapping for the whole game through `ToneMappingComponent`, which changes the look of everything and means settling the sun, the ambient and the kits' colours again; or keep the grey. The probe that measured it tilts the free camera to its lowest at the start of a match — `session.tiltCamera(by:screenHeight:)` with a large negative number — and was not kept.

### Q-360 — Where the squads are born is not the map's to say yet

- **Found:** the maintainer on 2026-09-25, while settling that the map names the snake's spawn points (FR-MAP-180).
- **What diverged:** nothing: the squads are placed by computation — the red squad as far from the snake as the graph reaches, the blue squad as far from both as the grouping distance keeps them (`Squads.spawn`). The maintainer wants the map to name the area each squad is born in, later.
- **Still needed:** how a map names a squad's area — cells, a rectangle, a named zone — and whether the computed placement stays as the fallback for a map that names none; then its requirement beside FR-MAP-180 and the header line in IF-MAP-010.

### Q-370 — Should the text maps be turned into Reality Composer Pro 3 scenes when the app is built?

- **Found:** the maintainer on 2026-09-25, while the blockout was being checked for ways the snake cannot take (FR-MAP-260).
- **What diverged:** nothing yet. Today a map is a text file read at launch: the scene is assembled from the kit (FR-TOOL-020), the island's edge is drawn (FR-MAP-200, some 73 ms on the simulator, ADR-0034), and the map is checked (FR-MAP-260, some 50 ms on the phone, ADR-0035), every time the app starts. Reality Composer Pro 3 is the project's level editor (`specs/02-overview.md`), and nothing connects it to the text maps.
- **The question:** whether to add a tool that turns each text map into a Reality Composer Pro 3 scene, run it as a step of the app's build, and ship the generated scenes in the final build instead of assembling them at launch.
- **Still needed:** what the generated scene would hold — the modules, the island's surfaces, the scenery — and what stays computed at launch: the navigation graph, the plan the snake and the bots read, the see-through that cuts modules open (FR-VIEW-150); whether the check of FR-MAP-260 moves to the build, so that a map that shows a false way fails the build rather than the launch; whether a scene edited by hand in Reality Composer Pro 3 can come back into the text map or is overwritten by the next build; and what the build step needs that the project does not have — a command-line way to write a Reality Composer Pro 3 package, and whether it runs within ART-040's standard tools.

### Q-380 — Should the drawn models move to Reality Composer Pro 3, or be converted into it?

- **Found:** the maintainer on 2026-09-25, beside Q-370.
- **What diverged:** nothing yet. Every model the game draws is built in code from RealityKit's primitives: the snake (`SnakeEntity.swift`), the bots' figures from a table of parts (`Figure.swift`, `BotEntity.swift`, ADR-0022), the shots (`ShotEntity.swift`), the modules and the kit's trees and shrubs (`SceneBuilder.swift`), and the island's scenery and the birds (`SceneryBuilder.swift`). Their parameters are already waiting for a rework of how a drawn model is parameterised (Q-280). Reality Composer Pro 3 is the project's level editor (`specs/02-overview.md`), and no model is made in it.
- **The question:** whether to move the models — the snake, the bots, the birds, the trees and shrubs, and whatever is drawn later — to Reality Composer Pro 3 assets made and edited there, or at least to add a tool that converts the models built in code into Reality Composer Pro 3 assets.
- **Still needed:** which models move and which stay built in code — what changes at run time, as the snake's body grows and bends, a bot shrinks when eaten, a wing beats, a module is cut open by the see-through (FR-VIEW-150), and so is drawn by the code whatever it starts from; whether moving the models settles Q-280 or is its answer; whether the conversion runs once, to hand the models to an editor, or at every build, like the maps of Q-370; how an asset made by hand is kept to the sizes the game plays by — the body's radius, a module's box, the eye height a bot sees from; and whether the kit's legend (IF-MAP-010) names assets rather than figures once there are assets to name.

### Q-390 — Should the map move to hexagonal cells?

- **Found:** the maintainer on 2026-09-25, after the snake fell off the balcony wherever its head crossed a corner of a cell (ADR-0036).
- **What diverged:** nothing yet. Every map is a grid of square cells: the map file's rows (IF-MAP-010), the navigation graph that joins cells side by side (FR-MAP-020), the kit's modules sized to a square cell, the flights that rise along a row or a column (FR-MAP-150), the island's edge drawn round the cells (FR-MAP-200), the check of what a map shows the snake (FR-MAP-260), and the snake's head that asks which cell it is in.
- **The question:** whether to move the map to hexagonal cells. Hexagonal cells meet only along sides, never at a single point, so a corner between two cells — which a square grid has at every cell and which the head fell through until ADR-0036 — would not exist; every neighbour would be the same distance away, and a diagonal way would no longer be a staircase.
- **Still needed:** how a hexagonal map is written as text, which rows a file can hold; what a wall is — a module on a cell, as now, or a module on a side between two cells; which ways a flight can rise, and how a building with square rooms is laid on hexagons; what the kit's modules become, and whether the blockout is redrawn or converted; what moving costs in the parts listed above; and whether to decide before the kit's models are reworked (Q-280, Q-380), since those are sized to the cell.

### Q-410 — Leaping a gap too wide to crawl across

- **Found:** the maintainer on 2026-09-25, while settling that the snake crawls across a gap narrower than its body (FR-SNAKE-260).
- **What diverged:** nothing yet. A gap as wide as the body or wider is a ledge: the snake drops into it where there is ground within the tuning's drop below (FR-SNAKE-220), and stops at it where there is none.
- **The question:** whether the snake may, later, leap a gap wider than its body.
- **Still needed:** how the player asks for a leap, or whether it happens by itself at speed; how wide a gap can be leapt, and whether that depends on the snake's length or speed; what the tail does in the air, since today every part lies on the ground or down a drop (FR-SNAKE-220); whether bots can follow across, which the navigation graph does not allow (FR-MAP-020); and what a map shows so that a gap that can be leapt looks different from one that cannot (FR-MAP-260).

### Q-430 — Fish that leap from Greenholm's water

- **Found:** the maintainer on 2026-09-25, while the water was being made prettier (FR-GREENHOLM-040 through FR-GREENHOLM-070): for later, some life in the water, such as fish leaping out at random with rings spreading on the water round them.
- **What diverged:** nothing yet. The only life in Greenholm is its birds (FR-GREENHOLM-030); the water has waves (FR-GREENHOLM-070) and nothing in it.
- **The question:** whether fish leap from the water, and what else lives in it.
- **Still needed:** how often and where — within the match frame only, as the birds are (FR-GREENHOLM-030), or anywhere; what a fish is drawn as, whether from primitives like the birds or an asset (Q-380); how the rings are drawn — the water shader takes one value per material (ADR-0038), so rings at a point need another way in, or a drawn ring on the surface; whether a fish takes any part in play, which FR-MAP-130 forbids for scenery; and what it costs in frames.

### Q-440 — The match takes longer to appear since the water got its shaders

- **Found:** 2026-09-25, reading the first frame of every frame record made that day on the maintainer's iPhone 16 Pro (`specs/50-verification.md`).
- **What diverged:** the first frame of a match came 0.48–0.58 s after launch in six runs before the water had a shader, 0.97–1.46 s in four with the waves (FR-GREENHOLM-070), and 1.0–1.57 s in three with the floor under the water as well (FR-MAP-270, FR-MAP-280) — so the floor is not clearly a part of it; once running, the match holds 60 frames a second. No requirement bounds the time from launch to a match on screen.
- **The question:** what the time goes to — compiling the two surface shaders when their materials are first made, building the floor's height field and the distance field under it, or the transparent water's first draw — and whether it matters.
- **Still needed:** a cold launch measured with the shaders and without, and with the floor and without, each run straight after the other on a cool phone that nobody touches; whether a second launch, with the shaders compiled once, is faster; and whether a bound on the time to a match belongs with NFR-PERF-010.
