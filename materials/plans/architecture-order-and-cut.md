# Architecture: a declared order, the cut the code should have, and parts for what is not built: handoff

A plan written on 2026-10-11 at the maintainer's request.

**Built the same day**, all five steps, with the maintainer's word on 2026-10-11 ("согласен со всем, делай всё"). What the work found that this plan did not is in ADR-0072 and ADR-0073, and where the two disagree, the ADRs win:

- **Step 0 was added** — FR-TOOL-330 and FR-TOOL-340: the references are produced from the code by `scripts/arch-edges.py` and a commit that leaves them stale is refused. The plan had this as its weakest joint and proposed a requirement; the maintainer said the tools for it were already here.
- **The screens split as written (E-120)**, and took two more obligations than the plan gave them: FR-VIEW-160 and FR-VIEW-190, the second of which the view and the match had both claimed since 2026-09-25.
- **The surroundings split the other way round.** The plan took the geometry down into a part of its own (E-130); measurement refused that twice, and the four files — the setting, the outline, the distance field and the rectangle of ground — belong to the map layer they are computed from. There is no E-130.
- **`World` went to the map layer, not to the match**: the squads and the scenery read it too, so it has to sit below all three.
- **Four changes to the code, not one**: `World` out of start-up, `SceneBuilder` into the view, the island's edge computed where the setting is, and a pose that stopped reaching into the match.
- **The result**: thirteen parts, 31 pairs of parts the code joins, no dependency against the declared order, no circle, `srs_arch.py` reporting no error and no warning, 692 tests passing after every change, and the build looked at on the phone.

What follows is the plan as it was written, kept because the measurements in it are what the work was judged against.
It is written so that an agent with no memory of the conversation can take it up; everything it needs is here or pointed to from here.

**Nothing here is approved.** The numbers `E-120` and `E-130` below are proposals — numbers the layer does not carry — and five decisions belong to the maintainer — they are gathered under *The decisions the maintainer owns*.
This file is not the specification and not the layer: `specs/` and `arch/` are, and a step that is agreed is written there, through `.claude/skills/srs-arch/SKILL.md`, with its decision record in `specs/adr/`.

Every number in this file was derived from the current tree on 2026-10-11 with the tools named beside it.
Re-derive rather than trust it: the commands are given so that the plan can be checked, not believed.

## Why this plan exists

The purpose of the architecture layer, in the maintainer's words on 2026-10-11, is to *propose* the optimal structure from the requirements and to hold it optimal as the requirements change.

What the layer does today is the other thing: it describes the structure the code has.
The work of 2026-10-10 (ADR-0070, ADR-0071) brought the description and the code into agreement — five of the eleven `depends_on` lists were wrong, and `arch/edges.json` now holds one witness for every pair of parts the code joins, so the model has something that can disagree with it.
That work was necessary and it was not this: where the code crossed a boundary, the crossing was written into the rationale and filed as Q-530 in `specs/91-open-issues.md`, rather than the cut being judged wrong and redrawn.
The project's own procedure reads a circle the other way — "the cut is wrong and two parts are one, or one edge is a dependency in name only" (`.claude/skills/srs-arch/SKILL.md`, *First things first*) — a finding to resolve, not a fact to record.

So the layer states what is, and nothing in the repository states what ought to be.
This plan is how the second half gets written down.

## What the layer offers for this, and what this project uses

Read from `srs-dd/arch.md` at 0.24.0, the version installed.

| What it is for | Where it is written | Used here today |
|---|---|---|
| `layers` — an order of groups; an edge against it is `dependency-upward`, reported in the declared model and in the code separately | `arch/arch-config.json` | no |
| `forbidden` — a pair no part may depend on, with the sentence its failure prints | `arch/arch-config.json` | no |
| `only` — an allow-list of who may reach a part | `arch/arch-config.json` | no |
| `forbidden_imports` — a module a part may not build with | `arch/arch-config.json` | no |
| `status: proposed` — a part designed and not yet built; its files need not exist, and it still answers for its obligations | `arch/00-elements.md` | no — no part is proposed |
| `--plan` — what moving to the designed parts costs | tool | no — "No part is designed and unbuilt, so there is nothing to move" |
| `--drivers` — the ten requirements a design is worked against | tool | not before the records were written |
| `--price proposed` — the cut the links themselves suggest, seeded by the drivers | tool | no |

