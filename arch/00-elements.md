# Elements

`E-NNN` — the parts this system is made of.

Each record names what the part is responsible for, the files it is made of, and — unless the project derives them from those files — the requirements it carries.
The join points one way: an element names its requirements, and a requirement never names an element.

Cut the parts as coarsely as the system allows.
An element per module says nothing the file tree did not; an element per boundary somebody could cross without noticing is what this layer is for.

The format is in `arch/README.md`.

### E-010 — The prompt bench

```yaml
status: built
carries: [Sources/PromptBench/PromptBench.swift, Sources/PromptBench/PromptVariants.swift, Sources/PromptBench/main.swift, Sources/PromptBench/BenchReport.swift]
requirements: [FR-TOOL-150, FR-TOOL-160]
depends_on: []
interface: a command line — variants and repeats in, one summary line per configuration out, optionally a CSV
```

Calls the system language model with a given set of instructions, schema and world states, and reports what came back: blocked calls, tokens, latency and the text of every line.

**Rationale.** The first part of this system to exist, and a boundary worth naming even while it is the only one: it is the only code that talks to the model outside the game, it runs on the Mac rather than the device, and it ships with the repository rather than with the app.
It is also what keeps a prompt change honest (FR-TOOL-170), so a later part that generates lines at run time must not absorb it — the bench has to stay runnable without the game.

### E-020 — Start-up and configuration

```yaml
status: built
carries: [Sources/CrawlCall/Config, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/CrawlCallApp.swift]
requirements: [IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, FR-TOOL-200]
depends_on: []
interface: a bundle in, one `Configurations` value or one named error out
```

Reads every configuration file once when the game starts, refuses a file whose shape is wrong, and hands the rest of the game one value holding the tuning.

**Rationale.** A boundary worth naming because everything downstream reads numbers through it and nothing downstream should read a file: a part that opens `config/` on its own would bypass the shape check that makes a typo an error (ADR-0012), and the mistake would look like a wrong number rather than a broken file.
The app's entry point belongs here rather than in a shell of its own — starting the game *is* the read, which is what four interface requirements say in their trigger.

### E-030 — The input contract

```yaml
status: built
carries: [Sources/CrawlCall/Input]
requirements: [IF-VIEW-010, FR-VIEW-050]
depends_on: []
interface: four intents, and nothing else crosses into the game logic
```

The intents the input schemes produce and the game logic consumes.

**Rationale.** Separate from start-up because it is the other place a boundary can be crossed quietly: a scheme that reached past the intents into the logic, or logic that read a touch event, would leave the abstraction intact on paper and gone in fact (FR-VIEW-030).
One file today, and the element is what keeps the fifth intent a change to IF-VIEW-010 rather than an addition somebody makes in passing.

### E-040 — The map layer

```yaml
status: built
carries: [Sources/CrawlCall/Map, maps/blockout.map, config/kit, ATTRIBUTION.md]
requirements: [IF-MAP-010, FR-TOOL-010, FR-TOOL-020, FR-TOOL-030, FR-MAP-010, FR-MAP-020, FR-MAP-100, FR-MAP-090, FR-MAP-150, FR-MAP-160]
depends_on: [E-020]
interface: a map file and its kit in; the placements, the navigation graph and the scene geometry out
```

Turns one text file into the two models the game runs on: what the bots path over and what the player sees, and answers the one question both of them ask of the geometry afterwards — what stands in the way of a straight line between two points (ADR-0019).

**Rationale.** The boundary that matters here is between the two models, and it is kept by making them one part rather than two: the graph and the geometry are derived from the same parse, in the same place, so a bot cannot path over a cell where no floor was placed.
Splitting parsing from geometry would look tidier and would let exactly that drift in, which is the failure the spike's navigation mesh made expensive (ADR-0016).
The line test sits here for the same reason and not in the view: the picture the player reads and the bots' eyes have to agree about what a wall is, and a part that owned the geometry but not the question asked of it would be a part with two answers waiting to happen. What the rule is, and the divergence standing in it, are ADR-0019; the requirements it serves stay with the parts that own them — FR-VIEW-150 and FR-VIEW-155 with E-050, FR-BOT-050 with E-090.
It depends on start-up because the cell size it measures in is tuning (IF-MAP-020), read by E-020.
`ATTRIBUTION.md` sits here for want of a better home rather than by right: it is a repository-wide document, and today the only requirement that reads it is FR-MAP-100's "a kit listed in the attribution file". When CON-PUB-030 has third-party assets to list, the file belongs to whatever owns the repository's guards, and this line moves with it.

