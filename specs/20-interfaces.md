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
code: [Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift, Sources/CrawlCall/Config/Schema.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Config/Resource.swift]
tests: [Tests/CrawlCallTests/ConfigurationTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/SchemaTests.swift]
created: 2026-09-21
```

When the game starts, the system **shall** read from the snake configuration — the JSON file `config/snake.json` (ADR-0012) — the base speed; the starting segment count; segments gained per archetype consumed; segments regrown by the medic ability; damage per segment; the body eating duration; the eating damage per second; the lunge's reach, wind-up, speed and angle (FR-SNAKE-270); the coil's time, and the shove's reach and speed (FR-SNAKE-280); the turning radius (FR-SNAKE-290); the number of segments that are the neck (FR-SNAKE-055); the distance ahead the head feels (FR-SNAKE-016); and per ability its speed, factor, amount or duration as FR-SNAKE-130 to FR-SNAKE-190 name them.

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
code: [Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift, Sources/CrawlCall/Config/Schema.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Config/Resource.swift]
tests: [Tests/CrawlCallTests/ConfigurationTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/SchemaTests.swift]
created: 2026-09-21
```

When the game starts, the system **shall** read from the tuning configuration — the JSON file `config/tuning.json` (ADR-0012) — the damage thresholds of each module type per state; the destruction damage of each bot weapon and its destruction ammunition; the destruction damage of the snake's body per segment of length; the trap width, trap length and tail-gap tolerance; the maximum drop height and the gravity the snake falls under off a ledge (FR-SNAKE-220); the navigation-graph cell size; and the step height, slope angle and body radius that FR-MAP-025 makes common to the snake and the bots.

**Rationale.** Concept §7: strength thresholds by module type, damage by source, the destroying weapons' ammunition, the snake's weight — all in a separate config, tuned experimentally; the risk it guards against is a map turned to wasteland by mid-match.

### IF-SCORE-010 — Scoring configuration

```yaml
status: partial
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift]
tests: [Tests/CrawlCallTests/AwarenessTests.swift]
created: 2026-09-21
```

When the game starts, the system **shall** read from the scoring configuration — the JSON file `config/scoring.json` (ADR-0012) — the body and live-prey base values; the stealth multipliers for open, hidden and perfect; the balance multiplier; the target-value multipliers for commander, heavy and medic; the witness window, the late-arrival window, the report delay and the inspection distance.

**Rationale.** Concept §6: the axes are the design; their weights are tuning.
`partial` because only the witness window, the late-arrival window, the report delay and the inspection distance are read: the values and multipliers wait for the scoring they set (FR-SCORE-010).

### IF-BOT-010 — Bot and match configuration

```yaml
status: partial
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift, Sources/CrawlCall/Config/Schema.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Config/Resource.swift]
tests: [Tests/CrawlCallTests/ConfigurationTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/SchemaTests.swift, Tests/CrawlCallTests/DeliberationTests.swift, Tests/CrawlCallTests/KnowledgeTests.swift]
created: 2026-09-21
```

When the game starts, the system **shall** read from the bot configuration — `config/bot.json` (ADR-0012) — per archetype its base personality weights, their allowed ranges, run speed, maximum health, detection range and the arms it carries — which primary weapon, which sidearm, which grenade and how many of them, and which knife (FR-BOT-440); from a catalogue of weapons, each firearm's damage, range, time between shots and magazine size (FR-BOT-450), each grenade's throw range, fuse time, blast radius and the share every further part of the snake within that blast adds (FR-BOT-470, FR-BOT-480, FR-BOT-490), and each knife's reach, throw range and damage (FR-BOT-510, FR-BOT-520); the override, interrupt, grouping and order distances; the hysteresis margin; the deliberation period and per-frame slot maximum; the collapse panic increment; the fear of an unhurt bot; the weight of each term in an action's score (FR-BOT-080); the height a bot's figure is drawn at and the height of its eyes; the speed a bot turns at (FR-BOT-280), its acceleration (FR-BOT-290) and the angle of its field of view (FR-BOT-050); how often a bot with nothing to do looks round (FR-BOT-380); the speed a round flies at and how far it flies (FR-BOT-060, FR-BOT-405), and the speed a bot firing with no cover beside it moves at and how often it turns back (FR-BOT-430); the times after which a bot forgets a sighting of the snake and one of an enemy (FR-BOT-260), and each squad's share delay (FR-BOT-310); and from the match configuration — `config/match.json` — the squad size, the archetypes eligible for the commander role, the commander interval, the truce switch and truce-break threshold, the state token budget and the maximum response tokens, and the thermal degradation threshold and factor — the threshold `serious` by default.

