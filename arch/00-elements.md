# Elements

`E-NNN` — the parts this system is made of.

Each record names what the part is responsible for, the files it is made of, and the requirements it carries.
The join points one way: an element names its requirements, and a requirement never names an element.
The list is the part that answers for an obligation, not every part a file of which the requirement's `code` field happens to name — deriving it from those fields was tried on 2026-10-10 and rejected, because `code` names everything a requirement is realized in and the projection then had the configuration part answering for how the snake moves (ADR-0071).
It is kept by hand, which means it is closed with the code: a requirement that reaches `implemented` goes into the list of the part that answers for it, in the same set of edits.

What the parts lean on is in `depends_on`, written by hand and compared against `arch/edges.json` — one reference between two files for every pair of parts the code joins, which is how a model written in Swift gets something to disagree with (ADR-0071).

Cut the parts as coarsely as the system allows.
An element per module says nothing the file tree did not; an element per boundary somebody could cross without noticing is what this layer is for.

The format is in `srs-dd/arch.md`.

### E-010 — The prompt bench

```yaml
status: built
carries: [Sources/PromptBench/PromptBench.swift, Sources/PromptBench/PromptVariants.swift, Sources/PromptBench/main.swift, Sources/PromptBench/BenchReport.swift]
requirements: [FR-TOOL-150, FR-TOOL-160]
depends_on: [E-040]
interface: a command line — variants and repeats in, one summary line per configuration out, optionally a CSV
units: [prompt-bench]
```

Calls the system language model with a given set of instructions, schema and world states, and reports what came back: blocked calls, tokens, latency and the text of every line.

**Rationale.** The first part of this system to exist, and a boundary worth naming even while it is the only one: it is the only code that talks to the model outside the game, it runs on the Mac rather than the device, and it ships with the repository rather than with the app.
It is also what keeps a prompt change honest (FR-TOOL-170), so a later part that generates lines at run time must not absorb it — the bench has to stay runnable without the game.
It leans on the map layer for one thing: the world states it asks the model about are built from a kit, and `Kit` is the map layer's.

### E-020 — The configuration contract

```yaml
status: built
carries: [Sources/CrawlCall/Config, config/bot.json, config/match.json, config/scoring.json, config/snake.json, config/tuning.json, config/view.json]
requirements: [IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, IF-SCORE-010, FR-TOOL-200]
depends_on: []
interface: a bundle in, one `Configurations` value or one named error out — entered by `Configurations`, `Configurations+Load`, `DebugText`, `Drawing`, `EntityName`, `ErrorIdentifier`, `FrameRecording`, `Geometry`, `GreenholmConfiguration`, `IntentName`, `Interface`, `Lighting`, `MapFormat`, `Motion`, `Resource`, `Surroundings`, `SymbolName`, `TextKey`, `Utility`
protects: [IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, IF-SCORE-010]
units: [crawlcall]
```

Reads every configuration file once when the game starts, refuses a file whose shape is wrong, and hands the rest of the game one value holding the tuning.

**Rationale.** A boundary worth naming because everything downstream reads numbers through it and nothing downstream should read a file: a part that opens `config/` on its own would bypass the shape check that makes a typo an error (ADR-0012), and the mistake would look like a wrong number rather than a broken file.
The configuration files are carried here with the code that reads them, for the same reason: the shape a file must have and the file are one change, and a key added in one without the other is the error this part exists to catch. Where a file is a part's own content rather than tuning — a kit, a setting — that part claims it by the more specific path (`config/kit` with E-040, `config/setting` with E-100).
It reaches nothing: this is the one leaf in the cut, which is what a contract the whole game reads through should be. It was not one until 2026-10-10, when standing the game up left for E-110 (ADR-0071).

### E-030 — The input contract

```yaml
status: built
carries: [Sources/CrawlCall/Input]
requirements: [IF-VIEW-010, FR-VIEW-050]
depends_on: [E-020]
interface: four intents, and nothing else crosses into the game logic — entered by `Intent`, `TouchScheme`
protects: [IF-VIEW-010]
units: [crawlcall]
```

The intents the input schemes produce and the game logic consumes.

