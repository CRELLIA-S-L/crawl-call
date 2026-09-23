# §5. Interface requirements

`IF-*` — protocols, external APIs, storage schemas.
Same requirement format as everywhere; the subject is the interface contract, not the implementation behind it.

Source: concept §7 (parameters in a separate config), §9.1 (structured commander output), §11.2 (the map as a text file), §3 (the input abstraction).
Configurations are the concept's "numbers to be tuned experimentally": each is a file the game reads at start, so that tuning is a diff and not a rebuild.
The files are JSON, one per interface, and the map a text file with a grid per floor (ADR-0012); the requirements below fix what each carries.

## Configuration files

### IF-SNAKE-010 — Snake configuration

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift, Sources/CrawlCall/Config/Schema.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/ConfigurationTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/SchemaTests.swift]
created: 2026-09-21
```

When the game starts, the system **shall** read from the snake configuration — the JSON file `config/snake.json` (ADR-0012) — the base speed; the starting segment count; segments gained per archetype consumed; segments regrown by the medic ability; damage per segment; the body and live-prey eating durations; and per ability its speed, factor, amount or duration as FR-SNAKE-130 to FR-SNAKE-190 name them.

**Rationale.** Concept §12: the final feel — snake speed, reaction distances, thresholds — stays with the human, and the agent takes corrections as numbers (§11.2).
One act — reading one file — over an enumerated set of keys.

### IF-MAP-020 — Tuning configuration for destruction and maps

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift, Sources/CrawlCall/Config/Schema.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/ConfigurationTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/SchemaTests.swift]
created: 2026-09-21
```

When the game starts, the system **shall** read from the tuning configuration — the JSON file `config/tuning.json` (ADR-0012) — the damage thresholds of each module type per state; the destruction damage of each bot weapon and its destruction ammunition; the destruction damage of the snake's body per segment of length; the trap width, trap length and tail-gap tolerance; the maximum drop height; the navigation-graph cell size; and the step height, slope angle and body radius that FR-MAP-025 makes common to the snake and the bots.

**Rationale.** Concept §7: strength thresholds by module type, damage by source, the destroying weapons' ammunition, the snake's weight — all in a separate config, tuned experimentally; the risk it guards against is a map turned to wasteland by mid-match.

### IF-SCORE-010 — Scoring configuration

```yaml
status: deferred
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the game starts, the system **shall** read from the scoring configuration — the JSON file `config/scoring.json` (ADR-0012) — the body and live-prey base values; the stealth multipliers for open, hidden and perfect; the balance multiplier; the target-value multipliers for commander, heavy and medic; the witness window, the late-arrival window, the report delay and the inspection distance.

**Rationale.** Concept §6: the axes are the design; their weights are tuning.

### IF-BOT-010 — Bot and match configuration

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift, Sources/CrawlCall/Config/Schema.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/ConfigurationTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/SchemaTests.swift]
created: 2026-09-21
```

When the game starts, the system **shall** read from the bot configuration — `config/bot.json` (ADR-0012) — per archetype its base personality weights, their allowed ranges, run speed, weapon damage and detection range; the override, interrupt and grouping distances; the hysteresis margin; the deliberation period and per-frame slot maximum; the collapse panic increment; and from the match configuration — `config/match.json` — the squad size, the archetypes eligible for the commander role, the commander interval, the truce switch and truce-break threshold, the state token budget and the maximum response tokens, and the thermal degradation threshold and factor — the threshold `serious` by default.

**Rationale.** Concept §8 (base weights), §9.2 (thresholds, scheduling), §14 (squad size), §15 (degradation).
The degradation threshold defaults to `serious` on the spike's measurement (ADR-0001): a twenty-minute run on the iPhone 16 Pro reached `fair` at fourteen minutes and never `serious`, holding 60 fps and a 2.7 s mean commander latency throughout — so `fair` as the threshold would stretch the intervals of a session that was losing nothing, while `serious` is the first state the spike never reached and therefore the first whose cost is unmeasured.
The factor has no default yet (Q-180).
Two files named in one requirement because they are read in the same act at the same moment; splitting the keys across two requirements would give a reader two places to look for one thing.