**Rationale.** Concept §8 (base weights), §9.2 (thresholds, scheduling), §14 (squad size), §15 (degradation).
The degradation threshold defaults to `serious` on the spike's measurement (ADR-0001): a twenty-minute run on the iPhone 16 Pro reached `fair` at fourteen minutes and never `serious`, holding 60 fps and a 2.7 s mean commander latency throughout — so `fair` as the threshold would stretch the intervals of a session that was losing nothing, while `serious` is the first state the spike never reached and therefore the first whose cost is unmeasured.
The figure's height and the eyes' are two numbers and not one because they answer to different things — how big a bot looks and where it sees from — and the shipped numbers put the second on the eyes the figure is drawn with (ADR-0022).
The factor has no default yet (Q-180).
Two files named in one requirement because they are read in the same act at the same moment; splitting the keys across two requirements would give a reader two places to look for one thing.
A weapon's damage, range and magazine left the archetype on 2026-10-11, when a bot came to carry four weapons and the numbers stopped being the bot's (FR-BOT-450, ADR-0075); what stays on the archetype is what belongs to the body — how fast it runs, how much of it there is and how far it sees.
`partial` from that day: the build reads every key above but the arms and the catalogue, and a bot still has one unnamed weapon whose damage and magazine are its archetype's.

## Commander I/O

### IF-CMD-010 — Commander input

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-SCORE-130]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/CommanderInput.swift, Sources/CrawlCall/Commander/SquadView.swift, Sources/CrawlCall/Commander/SquadHappenings.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/CommanderContractTests.swift]
created: 2026-09-21
```

When calling a commander, the system **shall** pass a structured world state from that squad's point of view carrying: its bots' positions, health, ammunition and roles; what the squad knows of the enemy; the squad's awareness state; the snake's last known position where awareness is not *calm*; the squad's current order and the commander's previous decision; any pending truce proposal; and the events since the previous call — the whole state within the state token budget of the match configuration, 1000 tokens by default, and written in the vocabulary IF-CMD-060 allows.

**Rationale.** Concept §9.1: a compressed state from its own point of view — own positions, what is known of the enemy, where the snake is, what is happening.
"From its own point of view" is the whole design: the commander is never told what it has not seen.
The token budget follows from CON-CMD-010: eight soldiers, the snake, the awareness state and the previous decision measured 583 tokens with the instructions in the spike.
The vocabulary is not a matter of taste: the state is the model's input and is checked by the same guardrail as the instructions.
Measured (ADR-0017): the same situation written as wounds and bodies was blocked in 10 of 10 calls, and in the game's own words in 0 of 10; a line the model did return echoed the state's vocabulary back — "I'm bleeding — also, why is this snake doing interpretive dance?"
Built on 2026-10-11 (ADR-0077): three bands for what is left of a soldier, two for a pouch, a quarter of the arena for where it stands, and the bench's own six names — every word of it read from the role-holder's knowledge and none from the arena.
`partial` until there is a call to pass it to (FR-CMD-020).
Measured the same day with the shipped instructions: 12 calls on the game's own states, none blocked, 624 to 679 input tokens, while the control was blocked 12 times in 12.
`partial` for a few hours on 2026-10-12, the events being the one clause nothing built, and `implemented` the same day (ADR-0083): a commander is told what its own soldiers reacted to — who went down, who took a hit, whose pouch ran out, whether the snake came near, and who saw it take one of ours — each said once, in the measured words, and spent by the call that carries it.
Nothing new is perceived for it: the five are the interrupts the frame already finds for the bots themselves (FR-BOT-170), and a quiet call is still the five lines the bench measured.

### IF-CMD-020 — Commander output

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [IF-CMD-010]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Commander/CommanderDecision.swift, Sources/CrawlCall/Commander/SystemModelCommander.swift, Sources/CrawlCall/Commander/Commander.swift]
tests: [Tests/CrawlCallTests/CommanderContractTests.swift]
created: 2026-09-21
```

When a commander responds, the system **shall** accept only a structured response carrying: a threat priority from {enemy, snake, withdraw}; an order from {hold, flank, withdraw-to-zone, disperse, destroy-cover}; a role or none per bot; personality weights per bot; a truce action from {none, propose, accept, reject}; and, for a speech call, the speaker's name and one line of at most the line length of the speech configuration; rejecting any response that does not parse into this shape; every numeric field carrying its permitted range as a generation constraint.