**Rationale.** Separate from start-up because it is the other place a boundary can be crossed quietly: a scheme that reached past the intents into the logic, or logic that read a touch event, would leave the abstraction intact on paper and gone in fact (FR-VIEW-030).
One file today, and the element is what keeps the fifth intent a change to IF-VIEW-010 rather than an addition somebody makes in passing.
It leans on the configuration contract for the stick's geometry and the names the intents are logged under, and on nothing else.

### E-040 — The map layer

```yaml
status: built
carries: [Sources/CrawlCall/Map, maps, config/kit, ATTRIBUTION.md]
requirements: [IF-MAP-010, FR-TOOL-010, FR-TOOL-020, FR-TOOL-030, FR-MAP-010, FR-MAP-020, FR-MAP-120, FR-MAP-200, FR-MAP-100, FR-MAP-090, FR-MAP-150, FR-MAP-160, FR-MAP-170, FR-MAP-180, FR-MAP-190, FR-MAP-210, FR-MAP-220, FR-MAP-260]
depends_on: [E-020]
interface: a map file and its kit in; the placements, the navigation graph, the scene geometry, the value a match is handed and where the ground ends out — entered by `DistanceField`, `GroundRect`, `Kit`, `MapSpecification`, `NavigationGraph`, `Outline`, `Passages`, `PieceIndex`, `SampleGrid`, `ScenePlan`, `Setting`, `Sight`, `World`
protects: [FR-MAP-020]
units: [crawlcall]
```

Turns one text file into everything a match is handed to run on: what the bots path over, what the player sees, which setting the arena stands in and where that setting's ground ends — and answers the two questions play asks of the geometry afterwards, what stands in the way of a straight line between two points (ADR-0019) and how far a point lies from the nearest thing.

**Rationale.** The boundary that matters here is between the two models, and it is kept by making them one part rather than two: the graph and the geometry are derived from the same parse, in the same place, so a bot cannot path over a cell where no floor was placed.
Splitting parsing from geometry would look tidier and would let exactly that drift in, which is the failure the spike's navigation mesh made expensive (ADR-0016).
The line test sits here for the same reason and not in the view: the picture the player reads and the bots' eyes have to agree about what a wall is, and a part that owned the geometry but not the question asked of it would be a part with two answers waiting to happen. What the rule is, and the divergence standing in it, are ADR-0019; the requirements it serves stay with the parts that own them — FR-VIEW-150 and FR-VIEW-155 with E-050, FR-BOT-050 with E-090.
It depends on the configuration contract because the cell size it measures in is tuning (IF-MAP-020), read by E-020 — and on nothing else, which is what makes everything above it placeable in an order.
Four files joined it on 2026-10-11 from the surroundings, and the reason is the same boundary FR-MAP-130 draws (ADR-0073): the setting a map's header names, the outline that header's ground floor makes, the field that answers how far a point lies from it and the rectangle of ground both are measured in are all read by play — the passage check asks where the ground ends, the snake asks before it lets the head off the edge — while the scenery drawn over them is read by nothing below the view. They were filed with the scenery and are now filed with the map they are computed from, which is also what untied the circle the two made.
`Map/SceneBuilder.swift` left for the view on the same day and for the mirror reason: a file whose whole work is turning metres into RealityKit entities belongs with the entities, and while it sat here the map layer reached up into the view fourteen times.
`ATTRIBUTION.md` sits here for want of a better home rather than by right: it is a repository-wide document, and today the only requirement that reads it is FR-MAP-100's "a kit listed in the attribution file". When CON-PUB-030 has third-party assets to list, the file belongs to whatever owns the repository's guards, and this line moves with it.

### E-050 — The view

