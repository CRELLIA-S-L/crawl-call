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
code: [Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Config/MapFormat.swift]
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
code: [Sources/CrawlCall/Map/ScenePlan.swift, Sources/CrawlCall/Map/SceneBuilder.swift, Sources/CrawlCall/Config/EntityName.swift, Sources/CrawlCall/Config/MapFormat.swift, Sources/CrawlCall/Config/Geometry.swift, Sources/CrawlCall/Map/Kit.swift]
tests: [Tests/CrawlCallTests/ScenePlanTests.swift, Tests/CrawlCallTests/MapParserTests.swift, Tests/CrawlCallTests/LaunchTests.swift]
created: 2026-09-21
```

When given a parsed map, the map tool **shall** assemble the scene by placing the kit's module for each cell at the coordinates the specification gives it, and, under every cell whose module is not walkable, the floor module the kit names for that module as well.

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
code: [Sources/CrawlCall/Map/NavigationGraph.swift, Sources/CrawlCall/Config/MapFormat.swift]
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
status: implemented
verification: D
derives_from: []
depends_on: [FR-VIEW-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/FreeCamera.swift, Sources/CrawlCall/View/FreeCameraControls.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Config/DebugText.swift, Sources/CrawlCall/Config/SymbolName.swift, Sources/CrawlCall/Config/Interface.swift]
tests: [Tests/CrawlCallTests/FreeCameraTests.swift]
created: 2026-09-21
```

Where debug mode is enabled, the system **shall** let the user detach the camera from the snake and move it freely.

**Rationale.** Concept §11.3: an external viewer cannot answer "does the tail fit", "where does it catch"; the debug build can.
One requirement per debug facility because each can be built and used without the others.
Debug mode is the Debug build configuration; the camera is zoomed by a pinch, panned by a two-finger drag, turned by a two-finger twist and tilted by a three-finger drag, within the limits of the view configuration, and put back on the snake by a button; ADR-0023 says why.

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

### FR-TOOL-260 — Debug mode tints what the see-through cuts by what cut it

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-VIEW-150, FR-VIEW-155]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SeeThrough.swift, Sources/CrawlCall/View/SeeThroughSwitches.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Config/Interface.swift, Sources/CrawlCall/Config/DebugText.swift]
tests: [Tests/CrawlCallTests/SeeThroughTests.swift]
created: 2026-09-25
```

Where debug mode is enabled and the user switches the tint on, the system **shall** tint each module the see-through cuts open by what cut it: the line of sight to the snake, the window around the head, or both.

**Rationale.** The maintainer, 2026-09-25: the see-through opens walls and crates beside the head that hide nothing (Q-260), and two cuts can do that — the line of sight of FR-VIEW-150 and the window of FR-VIEW-155 — so the phone has to show which one did before either is changed.
A switch and not always on, because debug mode is the build the maintainer plays (ADR-0023), and a tinted arena is not one to play in.

### FR-TOOL-270 — Debug mode switches each see-through cut off

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-VIEW-150, FR-VIEW-155]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/View/SeeThrough.swift, Sources/CrawlCall/View/SeeThroughSwitches.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Config/Interface.swift, Sources/CrawlCall/Config/DebugText.swift]
tests: [Tests/CrawlCallTests/SeeThroughTests.swift, Tests/CrawlCallTests/WindowTests.swift]
created: 2026-09-25
```

Where debug mode is enabled, the system **shall** let the user switch off the cut along the line of sight and the cut around the head, each on its own.