**Rationale.** Concept §9.1: guided generation, structured, not free text.
Rejection rather than repair: an unparseable response is a missed cycle, which the squad survives; a repaired one is an order nobody gave.
The line's shape is part of the contract because the model, asked for one shout, returned six-speaker scenes of up to 235 characters (ADR-0017).
The ranges are constraints rather than descriptions because the measurement separated the two: dropping the prose saved 72 tokens a call and cost nothing, while dropping the range produced weights of 0.8 to 8.0 for a field documented as 0 to 1.
Built on 2026-10-11 (ADR-0077) as two types: the generated one, shaped for the generator, and the game's own, with the crossing between them the only place a response is accepted or rejected.
The crew is an array of one described soldier type rather than a field per soldier, so the schema costs what one soldier costs however many there are.
`partial` until there is a call to answer (FR-CMD-020).

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
code: [Sources/CrawlCall/Map/MapSpecification.swift, maps/blockout.map, Sources/CrawlCall/Config/Resource.swift, Sources/CrawlCall/Config/MapFormat.swift, config/kit/blockout/legend.json]
tests: [Tests/CrawlCallTests/MapParserTests.swift, Tests/CrawlCallTests/FlightTests.swift, Tests/CrawlCallTests/IslandMapTests.swift]
created: 2026-09-21
```

A map **shall** be described by one UTF-8 text file holding a header that names the module kit, the setting, the snake's spawn points and the transitions between floors, followed by one character grid per floor in which each cell names a module of the kit, by the kit's legend; a step of a flight of stairs, by an arrow pointing the way the flight rises; or empty space.

**Rationale.** Concept §11.2: "translated into a text specification — an ASCII grid per floor"; the map lives in a text file so that iterations are seconds and versions go into git.
Which characters mean which modules is the kit's own `legend.json` (ADR-0012), so that a map and its kit cannot disagree.
The setting is named in the header beside the kit, for the same reason the kit is (FR-MAP-120).
A step is an arrow and not a legend character because which way a flight rises is the map's to say, not the kit's; what a step is drawn as is the kit's (FR-MAP-150, ADR-0033). The `transition` line stays for a way that goes straight up — the ladder a tower may have one day (Q-330) — and no map uses it now.

## Settings

A setting's configuration is its own file under `config/setting/`, named as the setting is (ADR-0031), read when a map that stands in it is loaded; each setting's interface is in the area of its name.
The snake's spawn points joined the header on 2026-09-25, when the maintainer asked for the map to say where the snake is born (FR-MAP-180).

### IF-GREENHOLM-010 — Greenholm configuration

```yaml
status: implemented
verification: T
derives_from: [FR-GREENHOLM-010]
depends_on: [FR-MAP-120]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/GreenholmConfiguration.swift, Sources/CrawlCall/Map/Setting.swift, Sources/CrawlCall/Config/Resource.swift, Sources/CrawlCall/Launch.swift]
tests: [Tests/CrawlCallTests/SurroundingsTests.swift]
created: 2026-09-24
```

When a map whose setting is Greenholm is loaded, the system **shall** read from the Greenholm configuration — the JSON file `config/setting/greenholm.json` (ADR-0012) — how far the island's edge lies beyond the map's outline and the radius its hollows are rounded with (FR-MAP-200); the shore's width and drop and the water's drop below the grass; the colours of the grass, the shore and the water; how far beyond the shore the sea floor falls, how deep it falls, its colour there (FR-MAP-270), and the water's opacity (FR-MAP-280); the foam's width and colour (FR-GREENHOLM-050); how rough the water is and how strongly it reflects (FR-GREENHOLM-060); the longest waves' length, the waves' speed as a share of deep water's, their crest strength and steepness (FR-GREENHOLM-070); the sky's colour at the zenith and at the horizon (FR-GREENHOLM-020); and how often birds cross, how many fly together, how fast and how high above the arena, how large, how often they beat their wings and their colour (FR-GREENHOLM-030).

**Rationale.** Every number of what the island looks like is taste, settled by eye on the phone, and ART-070 keeps such numbers out of code.
One file per setting beside the others, not a section of the view configuration, so that a setting added later brings its own file and changes nobody else's; and read only when a map names the setting, because a map on another setting has no use for it.
A file with an unknown key is rejected as every configuration is (ADR-0012).
Rewritten on 2026-09-25, when the island came to follow the map (ADR-0034): the numbers of the ring of trees and shrubs went with the ring, since trees and shrubs are now the map's modules, and the edge's margin and rounding came in.

## Input

### IF-VIEW-010 — Input intents

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Input/Intent.swift, Sources/CrawlCall/Config/IntentName.swift]
tests: [Tests/CrawlCallTests/IntentTests.swift, Tests/CrawlCallTests/TouchSchemeTests.swift]
created: 2026-09-21
```

