# Functional requirements — tooling

The map pipeline from text to scene, the 2D plan, the in-build debug mode, the render scripts, the repository guards.
Source: concept §11.2 (method), §11.3 (viewers), §12 (division of labour), §2.1 (how visuals are produced), §17.4 (identifiers in the repository).
Tools are code like any other: each is a requirement with `code` and `tests` when built.

## Map pipeline

### FR-TOOL-010 — Parse a map specification

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [IF-MAP-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/MapSpecification.swift]
tests: [Tests/CrawlCallTests/MapParserTests.swift]
created: 2026-09-21
```

When given a map specification file, the map tool **shall** produce the placement of every module per floor, or reject the file naming the line and the reason.

**Rationale.** Concept §11.2: the map lives in a text file — iterations take seconds, versions go into git, the agent generates variants in batches.

### FR-TOOL-020 — Assemble the scene from the kit

```yaml
status: implemented
verification: T
derives_from: [FR-TOOL-010]
depends_on: [FR-MAP-100]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/ScenePlan.swift, Sources/CrawlCall/Map/SceneBuilder.swift]
tests: [Tests/CrawlCallTests/ScenePlanTests.swift, Tests/CrawlCallTests/MapParserTests.swift, Tests/CrawlCallTests/LaunchTests.swift]
created: 2026-09-21
```

When given a parsed map, the map tool **shall** assemble the scene by placing the kit's module for each cell at the coordinates the specification gives it, and, under every cell whose module is not walkable, the kit's floor module as well.

**Rationale on the implied floor.** A grid cell holds one module (IF-MAP-010), so a cell holding a wall holds no floor, and a scene built literally has a hole under every wall, crate and partition — measured on the device on 2026-09-22, where the pixels at the foot of a partition read `0, 0, 0` against a floor of `133, 140, 151`.
The floor is implied rather than written into each cell because a map is a drawing a person edits, and making them spell out the floor under every wall would be the kind of bookkeeping the text format exists to avoid (concept §11.2).
Deliberate holes are a different thing and are not this: FR-MAP-110 is where a cell says it has none, so that a hole is something a map states rather than something a wall causes by accident.

**Rationale.** Concept §12: assembling a map to an exact specification in coordinates is what the agent does reliably.

### FR-TOOL-030 — Derive the navigation graph

```yaml
status: implemented
verification: T
derives_from: [FR-TOOL-020]
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/NavigationGraph.swift]
tests: [Tests/CrawlCallTests/NavigationGraphTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/MapParserTests.swift]
created: 2026-09-21
```

When given a parsed map, the map tool **shall** derive the navigation graph from its grids and transitions, one node per walkable cell and floor.

**Rationale.** Concept §11.2 step 3, with the graph in place of the navmesh (ADR-0016): the grid the map is written in is the graph the bots walk.

### FR-TOOL-040 — Validate the map

```yaml
status: deferred
verification: T
derives_from: [FR-TOOL-030]
depends_on: [FR-MAP-010, FR-MAP-070, FR-MAP-080, FR-MAP-090]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When given a map and its navigation graph, the map tool **shall** report every floor unreachable from another, every disconnected region of the graph, every transition whose cells are not walkable at both ends, and every requirement of the MAP area the map fails to meet.

**Rationale.** Concept §11.2 step 3 (the validator), §11.3 (disconnected zones and seams).
One act — a report — over an enumerated set of findings.

### FR-TOOL-050 — Export to the level editor

```yaml
status: deferred
verification: T
derives_from: [FR-TOOL-020]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When asked, the map tool **shall** export the assembled scene in the format the level editor of ADR-0001 opens.

**Rationale.** Concept §12: export to RCP is on the agent's list; the editor is the stack's and follows the engine decision.

### FR-TOOL-060 — Render a 2D plan per floor

```yaml
status: deferred
verification: T
derives_from: [FR-TOOL-010]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When given a map specification, the plan tool **shall** render one image per floor showing walls, passages, stairs and the zones of visibility.

**Rationale.** Concept §11.3: the best value for effort early on — 3D checks that modules fit, the plan tells whether the map is any good.

## Debug mode

### FR-TOOL-070 — Free camera

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-VIEW-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Where debug mode is enabled, the system **shall** let the user detach the camera from the snake and move it freely.

**Rationale.** Concept §11.3: an external viewer cannot answer "does the tail fit", "where does it catch"; the debug build can.
One requirement per debug facility because each can be built and used without the others.

### FR-TOOL-080 — Navigation graph overlay

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-MAP-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Where debug mode is enabled, the system **shall** draw the navigation graph's walkable cells over the geometry on request, blocked cells marked.

**Rationale.** Concept §11.3.

### FR-TOOL-090 — Disconnected regions and seams highlighted

```yaml
status: deferred
verification: D
derives_from: [FR-TOOL-080]
depends_on: [FR-TOOL-040]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Where debug mode is enabled, the system **shall** highlight in the overlay every disconnected region of the graph and every broken transition the validator reported.

**Rationale.** Concept §11.3.

### FR-TOOL-100 — Teleport by pointing

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-SNAKE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Where debug mode is enabled, when the user points at a walkable cell, the system **shall** move the snake's head there.

**Rationale.** Concept §11.3.

### FR-TOOL-110 — Snake length slider

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-SNAKE-060]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Where debug mode is enabled, the system **shall** let the user set the snake's segment count directly.

**Rationale.** Concept §11.3: "which corridor becomes a trap at 15 segments" is answered by crawling it at 15 segments.

### FR-TOOL-120 — Bot sight lines drawn

```yaml
status: deferred
verification: D
derives_from: []
depends_on: [FR-BOT-050]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Where debug mode is enabled, the system **shall** draw each bot's current line of sight, coloured by whether it reaches the snake.