```yaml
status: built
carries: [Sources/CrawlCall/View]
requirements: [FR-VIEW-010, FR-VIEW-130, FR-VIEW-020, FR-VIEW-060, FR-VIEW-070, FR-TOOL-070, FR-VIEW-100, FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, FR-VIEW-170, IF-VIEW-030, FR-TOOL-260, FR-TOOL-270, FR-VIEW-240, FR-VIEW-250, FR-VIEW-260, FR-VIEW-270, FR-VIEW-280, FR-VIEW-290, FR-VIEW-300, FR-VIEW-310, FR-VIEW-320, FR-VIEW-330, FR-VIEW-340]
depends_on: [E-020, E-030, E-040, E-060, E-090]
interface: a scene plan in; the camera it is seen through and the light it is read by, out — entered by `BotEntity`, `ChoicePlate`, `Controls`, `Digestion`, `FreeCamera`, `Gait`, `GameHostingController`, `LowPolySphere`, `LungePose`, `MatchEnd`, `MatchHost`, `SceneView`, `SeeThrough`, `ShotEntity`, `SnakeBody`, `SnakeEntity`, `SwallowPose`
protects: [FR-VIEW-010]
units: [crawlcall]
```

Decides how the arena reaches the player: one camera at a fixed pitch, one daylight source with the ambient that keeps shadows readable, the looks a map module has — solid; faded whole while it is a floor over the snake; or cut open where a line of sight to the snake goes through it, or around the head (ADR-0020) — the figures the bots are drawn as (ADR-0022), the free camera of debug mode (ADR-0023), and the controls the player's thumbs land on.

**Rationale.** Split from the map layer because the two answer different questions and change for different reasons: the map changes when a level does, the view when the game's look does, and a file holding both invites a camera decision to be made while editing geometry.
The boundary is also where the specification puts it — the VIEW area owns the angle and the light, the MAP and TOOL areas own what is placed and where.
Three of its dependencies run upward: the SwiftUI screens it holds — `MatchHost`, `MatchEnd`, `FreeCameraControls`, `SeeThroughSwitches` — reach into the match for `Game`, `GameSession` and `FrameRecorder`, and the entities it draws read the snake and the squads directly. Whether the screens are the view's at all is the first question in Q-530.

### E-100 — The surroundings

```yaml
status: built
carries: [Sources/CrawlCall/Setting, config/setting]
requirements: [FR-MAP-130, FR-MAP-140, FR-MAP-270, FR-MAP-280, IF-GREENHOLM-010, FR-GREENHOLM-010, FR-GREENHOLM-020, FR-GREENHOLM-030, FR-GREENHOLM-050, FR-GREENHOLM-060, FR-GREENHOLM-070]
depends_on: [E-020, E-040, E-050]
interface: a setting, the arena's plan and the edge of its ground in; the scenery around the arena, the sky and the birds out — entered by `Birds`, `FrameCoverage`, `Greenholm`, `Scenery`, `SceneryBuilder`
protects: [FR-MAP-130]
units: [crawlcall]
```

Draws the world the arena stands in: finds how much ground the match camera can show, lays the setting's parts over it — for Greenholm the island, its ring of trees and shrubs, the water and the sky — and flies the birds (ADR-0031).

**Rationale.** Its own part because the one thing it must never do is reach into play (FR-MAP-130): the map layer's pieces are what the snake collides with, what the bots see and what is cut open, and a part that could add to them would put scenery into all three without anybody deciding it. Kept apart, it reads the plan and never writes it.
It holds only what is drawn. On 2026-10-11 four files left it for the map layer (ADR-0073) — the setting a map's header names, the outline of its ground floor, the distance field and the rectangle of ground — because every one of them is read by play, and this part's whole reason is that play may not read it. What stayed is the scenery: the coverage the setting is sized for, the island's parts, and the birds.
It depends on the map layer for the arena's plan, the setting and the edge of its ground, on the configuration contract for the view configuration the coverage is computed from, and on the view for the scene it adds what it builds to — which is a dependency inside its own level rather than one running against the cut.
It still takes the value a match runs on, and that is no longer a reach upward: `World` moved from start-up to the map layer on the same day, so the part that draws the scenery now reads it from below rather than above (ADR-0073).

### E-060 — The snake