The input layer **shall** deliver to the game logic exactly these intents: a movement direction, an ability activation naming the segment, a pointed position on the map, a pause, and an intent to eat, which lunges at what is within reach (FR-SNAKE-270).

**Rationale.** Concept §3: the abstraction is laid down from day one; the schemes (FR-VIEW-040, FR-VIEW-050) produce these, the logic consumes them.
"Exactly these" is the contract — a scheme that needs another intent changes this requirement first, which is what eating did: the concept builds the whole economy of §6.2 on the choice between eating a body and leaving it, and a meal that began by itself whenever the head touched something would take that choice away.

### IF-VIEW-020 — View configuration

```yaml
status: implemented
verification: T
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift, Sources/CrawlCall/Config/Schema.swift, Sources/CrawlCall/Launch.swift, Sources/CrawlCall/CrawlCallApp.swift, Sources/CrawlCall/Config/Resource.swift, Sources/CrawlCall/View/SceneView.swift]
tests: [Tests/CrawlCallTests/ConfigurationTests.swift, Tests/CrawlCallTests/LaunchTests.swift, Tests/CrawlCallTests/SchemaTests.swift, Tests/CrawlCallTests/ViewConfigurationTests.swift]
created: 2026-09-21
```

When the game starts, the system **shall** read from the view configuration — the JSON file `config/view.json` (ADR-0012) — the camera pitch within the range FR-VIEW-010 allows; the camera's field of view, and how far back it stands in lengths of the map; the colour and brightness of the ambient light, and the sun's intensity, elevation and azimuth (FR-VIEW-130); the central region the head is kept in, and how long the camera takes to catch up with it (FR-VIEW-020); how far to either side the body sways and over how much ground a wave runs (FR-VIEW-330); the see-through margin of FR-VIEW-150; the visibility radius of FR-VIEW-155; the straggler distance; the visible-panic threshold; and how near and how far, and how low and how steep, the free camera of FR-TOOL-070 may be taken.

**Rationale.** Every VIEW requirement that names a number names it here; the camera pitch is a number the maintainer settles by eye (concept §12), inside the range the concept fixes.

## Text

### IF-VIEW-030 — String catalog

```yaml
status: implemented
verification: T
derives_from: [FR-VIEW-200]
depends_on: []
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Config/TextKey.swift, Sources/CrawlCall/View/Localizable.xcstrings]
tests: [Tests/CrawlCallTests/TextCatalogTests.swift]
created: 2026-09-24
```

The system **shall** take every text shown to the player from the string catalog `Localizable.xcstrings` (ADR-0024), by a key that names where the text appears — `matchEnd.snakeDied` — with English as the development language and every key translated for each language the game carries.

**Rationale.** A key that names the place rather than the English words stays the same when the words change, so a translation is not orphaned by an edit to the original, and the key is itself the name ART-070 asks every string in code to have.
Every key translated for each language the game carries, because a language with gaps shows its player English in the middle of their own; a key is only complete when every language has it.
Text shown only in the debug build is not shown to the player, and stays out of the catalog as a named constant.

## Model instructions

The instructions the game sends the on-device model are its own interface to it: their wording is tuning, what they must establish is a contract (ADR-0017).
Both requirements below are verified by inspecting the instructions in configuration against their list.

### IF-CMD-040 — Instructions for a commander's decision

```yaml
status: implemented
verification: I
derives_from: []
depends_on: [IF-CMD-020, CON-CMD-010]
refines: []
conflicts_with: []
code: [config/commander.json, Sources/CrawlCall/Config/Configurations.swift, Sources/CrawlCall/Config/Configurations+Load.swift]
tests: [Tests/CrawlCallTests/CommanderContractTests.swift]
created: 2026-09-22
```

The commander instructions **shall** establish: that the reader commands one squad in an arena where a rival squad and a snake are also present; that the answer is a decision and not prose; the meaning of each field of IF-CMD-020, including the range and effect of the personality weights; that nothing outside the squad's own knowledge may be assumed; and the content rules of IF-CMD-060.

**Rationale.** ADR-0017: the instructions are specified by what they must establish, not by their words.
The weights are the commander's only channel into behaviour (FR-CMD-060), so a reader that does not know what they do returns numbers that mean nothing.

Written on 2026-10-11 into `config/commander.json` rather than into the code, because a prompt that needs a rebuild to try is a prompt nobody measures and every change to it voids the bench's reading (FR-TOOL-170, ADR-0077).
It is about four and a half times the length of `v2-soft`, the variant the project's 0-blocks-in-100 reading belongs to, which establishes two of the five things above; the other three are what the length buys.
Measured the same day as `v5-game`, which reads this file rather than copying it: 12 calls on the game's own states with none blocked, against a control blocked 12 times in 12.
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