`arch/arch-config.json` holds one line today, pricing `interface-bypassed` to `report`.

## How good the current cut is, measured

The eleven parts the layer holds, as `python3 srs-dd/tools/srs_arch.py --cite` prints them:

E-010 — The prompt bench (arch/00-elements.md, built)
E-020 — The configuration contract (arch/00-elements.md, built)
E-030 — The input contract (arch/00-elements.md, built)
E-040 — The map layer (arch/00-elements.md, built)
E-050 — The view (arch/00-elements.md, built)
E-060 — The snake (arch/00-elements.md, built)
E-070 — The match (arch/00-elements.md, built)
E-080 — The runners (arch/00-elements.md, built)
E-090 — The squads (arch/00-elements.md, built)
E-100 — The surroundings (arch/00-elements.md, built)
E-110 — Start-up (arch/00-elements.md, built)

`python3 srs-dd/tools/srs_arch.py --price parts` scores each by the links of the requirements it holds — both ends inside the part, then leaving it, then arriving:

| Part | Held | Inside | Out | In |
|---|---|---|---|---|
| E-090 | 53 | 94 | 24 | 33 |
| E-050 | 28 | 25 | **27** | 8 |
| E-060 | 19 | 38 | 15 | 39 |
| E-040 | 16 | 20 | 9 | 33 |
| E-100 | 13 | 16 | 10 | 7 |
| E-070 | 7 | 4 | 5 | 5 |
| E-020 | 6 | 0 | 0 | 48 |
| E-080 | 6 | 3 | 4 | 0 |
| E-110 | 3 | 2 | 3 | 1 |
| E-010 | 2 | 2 | 4 | 1 |
| E-030 | 2 | 1 | 2 | 6 |

E-020 is the shape a contract should have: nothing leaves it, 48 links arrive.
E-050 is the one part of the eleven whose links out (27) exceed the links inside it (25) — by this measure the badly cut part, and *Step 2* is about it, though not about this number: the re-cut there leaves it at 27 against 24, which is measured and discussed in that step.
E-090 is the opposite: 94 links inside against 24 out, which is why its own rationale refuses to split it into perception, decision and movement.

## Step 1 — declare the order

Write into `arch/arch-config.json`, exactly as it would be written:

```json
{
  "layers": [
    ["E-110"],
    ["E-070"],
    ["E-050", "E-100"],
    ["E-060", "E-090"],
    ["E-030", "E-040"],
    ["E-020"]
  ],
  "rules": {
    "interface-bypassed": "report"
  }
}
```

The list is read top down: the first group may lean on every other, the last on none.
E-010 and E-080 are deliberately in no group — the bench and the runners stand outside the game, and a part in no group is outside the order, which is how an order is adopted on a cut that already exists.
Within a group nothing is reported, which is what puts the view beside the surroundings and the snake beside the squads: neither pair will be separated by this plan.

**What it reports, run on 2026-10-11 against this exact file and then reverted:** 14 warnings, which are 7 pairs named twice each — once where an element declares the edge, once where the code has it:

| Pair | The code's witness |
|---|---|
| E-040 → E-050 | `Sources/CrawlCall/Map/SceneBuilder.swift` uses `Sources/CrawlCall/View/SeeThrough.swift` |
| E-040 → E-100 | `Sources/CrawlCall/Map/Passages.swift` uses `Sources/CrawlCall/Map/DistanceField.swift` |
| E-050 → E-070 | `Sources/CrawlCall/View/FreeCameraControls.swift` uses `Sources/CrawlCall/GameSession.swift` |
| E-060 → E-100 | `Sources/CrawlCall/Snake/Surfaces.swift` uses `Sources/CrawlCall/Map/DistanceField.swift` |
| E-070 → E-110 | `Sources/CrawlCall/Game.swift` uses `Sources/CrawlCall/Launch.swift` |
| E-090 → E-110 | `Sources/CrawlCall/Bot/Execution.swift` uses `Sources/CrawlCall/Launch.swift` |
| E-100 → E-110 | `Sources/CrawlCall/Setting/SceneryBuilder.swift` uses `Sources/CrawlCall/Launch.swift` |