### E-050 — The view

```yaml
status: built
carries: [Sources/CrawlCall/View]
requirements: [FR-VIEW-010, FR-VIEW-130, FR-VIEW-020, FR-VIEW-060, FR-VIEW-070, FR-TOOL-070, FR-VIEW-100, FR-VIEW-120, FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, FR-VIEW-160, FR-VIEW-170, FR-VIEW-180, FR-VIEW-190, FR-VIEW-200, IF-VIEW-030, FR-VIEW-210, FR-VIEW-220, FR-VIEW-230, FR-TOOL-260, FR-TOOL-270]
depends_on: [E-040]
interface: a scene plan in; the camera it is seen through and the light it is read by, out
```

Decides how the arena reaches the player: one camera at a fixed pitch, one daylight source with the ambient that keeps shadows readable, the looks a map module has — solid; faded whole while it is a floor over the snake; or cut open where a line of sight to the snake goes through it, or around the head (ADR-0020) — the figures the bots are drawn as (ADR-0022), the free camera of debug mode (ADR-0023), and the controls the player's thumbs land on.

**Rationale.** Split from the map layer because the two answer different questions and change for different reasons: the map changes when a level does, the view when the game's look does, and a file holding both invites a camera decision to be made while editing geometry.
The boundary is also where the specification puts it — the VIEW area owns the angle and the light, the MAP and TOOL areas own what is placed and where.

### E-100 — The surroundings

```yaml
status: built
carries: [Sources/CrawlCall/Setting, config/setting]
requirements: [FR-MAP-120, FR-MAP-130, FR-MAP-140, IF-GREENHOLM-010, FR-GREENHOLM-010, FR-GREENHOLM-020, FR-GREENHOLM-030]
depends_on: [E-020, E-040]
interface: the setting a map names and the arena's plan in; the scenery around the arena, the sky and the birds out
```

Draws the world the arena stands in: loads the setting the map names, finds how much ground the match camera can show, lays the setting's parts over it — for Greenholm the island, its ring of trees and shrubs, the water and the sky — and flies the birds (ADR-0031).

**Rationale.** Its own part because the one thing it must never do is reach into play (FR-MAP-130): the map layer's pieces are what the snake collides with, what the bots see and what is cut open, and a part that could add to them would put scenery into all three without anybody deciding it. Kept apart, it reads the plan and never writes it.
It depends on the map layer for the arena's plan and on start-up for the view configuration the coverage is computed from; the view does not depend on it, and the match view only adds what it builds to the scene.

### E-060 — The snake

```yaml
status: built
carries: [Sources/CrawlCall/Snake]
requirements: [FR-SNAKE-010, FR-SNAKE-015, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-060, FR-SNAKE-070, FR-SNAKE-090, FR-SNAKE-100, FR-SNAKE-210, FR-SNAKE-220, FR-MAP-025]
depends_on: [E-040]
interface: a held direction and a frame's time in; a head, a floor and a trail out
```

Where the snake is and where it has been: the head's movement over walkable surfaces with its body kept out of what stands on them, the slide along what it cannot pass, the drop it may take, the trail the tail is read from, and the meal that holds it still while the tail grows.

**Rationale.** A part of its own because it is the one place that decides whether a move is allowed, and the game will grow several callers of that decision — eating holds the head still, abilities move it differently, a bot's shot shortens the tail. A rule about passing through walls that lived in each of them would be a rule in none.
It leans on the map layer for what is walkable and for the boxes of what is not, and on nothing else: the snake asks the graph and the scene plan, it does not read the map file, and it has no idea how any of it is drawn (ADR-0021).

