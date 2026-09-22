# §5. Interface requirements

`IF-*` — protocols, external APIs, storage schemas.
Same requirement format as everywhere; the subject is the interface contract, not the implementation behind it.

Source: concept §7 (parameters in a separate config), §9.1 (structured commander output), §11.2 (the map as a text file), §3 (the input abstraction).
Configurations are the concept's "numbers to be tuned experimentally": each is a file the game reads at start, so that tuning is a diff and not a rebuild.
The files are JSON, one per interface, and the map a text file with a grid per floor (ADR-0012); the requirements below fix what each carries.

## Configuration files

### IF-SNAKE-010 — Snake configuration

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

When the game starts, the system **shall** read from the snake configuration — the JSON file `config/snake.json` (ADR-0012) — the base speed; the starting segment count; segments gained per archetype consumed; segments regrown by the medic ability; damage per segment; the body and live-prey eating durations; and per ability its speed, factor, amount or duration as FR-SNAKE-130 to FR-SNAKE-190 name them.

**Rationale.** Concept §12: the final feel — snake speed, reaction distances, thresholds — stays with the human, and the agent takes corrections as numbers (§11.2).
One act — reading one file — over an enumerated set of keys.

### IF-MAP-020 — Tuning configuration for destruction and maps

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

When the game starts, the system **shall** read from the tuning configuration — the JSON file `config/tuning.json` (ADR-0012) — the damage thresholds of each module type per state; the destruction damage of each bot weapon and its destruction ammunition; the destruction damage of the snake's body per segment of length; the trap width, trap length and tail-gap tolerance; the maximum drop height; the navigation-graph cell size.

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

When the game starts, the system **shall** read from the bot configuration — `config/bot.json` (ADR-0012) — per archetype its base personality weights, their allowed ranges, run speed, weapon damage and detection range; the override, interrupt and grouping distances; the hysteresis margin; the deliberation period and per-frame slot maximum; the collapse panic increment; and from the match configuration — `config/match.json` — the squad size, the archetypes eligible for the commander role, the commander interval, the truce switch and truce-break threshold, and the thermal degradation threshold and factor.

**Rationale.** Concept §8 (base weights), §9.2 (thresholds, scheduling), §14 (squad size), §15 (degradation).
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

When calling a commander, the system **shall** pass a structured world state from that squad's point of view carrying: its bots' positions, health, ammunition and roles; what the squad knows of the enemy; the squad's awareness state; the snake's last known position where awareness is not *calm*; the squad's current order; any pending truce proposal; and the events since the previous call.

**Rationale.** Concept §9.1: a compressed state from its own point of view — own positions, what is known of the enemy, where the snake is, what is happening.
"From its own point of view" is the whole design: the commander is never told what it has not seen.

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

When a commander responds, the system **shall** accept only a structured response carrying: a threat priority from {enemy, snake, withdraw}; an order from {hold, flank, withdraw-to-zone, disperse, destroy-cover}; a role or none per bot; personality weights per bot; and a truce action from {none, propose, accept, reject}; rejecting any response that does not parse into this shape.

**Rationale.** Concept §9.1: guided generation, structured, not free text.
Rejection rather than repair: an unparseable response is a missed cycle, which the squad survives; a repaired one is an order nobody gave.

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

When the game starts, the system **shall** read from the speech configuration — the JSON file `config/speech.json` (ADR-0012) — the list of speech events, "order issued" among them; the rate cap and queue length; and the pre-written line set with at least one line per event.

**Rationale.** Concept §15: the frequency ceiling, the queue, the pre-generated set for degradation; FR-CMD-160 needs a fallback line for every event the filter can reject.

## Map format

### IF-MAP-010 — The map specification file

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

A map **shall** be described by one UTF-8 text file holding a header that names the module kit and the transitions between floors, followed by one character grid per floor in which each cell names a module of the kit, by the kit's legend, or empty space.

**Rationale.** Concept §11.2: "translated into a text specification — an ASCII grid per floor"; the map lives in a text file so that iterations are seconds and versions go into git.
Which characters mean which modules is the kit's own `legend.json` (ADR-0012), so that a map and its kit cannot disagree.

## Input

### IF-VIEW-010 — Input intents

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

The input layer **shall** deliver to the game logic exactly these intents: a movement direction, an ability activation naming the segment, a pointed position on the map, and a pause.

**Rationale.** Concept §3: the abstraction is laid down from day one; the schemes (FR-VIEW-040, FR-VIEW-050) produce these, the logic consumes them.
"Exactly these" is the contract — a scheme that needs a fifth intent changes this requirement first.

### IF-VIEW-020 — View configuration

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

When the game starts, the system **shall** read from the view configuration — the JSON file `config/view.json` (ADR-0012) — the camera pitch within the range FR-VIEW-010 allows; the central region the head is kept in; the straggler distance; and the visible-panic threshold.

**Rationale.** The three VIEW requirements that name a number name it here; the camera pitch is a number the maintainer settles by eye (concept §12), inside the range the concept fixes.