The thirteen `element-cycle` warnings keep firing beside them, so the run goes from 13 warnings to 27.
All thirteen are derived from the same seven edges, and the order says it better: it names the two parts, which way the edge runs and the file it runs in.
The honest resolution is to price `element-cycle` to `report` for as long as this plan is in flight.
Pricing it `off` loses the reading that catches a circle the order does not cover — two parts inside one group.
Neither pricing touches the gate: `.github/workflows/srs.yml` and `.githooks/pre-commit` both run `srs_gate.py` without `--strict`, so warnings do not fail CI or a commit.

**Done when** the order is in the file, the run reports the seven pairs and nothing else new, and the ADR says why the order is this way round.

## Step 2 — re-cut the two parts that are two parts

Neither of these changes a line inside any file: both are new records, and nothing is taken out of an old one's `carries`.
That is the standard's resolution rule doing the work — the element with the most specific claim on a path owns it, so a record naming seven files inside `Sources/CrawlCall/View` takes those seven while E-050 goes on carrying the directory.
Both records go in with `status: built` from the first line, because their files exist and their obligations are realized; `proposed` would be wrong twice over — a proposed part owns none of its files, so nothing would move, and the checker would report it under `element-built`.

Written as the end state and run against the checker on 2026-10-11, then reverted, this is what it costs besides the two records: E-110 declares E-120, E-040 and E-060 declare E-130, and E-050 drops E-070 from its `depends_on` — three lists, or the run says `dependency-undeclared` three times.
The requirements move with the answer, not with the file: FR-VIEW-120 and FR-VIEW-200 leave E-050's list, FR-MAP-200 leaves E-100's.
The measurements below were computed from `arch/edges.json` and confirmed by that run.

**E-120 — the screens** (a number this layer does not carry yet; a proposal). E-050 holds 24 files, of which 20 are Swift at 2 495 lines, and they answer two questions: how the arena is drawn, and what the player taps. The second group is the SwiftUI screens and the bridge to the window:

```
Sources/CrawlCall/View/ChoicePlate.swift
Sources/CrawlCall/View/Controls.swift
Sources/CrawlCall/View/FreeCameraControls.swift
Sources/CrawlCall/View/GameHostingController.swift
Sources/CrawlCall/View/MatchEnd.swift
Sources/CrawlCall/View/SeeThroughSwitches.swift
Sources/CrawlCall/View/MatchHost.swift
```

`MatchHost.swift` is not a screen but the bridge the window hands the match — it carries FR-VIEW-230 — A change of the orientation lock pauses the match (specs/10-fr-view.md, implemented), FR-TOOL-230 — A match records its frames when asked (specs/10-fr-tool.md, implemented) and FR-MAP-140 — The setting covers all the match camera can show (specs/10-fr-map.md, implemented) — and it belongs with the screens for the same reason: what only the window knows.
With the screens in a group of their own between E-110 and E-070, the edge `FreeCameraControls → GameSession` stops running upward and becomes what it is: a screen driving the match. Upward edges go from 7 to 6, and one new legal edge appears, E-110 → E-120 through `CrawlCallApp.swift`.

What it answers for is settled: of the twelve requirements these seven files realize, two are realized nowhere else but in the configuration types that name their strings and numbers —

FR-VIEW-120 — The HUD is drawn in the diorama style (specs/10-fr-view.md, partial)
FR-VIEW-200 — Text is shown in the player's language (specs/10-fr-view.md, implemented)