### E-070 — The match

```yaml
status: built
carries: [Sources/CrawlCall/Game.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Record]
requirements: [FR-VIEW-030, FR-VIEW-170, FR-VIEW-180, FR-VIEW-190, FR-SCORE-140, FR-SCORE-150, FR-TOOL-230, FR-TOOL-240]
depends_on: [E-020, E-060, E-050]
interface: intents in, a frame advanced, the scene and the camera moved to follow
```

What runs while a match is on: the intents the player sends, the world advanced once per frame, and the drawing brought up to date afterwards — and the two ends that stop all of it.

**Rationale.** This is the boundary FR-VIEW-030 draws — intents in, never touches or keys — and it is worth a part of its own so that the rule has somewhere to live rather than being a habit of whoever writes the next input scheme.
It is also the only part that knows the order of a frame: the world moves first and the picture follows, never the other way round, which is what keeps the camera from chasing a head that has not moved yet.
Whether a match is still on belongs here for the same reason: the two ends (FR-SCORE-140, FR-SCORE-150) are read off the snake and the bots but are a fact about the match, and a part that asked the snake whether the game was over would be the beginning of two answers.

### E-090 — The squads

```yaml
status: built
carries: [Sources/CrawlCall/Bot]
requirements: [FR-BOT-010, FR-BOT-020, FR-BOT-030, FR-BOT-050, FR-BOT-060, FR-BOT-080, FR-BOT-090, FR-BOT-118, FR-BOT-150, FR-BOT-160, FR-BOT-165, FR-BOT-200, FR-BOT-210, FR-VIEW-170, INV-BOT-010, INV-BOT-030]
depends_on: [E-020, E-040]
interface: a world, where the snake is and a frame's time in; squads that see, decide, walk and fire out
```

Everything a bot is: the kinds there are, who is on the map at the whistle, what each of them knows, what it decides and what it then does.

**Rationale.** One part rather than a perception part, a decision part and a movement part, because the three are one loop and the seams between them would be crossed every frame: what a bot knows is what it decides on, and what it decided is what it walks. Splitting them would mean three files agreeing about the same bot every step.
It is separate from the match (E-070) for the opposite reason: the match owns the snake, the clock and the order of a frame, and a squad that reached into those would decide when the world moves. What crosses the boundary is a world, the snake's whereabouts and a frame's time in; squads, their decisions and the damage they dealt out.
It leans on start-up for the numbers an archetype is made of (IF-BOT-010) and on the map layer for the graph it walks and the geometry it sees through; it knows nothing about what any of it looks like.

### E-080 — The runners

```yaml
status: built
carries: [scripts]
requirements: [FR-TOOL-190, FR-TOOL-180, FR-TOOL-210, FR-TOOL-220, FR-TOOL-250]
depends_on: []
interface: a simulator or a device identifier in; each phase's time, its verdict, a named timeout, and an app that is not left running out
```

Runs this project's own software the way the project says to run it: the suite on a simulator booted by identifier, with the build and the run as separate phases each ended by its own report or by a watchdog; and a build on a device, installed, launched, looked at and closed again.

**Rationale.** A part rather than a habit because the knowledge in it was expensive: that phases must be timed apart, that a phase ends when its log says so and not when `xcodebuild` exits, and that ending one means ending the tree it started. Each of those was learned from a stall that cost minutes, and each would be lost the moment somebody typed the single `test` command from memory.
It depends on nothing in the game: it drives the build system and the device from outside, and the game does not know it exists.
The device run belongs beside the test run rather than in a part of its own, because the expensive knowledge is the same knowledge: a run is addressed by identifier and never by name, it ends by the verb meant for ending it, and it confirms what it did instead of assuming it (`specs/50-verification.md`). Two parts would mean two places to learn that, and the second one would learn it later.
Neither runner carries an identifier of its own — the simulator arrives as an argument and the device as an environment variable — which is what lets the part be published as it stands. For the simulator that is convenience; for the device it is the maintainer's standing rule that no device identifier enters the repository, which no requirement states.