```yaml
status: built
carries: [Sources/CrawlCall/Snake]
requirements: [FR-SNAKE-010, FR-SNAKE-015, FR-SNAKE-016, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-060, FR-SNAKE-070, FR-SNAKE-090, FR-SNAKE-100, FR-SNAKE-210, FR-SNAKE-220, FR-SNAKE-260, FR-SNAKE-270, FR-SNAKE-055, FR-SNAKE-056, FR-SNAKE-280, FR-SNAKE-285, FR-SNAKE-290, FR-MAP-025]
depends_on: [E-020, E-040, E-090]
interface: a held direction and a frame's time in; a head, a floor and a trail out — entered by `Coil`, `Eating`, `Lunge`, `Snake`, `Surfaces`
protects: [FR-SNAKE-010]
units: [crawlcall]
```

Where the snake is and where it has been: the head's movement over walkable surfaces with its body kept out of what stands on them, the slide along what it cannot pass, the drop it may take, the trail the tail is read from, and the meal that holds it still while the tail grows.

**Rationale.** A part of its own because it is the one place that decides whether a move is allowed, and the game will grow several callers of that decision — eating holds the head still, abilities move it differently, a bot's shot shortens the tail. A rule about passing through walls that lived in each of them would be a rule in none.
It leans on the map layer for what is walkable and for the boxes of what is not: the snake asks the graph and the scene plan, it does not read the map file, and it has no idea how any of it is drawn (ADR-0021).
It also leans on the configuration contract for its tuning, and on two parts it should not: `Snake/Eating.swift` and `Snake/Lunge.swift` read `Archetype` and `Perception` from the squads, and `Snake/Surfaces.swift` reads the surroundings' distance field to know where the island ends. Both are in Q-530.

### E-070 — The match

```yaml
status: built
carries: [Sources/CrawlCall/Game.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Record]
requirements: [FR-VIEW-030, FR-SCORE-140, FR-SCORE-150, FR-TOOL-230, FR-TOOL-240]
depends_on: [E-020, E-030, E-040, E-050, E-060, E-090]
interface: intents in, a frame advanced, the scene and the camera moved to follow — entered by `FrameRecorder`, `Game`, `GameSession`, `TerminationRecord`
protects: [FR-VIEW-030, FR-SCORE-140, FR-SCORE-150]
units: [crawlcall]
```

What runs while a match is on: the intents the player sends, the world advanced once per frame, and the drawing brought up to date afterwards — and the two ends that stop all of it.

**Rationale.** This is the boundary FR-VIEW-030 draws — intents in, never touches or keys — and it is worth a part of its own so that the rule has somewhere to live rather than being a habit of whoever writes the next input scheme.
It is also the only part that knows the order of a frame: the world moves first and the picture follows, never the other way round, which is what keeps the camera from chasing a head that has not moved yet.
Whether a match is still on belongs here for the same reason: the two ends (FR-SCORE-140, FR-SCORE-150) are read off the snake and the bots but are a fact about the match, and a part that asked the snake whether the game was over would be the beginning of two answers.
It reads `World` from start-up, which is the one dependency here that runs upward: the value a match is given to run in is declared in `Launch.swift` rather than below the parts that read it (Q-530).

### E-090 — The squads

```yaml
status: built
carries: [Sources/CrawlCall/Bot]
requirements: [FR-BOT-010, FR-BOT-020, FR-BOT-530, FR-BOT-540, FR-BOT-550, FR-BOT-560, FR-BOT-570, FR-BOT-030, FR-BOT-040, FR-BOT-050, FR-BOT-060, FR-BOT-080, FR-BOT-440, FR-BOT-450, FR-BOT-460, FR-BOT-470, FR-BOT-480, FR-BOT-490, FR-BOT-500, FR-BOT-510, FR-BOT-520, INV-BOT-040, FR-BOT-090, FR-BOT-110, FR-BOT-115, FR-BOT-116, FR-BOT-118, FR-BOT-119, FR-BOT-150, FR-BOT-160, FR-BOT-165, FR-BOT-167, FR-BOT-170, FR-BOT-200, FR-BOT-210, FR-BOT-140, FR-BOT-220, FR-BOT-230, FR-BOT-240, FR-BOT-250, FR-BOT-260, FR-BOT-270, FR-BOT-280, FR-BOT-290, FR-BOT-300, FR-BOT-310, FR-BOT-320, FR-BOT-330, FR-BOT-340, FR-BOT-350, FR-BOT-360, FR-BOT-370, FR-BOT-380, FR-BOT-400, FR-BOT-405, FR-BOT-410, FR-BOT-420, FR-BOT-425, FR-BOT-430, INV-BOT-010, INV-BOT-020, INV-BOT-030, FR-BOT-120, FR-BOT-130, FR-BOT-180, FR-BOT-190, FR-SCORE-070, FR-SCORE-080, FR-SCORE-090, FR-SCORE-100, FR-SCORE-125, FR-SCORE-130]
depends_on: [E-020, E-040]
interface: a world, where the snake is and a frame's time in; squads that see, decide, walk and fire out — entered by `Archetype`, `Arms`, `Awareness`, `Blast`, `Bot`, `Execution`, `Flight`, `Interrupts`, `Perception`, `Round`, `Slots`, `Squads`
protects: [INV-BOT-010, INV-BOT-020, INV-BOT-030]
units: [crawlcall]
```