## Commander I/O

### IF-CMD-010 — Commander input

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SCORE-130]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When calling a commander, the system **shall** pass a structured world state from that squad's point of view carrying: its bots' positions, health, ammunition and roles; what the squad knows of the enemy; the squad's awareness state; the snake's last known position where awareness is not *calm*; the squad's current order and the commander's previous decision; any pending truce proposal; and the events since the previous call — the whole state within the state token budget of the match configuration, 1000 tokens by default, and written in the vocabulary IF-CMD-060 allows.

**Rationale.** Concept §9.1: a compressed state from its own point of view — own positions, what is known of the enemy, where the snake is, what is happening.
"From its own point of view" is the whole design: the commander is never told what it has not seen.
The token budget follows from CON-CMD-010: eight soldiers, the snake, the awareness state and the previous decision measured 583 tokens with the instructions in the spike.
The vocabulary is not a matter of taste: the state is the model's input and is checked by the same guardrail as the instructions.
Measured (ADR-0017): the same situation written as wounds and bodies was blocked in 10 of 10 calls, and in the game's own words in 0 of 10; a line the model did return echoed the state's vocabulary back — "I'm bleeding — also, why is this snake doing interpretive dance?"

### IF-CMD-020 — Commander output

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [IF-CMD-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a commander responds, the system **shall** accept only a structured response carrying: a threat priority from {enemy, snake, withdraw}; an order from {hold, flank, withdraw-to-zone, disperse, destroy-cover}; a role or none per bot; personality weights per bot; a truce action from {none, propose, accept, reject}; and, for a speech call, the speaker's name and one line of at most the line length of the speech configuration; rejecting any response that does not parse into this shape; every numeric field carrying its permitted range as a generation constraint.

**Rationale.** Concept §9.1: guided generation, structured, not free text.
Rejection rather than repair: an unparseable response is a missed cycle, which the squad survives; a repaired one is an order nobody gave.
The line's shape is part of the contract because the model, asked for one shout, returned six-speaker scenes of up to 235 characters (ADR-0017).
The ranges are constraints rather than descriptions because the measurement separated the two: dropping the prose saved 72 tokens a call and cost nothing, while dropping the range produced weights of 0.8 to 8.0 for a field documented as 0 to 1.

### IF-CMD-030 — Speech configuration

```yaml
status: deferred
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the game starts, the system **shall** read from the speech configuration — the JSON file `config/speech.json` (ADR-0012) — the list of speech events, "order issued" among them; the rate cap, queue length and line length; and the pre-written line set with at least one line per event and speaker.

**Rationale.** Concept §15: the frequency ceiling, the queue, the pre-generated set for degradation; FR-CMD-160 needs a fallback line for every event the filter can reject, and FR-CMD-165 for every call the model refuses — which the measured configuration did not do in a hundred bench calls or a twenty-minute session, while the game's first one did in one call in ten — the bound the game is built to survive is one in five (CON-CMD-020), so the set is the game's second voice and not a spare.

## Map format

### IF-MAP-010 — The map specification file

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Map/MapSpecification.swift]
tests: [Tests/CrawlCallTests/MapParserTests.swift]
created: 2026-09-21
```

A map **shall** be described by one UTF-8 text file holding a header that names the module kit and the transitions between floors, followed by one character grid per floor in which each cell names a module of the kit, by the kit's legend, or empty space.

**Rationale.** Concept §11.2: "translated into a text specification — an ASCII grid per floor"; the map lives in a text file so that iterations are seconds and versions go into git.
Which characters mean which modules is the kit's own `legend.json` (ADR-0012), so that a map and its kit cannot disagree.

## Input

### IF-VIEW-010 — Input intents

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Input/Intent.swift]
tests: [Tests/CrawlCallTests/IntentTests.swift, Tests/CrawlCallTests/TouchSchemeTests.swift]
created: 2026-09-21
```

The input layer **shall** deliver to the game logic exactly these intents: a movement direction, an ability activation naming the segment, a pointed position on the map, and a pause.

**Rationale.** Concept §3: the abstraction is laid down from day one; the schemes (FR-VIEW-040, FR-VIEW-050) produce these, the logic consumes them.
"Exactly these" is the contract — a scheme that needs a fifth intent changes this requirement first.

### IF-VIEW-020 — View configuration

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift, Sources/CrawlCall/Config/Schema.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/CrawlCallApp.swift]
tests: [Tests/CrawlCallTests/ConfigurationTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/SchemaTests.swift]
created: 2026-09-21
```

