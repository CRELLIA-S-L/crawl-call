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