**Rationale.** The maintainer, 2026-09-25, beside FR-TOOL-260: with one cut off, what is still open is the other's alone, which says as plainly as the tint which cut opens what (Q-260).
The switches exist in debug mode only (ADR-0023). A match starts with the cut along the line of sight and, since the maintainer found the window to be what over-cut, without the window around the head (FR-VIEW-155), which a switch here turns back on to compare.

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
The three renders are in the repository; the scripts that made them are not.
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
code: [Sources/PromptBench/PromptBench.swift, Sources/PromptBench/main.swift, Sources/PromptBench/BenchReport.swift]
tests: [Tests/PromptBenchTests/main.swift, scripts/prompt-bench-selftest.sh]
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
code: [Sources/PromptBench/PromptBench.swift, Sources/PromptBench/PromptVariants.swift, Sources/PromptBench/BenchReport.swift]
tests: [Tests/PromptBenchTests/main.swift, scripts/prompt-bench-selftest.sh]
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
status: implemented
verification: T
derives_from: []
depends_on: [NFR-PERF-010, NFR-PERF-050]
refines: []
conflicts_with: []
code: [scripts/run-on-device.sh]
tests: [scripts/run-on-device-selftest.sh]
created: 2026-09-22
```

When an unattended run ends, whether it finished its route or stopped early, the run tool **shall** terminate on the device the app it launched before it reports.

**Rationale.** The next measurement is the reason, not tidiness: NFR-PERF-010 asks for 60 frames per second *cold*, and the thermal requirements are read against a device that started cool (NFR-PERF-050), so an app left rendering in the background puts the following run somewhere in the middle of its own thermal curve and produces a number nobody can reproduce (`specs/50-verification.md`).
The spike's own instrument is the evidence that this does not happen by itself: `materials/spike/instrument/run-autopilot.sh` terminates any *previous* instance when it launches, and never terminates the one it started — not on the path that succeeds, and not on the two paths that abort, which are the runs most likely to be left behind.
"Before it reports" rather than "afterwards" because a report is where a run ends for whoever reads it, and a step after the report is a step that gets skipped.
Built as a trap on the way out and not as a last line, because "stopped early" is the half that matters: a failed capture, an interrupted run or a device that went away are exactly the paths a last line never reaches, and they are the runs that leave the app rendering.
The device is named to the tool by the environment and never written into it, so that closing a run is one command and the tool is the same tool on anybody's desk. That a device identifier stays out of the repository is the maintainer's standing rule and not a requirement: CON-PUB-040 is about signing identifiers and CON-PUB-060 about secrets, and neither reaches a device.

### FR-TOOL-190 — A phase that stops making progress is killed and reported

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [scripts/run-tests.sh]
tests: [scripts/run-tests-selftest.sh]
created: 2026-09-22
```

When a phase of a test run has reported its result, or has outlived the time the run allows it, the test runner **shall** end that phase — and where the time ran out, report which phase it was, how long it was given, and what the process was doing.

**Rationale.** Three runs on 2026-09-22 sat for minutes — nine, four and four — with no output and no processor in use, and each was noticed by a person watching a clock rather than by the tools. The fourth was caught by this requirement's own code, and it named what none of the others could: the suite had finished and printed its verdict, and `xcodebuild` was hanging afterwards. Hence the first half of the statement — a phase ends when it has said what it came to say, not when its process decides to leave. A watchdog turns that from a wait into a finding, which is what `specs/50-verification.md` asks of a run whose time is wrong.
Killing is the easy half; the report is the point. "The tests phase gave up after 150s, the process was blocked at 0% CPU, and its last output was …" is where the next investigation starts, and it is exactly what nobody had during those three stalls.
The limit belongs to the caller rather than to the script, because a clean build and an incremental one are not the same wait, and a machine slower than this one is not wrong.
Its test takes the watchdog out of the runner rather than restating it, so a copy that drifted from what ships would prove nothing: the self-test reads `watch()` out of `run-tests.sh`, gives it a command that finishes and one that does not, and checks the timeout code, the report's three facts, and that the stuck command is actually gone.