When the game starts, the system **shall** read from the view configuration — the JSON file `config/view.json` (ADR-0012) — the camera pitch within the range FR-VIEW-010 allows; the central region the head is kept in; the see-through margin of FR-VIEW-150; the straggler distance; and the visible-panic threshold.

**Rationale.** Every VIEW requirement that names a number names it here; the camera pitch is a number the maintainer settles by eye (concept §12), inside the range the concept fixes.

## Model instructions

The instructions the game sends the on-device model are its own interface to it: their wording is tuning, what they must establish is a contract (ADR-0017).
Both requirements below are verified by inspecting the instructions in configuration against their list.

### IF-CMD-040 — Instructions for a commander's decision

```yaml
status: deferred
verification: I
derives_from: []
depends_on: [IF-CMD-020, CON-CMD-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

The commander instructions **shall** establish: that the reader commands one squad in an arena where a rival squad and a snake are also present; that the answer is a decision and not prose; the meaning of each field of IF-CMD-020, including the range and effect of the personality weights; that nothing outside the squad's own knowledge may be assumed; and the content rules of IF-CMD-060.

**Rationale.** ADR-0017: the instructions are specified by what they must establish, not by their words.
The weights are the commander's only channel into behaviour (FR-CMD-060), so a reader that does not know what they do returns numbers that mean nothing.

### IF-CMD-050 — Instructions for a bot's line

```yaml
status: deferred
verification: I
derives_from: []
depends_on: [IF-CMD-060, FR-CMD-140]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

The speech instructions **shall** open with the writer's role in a cartoon game and permission to work in it, and then establish that the crew are named figures, that the answer is one short line somebody shouts in the shape IF-CMD-020 defines, and the content rules of IF-CMD-060.

**Rationale.** ADR-0017, measured: without the register the model produced sixty-three restatements of one tactical order with no names and no panic; with it, named soldiers blaming each other, which is what §1 says sells the game.
Naming the crew is what makes "IT ATE DAVIS" possible at all.
The role comes first because Apple's guidance says so — "the very beginning of an Instructions string is an effective place to give the model a clear role with permission to work in a domain" — and the measurement agrees: the instructions decide the outcome on their own, blocking a harmless situation 5 times in 5 in the control and none in the shipping text.
What the line reacts to is not in the instructions but in the state (IF-CMD-010), which changes every call; and the references of ADR-0002 are not named in the text, because naming them costs tokens and changed nothing.
Instructions are judged in the whole prompt they ship in, never on their own: a shorter text than the one in use passed 150 calls beside one schema and was blocked 6 times in 100 beside another.

### IF-CMD-060 — What a generated line may and may not contain

```yaml
status: deferred
verification: T
derives_from: [CON-PUB-080]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

A generated line **shall** be admissible only when it is one utterance of at most the line length of the speech configuration, spoken by a named soldier of the speaking squad, about what just happened — and contains none of: a slur against any group; sexual content; a real person, organisation, nation or conflict; an instruction for harm outside the game; profanity beyond what the 13+ rating of ADR-0014 admits; a wound, blood, a weapon by name, or a death described as a death rather than as a disappearance or a gulp.

**Rationale.** ADR-0017: one list, read by the instructions that ask for a line (IF-CMD-050) and by the filter that judges the one that came back (FR-CMD-160), because two lists drift apart.
The first five entries follow the rating (ADR-0014); the last is the comedy frame F-030 — and it is also what the model itself refuses over, so the instructions and the filter agree with the model's own limits instead of fighting them.