— and both are on E-050's list today, so the new part has an obligation of its own from the first line.
Six more of E-050's list are realized partly in these files and partly in the rendering ones, and which side answers for each is for the maintainer to settle in the same pass: FR-VIEW-050 — iOS scheme: touch (specs/10-fr-view.md, implemented), FR-VIEW-160 — The eat button says whether there is anything to eat (specs/10-fr-view.md, implemented), FR-VIEW-190 — A finished match says so and starts again on a press (specs/10-fr-view.md, implemented), FR-TOOL-070 — Free camera (specs/10-fr-tool.md, implemented), FR-TOOL-260 — Debug mode tints what the see-through cuts by what cut it (specs/10-fr-tool.md, implemented) and FR-TOOL-270 — Debug mode switches each see-through cut off (specs/10-fr-tool.md, implemented).
The remaining four — FR-VIEW-230, FR-VIEW-220 — A game that fills an iPad's screen keeps its orientation (specs/10-fr-view.md, implemented), FR-TOOL-230 and FR-MAP-140 — are carried by E-110, E-070 and E-100 and stay where they are: a part owns a file without answering for every obligation that file helps keep.

**E-130 — the island's extent** (a proposal, as above). E-100 holds both the island's geometry and its scenery, and the geometry is what the rest of the game reads:

```
Sources/CrawlCall/Map/DistanceField.swift
Sources/CrawlCall/Map/Outline.swift
```

`DistanceField.swift` leans on nothing but `Config/Surroundings.swift`, and it is read from `Map/Passages.swift` and `Snake/Surfaces.swift` — the two edges that run upward into the surroundings today.
Put the extent below the map, and both become downward: upward edges go from 6 to 4.
What it would answer for is the harder half, and it decides whether the split happens at all.
Its two files between them implement four requirements:

FR-MAP-200 — The setting's edge is the map's outline, rounded (specs/10-fr-map.md, implemented)
FR-MAP-170 — Floor 0 is the ground (specs/10-fr-map.md, implemented)
FR-GREENHOLM-010 — The Greenholm setting (specs/10-fr-greenholm.md, implemented)
FR-MAP-270 — The ground goes on under the water (specs/10-fr-map.md, implemented)

Every one of the four is implemented in files that stay behind: FR-MAP-200 in 7 files across three parts, FR-MAP-170 in 4, FR-GREENHOLM-010 in 5, FR-MAP-270 in 8 (counted from the header annotations on 2026-10-11).
A part answers for an obligation without owning every file that realizes it, so this is allowed; what is not allowed is a part answering for nothing, which the checker reports as `element-empty`.
FR-MAP-200 is the one obligation that is this part's own sentence — the setting's edge is the map's outline, rounded, which is what a distance field and an outline compute — so **either E-130 answers for FR-MAP-200 or the split does not happen.**
This keeps FR-MAP-130 — Scenery takes no part in play (specs/10-fr-map.md, implemented) where it is, with the scenery: the extent is geometry the game may read, the scenery is what it may not.

The order grows two groups:

```json
{"layers": [["E-110"], ["E-120"], ["E-070"], ["E-050", "E-100"],
            ["E-060", "E-090"], ["E-030", "E-040"], ["E-130"], ["E-020"]]}
```

Measured on the same reverted run, `--price parts` scores the three parts as E-050 26 held · 24 inside · 27 out · 7 in, E-120 2 · 0 · 1 · 2, E-130 1 · 0 · 2 · 5.
That is the honest counter-argument to this step and it belongs in the ADR: the re-cut fixes the direction of the dependencies and does **not** improve the requirement-link measure — the view's links out still exceed the links inside it, because the two obligations that leave were weakly linked ones — and both new parts are small, 2 requirements and 1.
They are cut for the boundary, not for cohesion, which is what the layer is for ("is there a boundary somebody could cross without noticing", `srs-dd/arch.md`), but a reader who judges parts by the table alone will not see the point of either.

**Done when** both records are written with the files they claim, the run reports four upward pairs in the code *and* four in the declared model — the second only holds once the three `depends_on` lists above are rewritten, which the reverted run of 2026-10-11 proved by leaving them alone and getting seven.

## Step 3 — move `World` out of `Launch.swift`

`World` — what a match is given to run in — is declared at `Sources/CrawlCall/Launch.swift:17` and read by the match, the squads and the surroundings.
Three of the four remaining upward edges are that one declaration.
Move the `struct` into a file of its own, carried by the part that owns what a match runs in, and the three edges go with it: upward edges go from 4 to 1.

