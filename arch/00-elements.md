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
carries: [Sources/PromptBench/PromptBench.swift, Sources/PromptBench/PromptVariants.swift, Sources/PromptBench/main.swift]
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
requirements: [IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010]
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
requirements: [IF-VIEW-010]
depends_on: []
interface: four intents, and nothing else crosses into the game logic
```

The intents the input schemes produce and the game logic consumes.

**Rationale.** Separate from start-up because it is the other place a boundary can be crossed quietly: a scheme that reached past the intents into the logic, or logic that read a touch event, would leave the abstraction intact on paper and gone in fact (FR-VIEW-030).
One file today, and the element is what keeps the fifth intent a change to IF-VIEW-010 rather than an addition somebody makes in passing.

### E-040 — The map layer

```yaml
status: built
carries: [Sources/CrawlCall/Map, maps/blockout.map, ATTRIBUTION.md]
requirements: [IF-MAP-010, FR-TOOL-010, FR-TOOL-020, FR-TOOL-030, FR-MAP-010, FR-MAP-020, FR-MAP-100]
depends_on: [E-020]
interface: a map file and its kit in; the placements, the navigation graph and the scene geometry out
```

Turns one text file into the two models the game runs on: what the bots path over and what the player sees.

**Rationale.** The boundary that matters here is between the two models, and it is kept by making them one part rather than two: the graph and the geometry are derived from the same parse, in the same place, so a bot cannot path over a cell where no floor was placed.
Splitting parsing from geometry would look tidier and would let exactly that drift in, which is the failure the spike's navigation mesh made expensive (ADR-0016).
It depends on start-up because the cell size it measures in is tuning (IF-MAP-020), read by E-020.
`ATTRIBUTION.md` sits here for want of a better home rather than by right: it is a repository-wide document, and today the only requirement that reads it is FR-MAP-100's "a kit listed in the attribution file". When CON-PUB-030 has third-party assets to list, the file belongs to whatever owns the repository's guards, and this line moves with it.

### E-050 — The view

```yaml
status: built
carries: [Sources/CrawlCall/View]
requirements: [FR-VIEW-010, FR-VIEW-130]
depends_on: [E-040]
interface: a scene plan in; the camera it is seen through and the light it is read by, out
```

Decides how the arena reaches the player: one camera at a fixed pitch, one daylight source with the ambient that keeps shadows readable.

**Rationale.** Split from the map layer because the two answer different questions and change for different reasons: the map changes when a level does, the view when the game's look does, and a file holding both invites a camera decision to be made while editing geometry.
The boundary is also where the specification puts it — the VIEW area owns the angle and the light, the MAP and TOOL areas own what is placed and where.