Everything a bot is: the kinds there are, who is on the map at the whistle, what each of them knows, what it decides and what it then does.

**Rationale.** One part rather than a perception part, a decision part and a movement part, because the three are one loop and the seams between them would be crossed every frame: what a bot knows is what it decides on, and what it decided is what it walks. Splitting them would mean three files agreeing about the same bot every step.
It is separate from the match (E-070) for the opposite reason: the match owns the snake, the clock and the order of a frame, and a squad that reached into those would decide when the world moves. What crosses the boundary is a world, the snake's whereabouts and a frame's time in; squads, their decisions, the rounds they sent and what those struck of the snake out.
It leans on the configuration contract for the numbers an archetype is made of (IF-BOT-010) and on the map layer for the graph it walks and the geometry it sees through; it knows nothing about what any of it looks like.
It also reads `World` from start-up, the upward dependency E-070 and E-100 share with it (Q-530).

### E-080 — The runners

```yaml
status: built
carries: [scripts, Tests/CrawlCallTests/TestSupport.swift]
requirements: [FR-TOOL-190, FR-TOOL-180, FR-TOOL-210, FR-TOOL-220, FR-TOOL-250, FR-TOOL-280]
depends_on: []
interface: a simulator or a device identifier in; each phase's time, its verdict, a named timeout, and an app that is not left running out
protects: [FR-TOOL-180]
```

Runs this project's own software the way the project says to run it: the suite on a simulator booted by identifier, with the build and the run as separate phases each ended by its own report or by a watchdog; and a build on a device, installed, launched, looked at and closed again.

**Rationale.** A part rather than a habit because the knowledge in it was expensive: that phases must be timed apart, that a phase ends when its log says so and not when `xcodebuild` exits, and that ending one means ending the tree it started. Each of those was learned from a stall that cost minutes, and each would be lost the moment somebody typed the single `test` command from memory.
It depends on nothing in the game: it drives the build system and the device from outside, and the game does not know it exists.
The device run belongs beside the test run rather than in a part of its own, because the expensive knowledge is the same knowledge: a run is addressed by identifier and never by name, it ends by the verb meant for ending it, and it confirms what it did instead of assuming it (`specs/50-verification.md`). Two parts would mean two places to learn that, and the second one would learn it later.
Neither runner carries an identifier of its own — the simulator arrives as an argument and the device as an environment variable — which is what lets the part be published as it stands. For the simulator that is convenience; for the device it is the maintainer's standing rule that no device identifier enters the repository, which no requirement states.
It also carries the helpers the suite reaches into collections with (FR-TOOL-280): they are part of how a test run ends — with a count and the names of what failed, never with a crash — which is this part's knowledge too.

### E-110 — Start-up

```yaml
status: built
carries: [Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Launch.swift]
requirements: [FR-VIEW-210, FR-VIEW-220, FR-VIEW-230]
depends_on: [E-020, E-030, E-040, E-050, E-070, E-100, E-120]
interface: a bundle and the name of a map in; the world a match runs in, and the window it is played in, out — entered by `Launch`
units: [crawlcall]
```

Stands the game up: reads what the world is made of, builds it once, and puts the window the match is played in on the screen.