It is a move of one declaration with no change of behaviour, and it is the only step here that edits a file's contents.
Which part owns the new file is a decision, below.

**Done when** the suite passes, `arch/edges.json` no longer holds a `World:` witness into `Launch.swift`, and the run reports one upward pair.

## Step 4 — the one change that is a code change

What is left is `Map/SceneBuilder.swift` building the entities the view draws, through `SeeThrough`, `SceneView` and `LowPolySphere`.
The map layer should produce the data a scene is built from and not the scene: the building belongs in the view, which already owns FR-VIEW-030 — Game logic reads intents, not device events (specs/10-fr-view.md, implemented) and the look of everything else.
With this removed the cut is acyclic — verified on 2026-10-11 by Tarjan over `arch/edges.json` with the `World` witnesses and this edge taken out: no strongly connected component larger than one, two leaves, E-020 and E-080.

This is the one step that needs tests of its own, and it is the one to do last, because the three before it cost nothing and make its effect visible.

**Done when** the suite passes, the run reports no upward edge and no cycle, and the ADR records why the scene is built in the view.

## Step 5 — design parts for what is not built

This is the half of the layer's purpose that is entirely missing: 104 requirements stand `deferred` with no part answering for them, and 4 more are `draft` and are deliberately not designed against (`srs-dd/arch.md`: structure ahead of approval).
By area: 21 FR-CMD, 12 FR-SNAKE, 12 CON-PUB, 11 FR-TOOL, 9 NFR-PERF, 8 FR-SCORE, 6 each of IF-CMD, FR-MAP and FR-BOT, 4 FR-VIEW, 2 each of INV-SNAKE, INV-SCORE, INV-MAP and CON-CMD, and 1 CON-MAP.
`--price parts` counts the same set from the other end, as 108 requirements in no group.

The commander is the first part to design, and three independent readings say so:

- FR-CMD-020 — The commander is called on an interval (specs/10-fr-cmd.md, deferred) is the fourth most constrained requirement in the specification, with 15 incoming links (`--drivers`).
- In the cut the links themselves suggest, the group seeded by FR-CMD-020 holds 34 requirements with 65 links inside it and 9 out — the most cohesive and least coupled group of the eleven it proposes (`--price proposed`).
- The area is 29 requirements already written: 21 in `specs/10-fr-cmd.md`, 6 IF-CMD in `specs/20-interfaces.md` including IF-CMD-010 — Commander input (specs/20-interfaces.md, deferred), and 2 CON-CMD in `specs/40-invariants.md`.

A proposed part for it names where its files will be, what it answers for, what it leans on and what crosses into it, and it is written *before* the first file, which is what `proposed` is for.
ADR-0003 already fixes the hardest constraint — the language model never drives per-frame execution — so the boundary is known: the commander answers on an interval and the squads act every frame without it.
Five NFR-PERF requirements are about this part (030, 040, 055, 060, 070), and NFR-PERF-010 — 60 frames per second on the baseline device (specs/30-nfr.md, deferred) is the budget it must not break.

Two more clusters want a part and are smaller:

- **Publication** — 12 CON-PUB in `specs/40-invariants.md`: platforms, the licence, signing identifiers out of the repository, no secrets, generated speech as user content, the seller. Every one of them stands `deferred` with `code: []` and `tests: []` and `verification: I`, so the specification points at no file, and the files that in fact keep them are claimed by no element: `LICENSE`, `.gitignore`, `Signing.example.xcconfig`, `.github`, `.githooks`, the Xcode project and the entitlements are in no `carries` list (checked on 2026-10-11 against `arch/00-elements.md`). The one exception is `ATTRIBUTION.md`, which E-040 carries "for want of a better home rather than by right" by its own record's words, naming FR-MAP-100 — Maps are assembled from a modular kit (specs/10-fr-map.md, implemented) as the only requirement that reads it today and CON-PUB-030 — Third-party assets keep their licences (specs/40-invariants.md, deferred) as where it belongs once there are third-party assets to list. A part for the repository's own guards is what that line is waiting for.
- **Performance** — 9 NFR-PERF, of which 5 are the commander's. Whether the rest are a part or an obligation spread across the parts that must meet them is a judgement, and the honest answer may be that there is no part here; *What this procedure does not do* in the skill forbids inventing one to fill the file.

