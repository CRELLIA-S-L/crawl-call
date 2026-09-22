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