**Rationale.** Concept §11.3; also the only way to see witnessing (FR-SCORE-070) happen.

## Render scripts

### FR-TOOL-130 — Concept renders are built by script

```yaml
status: deferred
verification: I
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
exempt: [unlinked]
created: 2026-09-21
```

The repository **shall** hold, under `materials/render/`, the scripts that assemble the concept scene in Blender and render the concept images.

**Rationale.** Concept §2.1: the visual is assembled by script as a 3D scene, not drawn; the renders of §2.2 were made this way and the scripts stay the tool for concept renders and possibly for generating models.
The three renders are in the repository; the scripts that made them are not yet, which is why this is a draft.
Exempt from `unlinked`: the scripts serve the concept document, not another requirement, and a link invented to satisfy the rule would say otherwise.

## Repository guards

### FR-TOOL-140 — Pre-commit check for a Team ID in the project file

```yaml
status: deferred
verification: T
derives_from: [CON-PUB-050]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a commit stages the Xcode project file, the pre-commit hook **shall** reject the commit if the file contains a development team identifier.

**Rationale.** Concept §17.4: choosing a team in Xcode silently writes the Team ID into `project.pbxproj`, bypassing the config; the diff is checked before every commit — a job for the hook.

## Prompt tests

### FR-TOOL-150 — The prompt bench

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [IF-CMD-040, IF-CMD-050, IF-CMD-060, CON-CMD-020]
refines: []
conflicts_with: []
code: [Sources/PromptBench/PromptBench.swift, Sources/PromptBench/main.swift]
tests: []
created: 2026-09-22
```

When run over a set of instructions and a set of world states, the prompt bench **shall** report, per configuration, how many calls the model blocked, the input and output tokens, the latency, and the text of every line it returned.

**Rationale.** Apple asks for exactly this: "Create a list of potentially harmful prompt inputs that you can run as part of your app's tests… log the timestamp, full input prompt, the model's response, and whether it activates any built-in safety", and "When any model you use updates, it's important to re-run all of your prompt tests".
Without it the refusal rate is anecdote: the difference between 10 blocked in 100 and 0 in 100 (ADR-0017) is invisible in a ten-minute play session, which is how the first configuration shipped into the spike.
The bench calls the model directly and does not render, so a hundred calls take minutes on any machine that runs the model — the Mac included, which is where it is used.

### FR-TOOL-160 — The bench carries a control that must be blocked

```yaml
status: implemented
verification: T
derives_from: [FR-TOOL-150]
depends_on: []
refines: [FR-TOOL-150]
conflicts_with: []
code: [Sources/PromptBench/PromptBench.swift, Sources/PromptBench/PromptVariants.swift]
tests: []
created: 2026-09-22
```

The prompt bench **shall** report every run in which its deliberately blocked control was not blocked as void rather than as a measurement.

**Rationale.** A bench that cannot detect a block reports zero blocks for every configuration, which is the same reading as success.
The control used in the spike — a squad dying in described agony — was blocked in 50 of 50 calls while the game's own configurations were blocked in 0 (ADR-0017).

### FR-TOOL-170 — A bench measurement names the configuration it covers

```yaml
status: deferred
verification: T
derives_from: [FR-TOOL-150]
depends_on: [IF-CMD-010, IF-CMD-020, IF-CMD-040, IF-CMD-050, IF-CMD-060, CON-CMD-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

Every measurement the prompt bench records **shall** name the four things it was taken under — the instructions, the response schema, the vocabulary of the world state, and the model version — so that a configuration differing from the latest record in any of them is read as unmeasured until the bench has been run over it again.

**Rationale.** Safety is a property of the whole configuration, not of the instructions alone: the shortest instruction variant passed 150 calls with the shipping schema and was blocked 6 times in 100 with the previous one, every block on the same situation, while the shipping instructions were never blocked in either (ADR-0017).
The two axes also act independently — the same situation written as wounds and bodies was blocked 10 of 10 under the old instructions and 0 of 10 under the new ones — so a change to either invalidates the other's reading.
Apple asks for the same on the model axis: "When any model you use updates, it's important to re-run all of your prompt tests", and the system model ships with the OS rather than with the game (CON-CMD-020).
What the record obliges is a re-run before the change ships, and the cost of one is minutes on a Mac (FR-TOOL-150), which is what makes the rule affordable rather than aspirational.

### FR-TOOL-180 — An unattended run closes the app it started

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [NFR-PERF-010, NFR-PERF-050]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

When an unattended run ends, whether it finished its route or stopped early, the run tool **shall** terminate on the device the app it launched before it reports.

**Rationale.** The next measurement is the reason, not tidiness: NFR-PERF-010 asks for 60 frames per second *cold*, and the thermal requirements are read against a device that started cool (NFR-PERF-050), so an app left rendering in the background puts the following run somewhere in the middle of its own thermal curve and produces a number nobody can reproduce (`specs/50-verification.md`).
The spike's own instrument is the evidence that this does not happen by itself: `materials/spike/instrument/run-autopilot.sh` terminates any *previous* instance when it launches, and never terminates the one it started — not on the path that succeeds, and not on the two paths that abort, which are the runs most likely to be left behind.
"Before it reports" rather than "afterwards" because a report is where a run ends for whoever reads it, and a step after the report is a step that gets skipped.