**Done when** `python3 srs-dd/tools/srs_arch.py --no-write` reports no `requirement-unassigned` note for the CMD area, `--plan` prints what moving to the designed parts costs, and each proposed part has passed the five readings in the skill.

## The decisions the maintainer owns

1. **Where the view stands relative to the match.** The order above puts the match above the view: the match owns the order of a frame and drives the drawing, as its own rationale says, and the violation is then a screen reaching into the match. The other way round — the view above the match, the match knowing nothing of it — is stricter and gives the same count of 7, but makes `GameSession.swift` moving the scene the violation, which it does today on purpose. **Recommended: as written, the match above the view.**
2. **The pricing of `element-cycle` while this is in flight** — `report`, with the reason written in the ADR, against `off`. **Recommended: `report`.**
3. **Whether `GameRoot` and `MatchView`, which are SwiftUI views inside `Sources/CrawlCall/CrawlCallApp.swift`, join E-120.** They are screens by nature and start-up files by location; splitting a file is not a `carries` change but a code move, and this plan does not assume one.
4. **Which of the four obligations the extent answers for** — FR-MAP-200, FR-MAP-170, FR-GREENHOLM-010, FR-MAP-270 — and therefore whether E-130 exists: a part answering for none of them is `element-empty`, and FR-MAP-200 is the only one of the four that reads as its own sentence (Step 2).
5. **Which part owns `World` after Step 3** — the match, which is what runs in it, or a part of its own for what a match is given.

## Risks, and what not to do

- **Do not touch `specs/`.** A requirement never names an element, and nothing in this plan changes what the system must do.
- **Do not let a re-cut become a code move.** Steps 1 and 2 are records; the moment a file's contents change, the step is Step 3 or 4 and needs the suite.
- **Do not redraw more than one part per round.** The skill is explicit: one file at a time, the project's checks between each, the original kept until what replaced it passes.
- **A new part that answers for nothing is not a part.** Both proposals here take files from a part that keeps the requirements those files realize, so each must be given an obligation of its own before it is written — E-120 has two that are nowhere else, E-130 has the condition in Step 2. `element-empty` is the finding that catches it, and the skill's reading of it is "a part nobody needed, or a requirement nobody wrote".
- **`arch/edges.json` is kept by hand** and nothing holds it against the code — a stale list is silent the way an absent one is (`srs-dd/arch.md`). Every step above changes which pairs the code joins, so the file is re-derived in the same set of edits, by the rule in ADR-0071. Q-530 proposes a requirement for a generator; until it exists this is the plan's weakest joint.
- **The three generated files** — `specs/90-traceability.md`, `grounds/90-dashboard.md`, `arch/90-map.md` — are regenerated by the checkers and compared by the gate; they are committed with the change, never edited.
- **Nothing is committed by an agent** unless the maintainer says so, and "заливай" means a local commit, never a push.

## For an agent starting cold

`materials/plans/surroundings.md`, section *How this project is worked, for an agent starting cold*, holds the standing instructions — the files to read first, the language to write in, how a record is cited, how the tests and the device run are started, and what the pre-commit hook does to a tree with two changes in it.
It is accurate as of 2026-10-11 with one addition: the tool paths moved to `srs-dd/tools/` in SRS-DD 0.23.0, and the standard is `srs-dd/standard.md` with the layer's own in `srs-dd/arch.md`.

At the commit this plan was written against, the checkers report: `srs_check` 0 errors, 0 warnings, 0 notes; `srs_arch` 0 errors, 13 warnings, all `element-cycle` and all described above; `srs_grounds` 0 errors, 1 warning on B-040 — FR-SNAKE-050 stands on verticality mattering (grounds/03-bets.md, retired).
That bet was retired on 2026-09-30 with its reason in the record, and the rule reads it as a cancellation because the requirement it names, FR-SNAKE-050 — Tail blocks the snake's own head (specs/10-fr-snake.md, superseded), is superseded.
It predates this work.