### FR-TOOL-210 — A test run says how it ended, whatever the ending

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-TOOL-190]
refines: []
conflicts_with: []
code: [scripts/run-tests.sh]
tests: [scripts/run-tests-selftest.sh]
created: 2026-09-24
```

When a test run ends — its build failed, its tests failed, it passed, or its watchdog cut it short — the test runner **shall** print the build's errors where the build failed, otherwise the number of tests executed with the number that failed and the name of every failed test, and exit with a status that is zero only where every test executed and passed.

**Rationale.** On 2026-09-24 two runs with failing tests printed nothing but their phase times: the runner stops at the first command that fails, and the lines that print the result come after it. The failures had to be dug out of `tests.log`. A failed build said even less — only that it had failed, and not what.
The run is also ended on the suite's own last line, `Test Suite 'All tests' passed` or `failed`: when tests fail, `xcodebuild` has been seen printing that line and its counts and then hanging without the `** TEST FAILED` verdict, and the watchdog then killed a run that had already said everything.
The exit status is read from what the run printed, not from the process that printed it, because that process is the one known to hang after its verdict (FR-TOOL-190).
The maintainer asked for the runner to be fixed on 2026-09-24.

### FR-TOOL-220 — A test run lists the build's warnings

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-TOOL-210]
refines: []
conflicts_with: []
code: [scripts/run-tests.sh]
tests: [scripts/run-tests-selftest.sh]
created: 2026-09-24
```

When a test run's build succeeds, the test runner **shall** print every warning the build reported about the project's own files and settings, and how many there were.

**Rationale.** ART-080 asks a build to report no warning, and a warning nobody sees is not cleared: the two this build carried on 2026-09-24 were found by reading its log by hand, and one of them hid a test that could not fail for the reason it states.
Printed and not failed — the maintainer's choice on 2026-09-24 over failing the build on a warning, which would stop all work the day a new SDK deprecates something.
The project's own files and settings, because the build also prints notices of Xcode's own tools about frameworks the project does not use; those are named in `specs/91-open-issues.md` under ART-080 rather than repeated on every run.

## Diagnostics