**Rationale.** Split out of E-020 on 2026-10-10 (ADR-0071), which until then was called *Start-up and configuration* and did both.
The two are not one responsibility: reading a file and refusing a wrong shape is a contract the whole game reads numbers through, while standing the game up is the one place that knows what the pieces are and how they are joined. Keeping them together was what made a part everything depends on depend on six others — the configuration part declared no dependencies and in fact reached into the input schemes, the map, the view, the match and the surroundings, all of it from `CrawlCallApp.swift` and `Launch.swift`.
Apart, E-020 reaches nothing: it is the only leaf in the cut, which is what a contract everybody reads should be.

`World` — what a match is given to run in — is declared here, in `Launch.swift`, and read by the match, the squads and the surroundings; those three dependencies run back into this part and are three of the disagreements Q-530 holds.

### E-140 — The repository's guards

```yaml
status: built
carries: [scripts/arch-edges.py, scripts/arch-edges-selftest.sh, .githooks/pre-commit, .github/workflows/srs.yml]
requirements: [FR-TOOL-330, FR-TOOL-340, FR-TOOL-140, CON-PUB-020, CON-PUB-030, CON-PUB-040, CON-PUB-050, CON-PUB-060, CON-PUB-070, CON-PUB-090, CON-PUB-100]
depends_on: []
interface: a repository in; the references its parts have, and a refusal where a commit or a push would leave a generated file stale, out — entered by `arch-edges.py`
protects: [FR-TOOL-340]
```

Keeps the repository honest about itself: produces the references between the parts from the code, and refuses a commit or a push that would leave a file the project generates differing from what the code says.

**Rationale.** Separate from the runners (E-080) because the two face opposite ways: a runner drives the project's software from outside and reports what it did, while a guard reads the repository and refuses a change to it. The knowledge in each is different too — a runner knows that a phase ends when its log says so, a guard knows what the model of the parts is derived from — and a part holding both would have no sentence of its own.
It is the home the layer has been missing: on 2026-10-10 `ATTRIBUTION.md` was left with the map layer "for want of a better home rather than by right", and the twelve publication constraints (CON-PUB-010 through CON-PUB-120) name no file at all while the files that keep them — `LICENSE`, `.gitignore`, `Signing.example.xcconfig`, the Xcode project — are carried by nobody. Those join this part as their obligations are built, not before: a part is not filled with files to look complete.
It leans on nothing. The generator reads the sources and the layer's own records and imports nothing but the standard library (ART-040), which is what lets a guard run in a checkout with nothing installed.
The runners keep `scripts` as a directory; the two files here are claimed by the more specific path, which is how a part inside another owns what it names (`srs-dd/arch.md`).

### E-120 — The screens

```yaml
status: built
carries: [Sources/CrawlCall/View/ChoicePlate.swift, Sources/CrawlCall/View/Controls.swift, Sources/CrawlCall/View/FreeCameraControls.swift, Sources/CrawlCall/View/GameHostingController.swift, Sources/CrawlCall/View/MatchEnd.swift, Sources/CrawlCall/View/SeeThroughSwitches.swift, Sources/CrawlCall/View/MatchHost.swift]
requirements: [FR-VIEW-120, FR-VIEW-160, FR-VIEW-190, FR-VIEW-200]
depends_on: [E-020, E-030, E-050, E-070]
interface: a match and the window it is played in, in; the thumbs, the readings and the words the player is given, out — entered by `ChoicePlate`, `Controls`, `GameHostingController`, `MatchEnd`, `MatchHost`, `SeeThroughSwitches`
protects: [FR-VIEW-200]
units: [crawlcall]
```

What the player touches and reads: the stick and the buttons, the plate a choice is made on, the words a finished match is announced with, the debug mode's switches, and the bridge that hands the window's news to the match on screen.

