# ADR-0071 — The architecture layer describes the cut the code has, and the configuration part stops standing the game up

- **Status:** accepted
- **Date:** 2026-10-10
- **Related requirements:** FR-VIEW-210, FR-VIEW-220, FR-VIEW-230, FR-VIEW-180, IF-BOT-010

## Context and problem statement

The architecture layer was written on 2026-09-25 and had not been closed with the code since: of the 266 requirements the specification holds, 21 that are `implemented` or `partial` belonged to no part, two parts still carried FR-VIEW-180 after it was superseded, and `config/bot.json` and `config/tuning.json` were named by requirements and owned by nobody — 29 warnings in all.
Worse than the staleness, the declared dependencies were a guess that nothing had ever checked: the checker reads imports in Python and nothing else, this project is Swift and Metal, and `arch/edges.json` did not exist, so `srs_arch.py` said in as many words that the model had been compared with nothing.
Five of the eleven `depends_on` lists turned out to be wrong once something did compare them, and one part — *Start-up and configuration*, which every other part reads numbers through — declared no dependencies while in fact reaching into the input schemes, the map layer, the view, the match and the surroundings.

## Considered options

For what a part carries:

1. Keep `requirements` written by hand and close it with the code, as the specification's own fields are closed.
2. Set `requirements: derived` in `arch/arch-config.json` and let the checker compute what a part carries from the `code` fields of the files it owns.

For the configuration part:

1. Split it: the contract that reads and validates the files stays E-020, and standing the game up becomes a part of its own.
2. Leave it whole and declare the six dependencies it really has.

For the dependency model:

1. Supply `arch/edges.json` — one reference between two files for every pair of parts the code joins — and set `depends_on` to what it shows.
2. Leave the model unchecked and keep it as a statement of intent.

## Decision outcome

**Written requirements, option 1.** `derived` was tried first and rejected on what it produced: a `code` field names every file a requirement is realized in, the configuration types are read almost everywhere, and the projection had E-020 answering for 85 requirements — among them how the snake moves and what the water looks like. The hand-written list is a judgement about which part answers for an obligation, and that judgement is the layer's content; the derivation is a join over the specification's fields, which the traceability matrix already is.
Its cost is the staleness this ADR is repairing, so the layer's own introduction now says the list is closed with the code, in the same set of edits as the `code` and `tests` fields.

**The split, option 1.** *Start-up and configuration* was two sentences, and the second one was what made a leaf depend on six other parts: `CrawlCallApp.swift` and `Launch.swift` build the world and put the window on screen, which is the one place that knows what the pieces are and how they are joined. They are now E-110 — Start-up, and E-020 — The configuration contract reaches nothing at all, which is the one leaf in the cut and what a contract the whole game reads through should be.
FR-VIEW-210, FR-VIEW-220 and FR-VIEW-230 — the window on an iPad, its orientation and what a change of the lock does — moved from the view to start-up with the files that realize them.

**The edges, option 1.** Without them the layer's second half is decoration: a declared model nothing contradicts reads as a model that agrees with the code.

### How it works

**The reference graph.** The edges were computed by one rule, written down here so that the file can be produced again: a type declared at the top level of a Swift file in `Sources/` is that file's name; a mention of such a name in another file, outside a string literal and outside a comment, and not a type that file declares itself, is a reference; a reference between two files owned by different parts is an edge. Nested types are excluded, because another file cannot name one without naming its container first. The rule found 1 307 references in 35 pairs of parts, against the 11 edges the records declared.
`arch/edges.json` holds one witness per pair rather than all 268 file pairs: the checker resolves each end to its part, so one real reference per pair is enough for the comparison, and a file of 35 entries is one a person can keep. Each `via` says which symbol and line the witness is, and how many references the pair has, so the output names the weight of the edge and not only its existence.
Nothing holds the file against the code — the checker cannot regenerate what it did not compute — so it is as stale as any hand-written record; FR-TOOL-330 is offered in Q-530 for a generator in the repository.

**What a part is entered by.** `interface` was prose about what crosses a boundary. It now also names what another part may enter the part by, so the reader of a record learns where the doors are. The rule `interface-bypassed` is priced `report` rather than `warn`: for a project whose edges are file paths, the checker compares `interface` against the full path, so satisfying it would make the field a second copy of `carries` and lose the sentence that says what the boundary is for.

**What a part was cut to keep.** `protects` was filled where the rationale already named it — the configuration contracts for E-020, the four intents for E-030, the graph covering every walkable cell for E-040, the head staying on walkable surfaces for E-060, the two ends of a match and intents-only for E-070, the three bot invariants for E-090, scenery never reaching into play for E-100, and a run that ends for E-080.

**Where the files live.** E-020 carries the six configuration files that are tuning, named one by one rather than as `config`: the directory would have made `config/kit` and `config/setting` parts inside the configuration part, which the map and the surroundings are not. E-040 carries `maps` rather than one map file, so the fixture the suite runs on belongs to the part that owns the format.

### Consequences

The cut has thirteen cycles in it, and they are reported now because the model finally says what the code does. They come from nine references that run against the order the parts imply: `World` declared in start-up and read by three parts below it, the map layer building view entities and asking the surroundings for the island's edge, the SwiftUI screens in the view reaching into the match, the snake reading the squads and the surroundings, and the surroundings reading the view. Each is a code change, each is written in Q-530 with what it would take, and none is made here: this decision is about describing the system, and a redraw of a working game is the maintainer's to agree.
What remains checkable is now checked: a new dependency between parts shows up as `dependency-undeclared` the next time the edges are produced, a requirement that reaches `implemented` without being given a part shows up as `requirement-uncarried`, and a part entered by a door its record does not name is reported.