### FR-TOOL-200 — An error or a log line opens with the identifier of its kind

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/ErrorIdentifier.swift, Sources/CrawlCall/Config/Schema.swift, Sources/CrawlCall/Config/Configurations+Load.swift, Sources/CrawlCall/Map/Kit.swift, Sources/CrawlCall/Map/MapSpecification.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/View/SceneView.swift, Sources/CrawlCall/Setting/Setting.swift, Sources/CrawlCall/Setting/SceneryBuilder.swift, Sources/CrawlCall/Setting/FrameCoverage.swift]
tests: [Tests/CrawlCallTests/ErrorIdentifierTests.swift]
exempt: [unlinked]
created: 2026-09-24
```

When the game reports an error or writes a log line, the system **shall** open the line with the identifier of its kind — upper-case words joined by underscores, unique across the game — followed by a colon, a space and the message.

**Rationale.** The maintainer asked on 2026-09-24 for errors to be sorted by kind, each kind with an identifier, and for every line to open with it: `MAP_REPEATED_KIT: line 4 names the kit a second time`.
An identifier is what a search, a filter or a test holds on to when the wording of a message changes; a message alone has to be matched by its words, and its words are the part most likely to be improved.
Unique across the game, because an identifier two kinds share would send a search to the wrong one.
The identifiers are declared once, in the catalogue ART-070 places under `Sources/CrawlCall/Config/`.
Exempt from `unlinked`: the format serves every error the game reports rather than one requirement, and a link to any single one would say otherwise.

## Frame record

The game's own instrument for where a frame's time goes, asked for by Q-250 and built first of its parts on 2026-09-24, when the freezes behind a long snake had been found by measurement on the simulator and one was still seen on the phone that no measurement placed.

### FR-TOOL-230 — A match records its frames when asked

```yaml
status: implemented
verification: T
derives_from: [NFR-PERF-010]
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Record/FrameRecord.swift, Sources/CrawlCall/Record/FrameRecorder.swift, Sources/CrawlCall/Config/FrameRecording.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/Game.swift, Sources/CrawlCall/View/SeeThrough.swift, Sources/CrawlCall/View/MatchHost.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/FrameRecordTests.swift]
created: 2026-09-24
```

When the game is launched with the frame record switched on, the system **shall** record for every frame the interval since the previous frame, the time its own step took in each of its phases — the match's step, the bots' deliberation, the see-through and the update of what is drawn — and the events of the match in that frame.

**Rationale.** A freeze the HUD shows is a spike with no name. The interval is what RealityKit measured between its frames; the phases are what this game spent of it. A long interval over short phases puts the time in the renderer or on the GPU — a shader compiled on first use, a material swapped on many modules at once — where moving the game's work to another thread would change nothing; a long phase puts it in the game. The events say what happened in the frame the time went: a match beginning or ending, a bot's deliberation, a meal beginning or ending — the tail grows as it ends — a hit on the snake, a module cut open for the first time, a module changing its look.
Switched on by the launch rather than built in, so that the build measured is the build played, Debug or Release alike; and kept in memory of a fixed size, so that recording costs no allocation on a frame and cannot itself be the spike it looks for.
The maintainer asked for the instrument on 2026-09-24, to decide by measurement whether the match's work should move off the main thread; on its first reading it stays (ADR-0030).

### FR-TOOL-240 — The frame record is written where the run tool can take it

```yaml
status: implemented
verification: T
derives_from: [FR-TOOL-230]
depends_on: [FR-TOOL-230]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Record/FrameRecorder.swift, Sources/CrawlCall/Record/TerminationRecord.swift, Sources/CrawlCall/Record/FrameRecord.swift, Sources/CrawlCall/Config/FrameRecording.swift, Sources/CrawlCall/GameSession.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/FrameRecordTests.swift]
created: 2026-09-24
```

When a match with the frame record switched on ends, when the app leaves the foreground, or when it is asked to terminate, the system **shall** write the record as a CSV file in the app's documents container.

**Rationale.** Written at those moments and not per frame, because a write is exactly the kind of work that stalls one. When it is asked to terminate, because that is how a run on the device ends (FR-TOOL-180): the run tool sends SIGTERM, and a process that dies of it leaves nothing behind. A signal dispatch source only reports the arrival of a signal and "cannot catch signals to prevent termination" (Apple, *Concurrency Programming Guide*), so the default action is set aside with `signal(SIGTERM, SIG_IGN)` while the record is switched on, and the app ends itself once the file is written.
The documents container is where `devicectl device copy from --domain-type appDataContainer` reaches.

### FR-TOOL-250 — A run on the device reports its slowest frames

```yaml
status: implemented
verification: T
derives_from: [FR-TOOL-230]
depends_on: [FR-TOOL-240]
refines: []
conflicts_with: []
code: [scripts/run-on-device.sh]
tests: [scripts/run-on-device-selftest.sh]
created: 2026-09-24
```

When a run on the device ends, the run tool **shall** copy the frame record from the device where there is one, and print the number of frames, how many came more than one and a half frame periods of 60 per second after the one before, and for each of the slowest frames its interval, its phases and its events.

**Rationale.** The record is read where the run is, so that a freeze is named the minute it was seen rather than after somebody opens a spreadsheet.
Late is one and a half frame periods at 60 per second, 25 ms: a frame of 16.67 ms is on time at NFR-PERF-010's rate, and a frame that came after a skipped one is at least 33 ms, so the line between them falls where no on-time frame reaches and every skipped one does. "More than 16.6 ms", as first drafted, would have called every frame late.

### FR-TOOL-280 — The test suite holds nothing that would crash it

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-TOOL-210]
refines: []
conflicts_with: []
code: [Tests/CrawlCallTests/TestSupport.swift]
tests: [Tests/CrawlCallTests/TestHygieneTests.swift]
created: 2026-09-25
```

If the test suite's own code holds a `try!`, an `as!`, a forced unwrap or a subscript by a number, the test suite **shall** fail, naming the file and the line.

**Rationale.** The maintainer, 2026-09-25: a test that fails reports a failure, never a crash (`specs/50-verification.md`). A crash of the test process ends the run, not the test — on 2026-09-25 one ended a run at its watchdog's limit with no count and no name for the failed test, and brought up macOS's offer to report it to Apple. Those four are how the suite's own code ends the process where a value is not there; the suite reaches into collections through helpers that fail the test instead. Checked by the suite itself, so that the rule holds without anybody having to remember it.