**Rationale.** Split from the view on 2026-10-11 (ADR-0073) because the two answer different questions and change for different reasons: the view changes when the game's look does, the screens when what the player is asked to do does, and a part holding both invited a camera decision to be made while editing a button.
The split is also what the cut needed: the screens are what drives a match — a press restarts it, a switch changes what it draws, the window's orientation lock pauses it — and while they sat in the view, that driving ran upward against the order, since the match stands above the view and must not be reached into from below. In a group of their own above the match it is no longer a crossing but the ordinary direction: the screens hold the match, the match holds the drawing.
It answers for the words and the readings rather than for the pictures: FR-VIEW-200 and FR-VIEW-120 are realized nowhere outside these files but in the configuration types that name their strings and numbers, FR-VIEW-160 is a button that must say what it can do, and FR-VIEW-190 was claimed by both the view and the match until this split settled it — the match owns the two ends of a game (FR-SCORE-140, FR-SCORE-150), and the screen that announces one and offers another is this part.
It leans on the match for what to show, on the input contract for the intents a thumb makes, on the view for the scene it hosts, and on the configuration contract for the strings and the geometry of a control.
`MatchHost.swift` is not a screen but the bridge the window hands the match, and it belongs here for the same reason the screens do: what only the window knows — the orientation lock, the widest frame this device can give — is not the view's business.

### E-150 — The commanders

```yaml
status: proposed
carries: [Sources/CrawlCall/Commander, config/commander.json]
requirements: [FR-CMD-010, FR-CMD-020, FR-CMD-025, FR-CMD-027, FR-CMD-030, FR-CMD-040, FR-CMD-070, FR-CMD-080, FR-CMD-090, FR-CMD-100, FR-CMD-105, FR-CMD-110, FR-CMD-120, FR-CMD-125, FR-CMD-130, FR-CMD-140, FR-CMD-150, FR-CMD-160, FR-CMD-165, IF-CMD-010, IF-CMD-020, IF-CMD-030, IF-CMD-040, IF-CMD-050, IF-CMD-060, CON-CMD-010, CON-CMD-020, CON-PUB-080, NFR-PERF-030, NFR-PERF-040, NFR-PERF-055, NFR-PERF-060, NFR-PERF-070, NFR-PERF-080]
depends_on: [E-020, E-090]
interface: what a squad knows, on an interval, in; a threat priority, an order, roles, personality weights, a truce offer and a line to speak out — never a frame of execution
protects: [CON-CMD-020, NFR-PERF-030]
units: [crawlcall]
```

The language model's half of the game: once every interval each squad's commander is told what its squad knows, and answers with what the squad should want — whom to fear, where to go, who holds which role, how its bots lean, whether to offer the other squad a truce — and with what its bots say out loud.

**Rationale.** Designed on 2026-10-11 and not built (ADR-0073). It is designed before the code because this is the largest unbuilt piece of the system and the one whose boundary is hardest to recover once crossed: ADR-0003 fixes that the model never drives per-frame execution, and a part that answered a call *during* a frame would break NFR-PERF-030 in a way no test would name as the cause.
Three readings say it is one part and not a share of the squads. The specification's own links: the group seeded by FR-CMD-020 holds 34 requirements with 65 links inside it and 9 leaving — the most cohesive and least coupled group the links suggest of the eleven (`srs_arch.py --price proposed`). The interval: everything here happens between frames and may fail, arrive late or be refused (CON-CMD-020), while the squads must act on every frame whatever happened — two different clocks in one part would mean the slower one waiting for the faster.
And the direction: a commander writes what a squad wants and never reads a frame, so it stands above the squads and the squads need not know it exists. That is why it sits between the match, which ticks it, and the squads, which it writes into.
It leans on the squads for what a squad is and what it knows, and on the configuration contract for the instructions, the ceilings and the pre-written lines (IF-CMD-030, IF-CMD-040, IF-CMD-050).
It answers for the speech requirements as well as the orders, because both are generations through one surface with one content filter (FR-CMD-160, CON-PUB-080) and a second part speaking to the model would be a second place to get the refusals, the ceilings and the thermal fallback right.
The prompt bench (E-010) stays outside it and must keep running without the game: it is what keeps a prompt change honest (FR-TOOL-170), and a part that generated lines at run time would absorb it if nobody said so.
What it is *not*: it does not hold the interval's clock, which is the match's (E-070), and it does not hold what a bot does with an order, which is the squads'.
