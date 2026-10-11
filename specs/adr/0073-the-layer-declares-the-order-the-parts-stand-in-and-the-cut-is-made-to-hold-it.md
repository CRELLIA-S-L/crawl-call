# ADR-0073 — The layer declares the order the parts stand in, and the cut is changed to hold it

- **Status:** accepted
- **Date:** 2026-10-11
- **Related requirements:** FR-MAP-120, FR-MAP-130, FR-MAP-200, FR-VIEW-030, FR-VIEW-120, FR-VIEW-190, FR-VIEW-200

## Context and problem statement

ADR-0071 made the architecture layer describe the cut the code has, and found thirteen circles in it.
Those were written up in Q-530 and left, on the reading that a redraw of a working game is the maintainer's to agree.
On 2026-10-11 the maintainer said what the layer is for: it is to propose the structure the requirements call for and to hold it as they change, not to record whatever the code grew into.
By that reading the thirteen circles were never a finding to file; they were the layer saying the cut was wrong.

Nothing in the repository stated what the structure ought to be.
The framework provides for exactly that — `layers` in `arch/arch-config.json` orders the parts in levels and reports every dependency that runs against the order, in the declared model and in the code separately (`srs-dd/arch.md`) — and the project used none of it.

## Considered options

For the order itself:

1. The match above the view: the match owns the order of a frame and drives the drawing.
2. The view above the match: the view observes a match that knows nothing of it.

For the circles the order then exposes:

1. Re-cut the parts where a part held two responsibilities, and change the code only where no re-cut can help.
2. Change the code to fit the cut as it stands.
3. Price the findings down and leave both.

For the parts that hold two things:

1. The view splits: the drawing and the screens.
2. The surroundings split: what play reads and what only the eye sees.
3. `World`, the value a match is handed, leaves start-up for a part below everything that reads it.

## Decision outcome

**The order, option 1 — the match above the view.** E-070's own rationale already says it is the only part that knows the order of a frame: the world moves first and the picture follows. The stricter reading, with the view observing the match, would make `GameSession` moving the scene the violation, and it does that on purpose. The order, top down: start-up; the screens; the match; the view beside the surroundings; the snake beside the squads; the input contract beside the map layer; the configuration contract. The prompt bench, the runners and the repository's guards stand outside it, which is how an order is adopted on a cut that already exists.

**The circles, option 1.** Of the seven dependencies that ran against the order, three were a part holding two responsibilities and went away with a re-cut; four were the code reaching the wrong way and were changed. None was priced down.

**`element-cycle` is priced `report`.** The order says what a circle says and says it better — which two parts, which way, and the file the reference is in — so the derived reading stays audible without being a warning of its own.

### The two parts that were two parts

**E-120, the screens, split from the view.** The view held both how the arena is drawn and what the player touches and reads; the second group drives a match — a press restarts it, a switch changes what it draws, the window's orientation lock pauses it — and while it sat in the view that driving ran upward. Above the match it is the ordinary direction. The part answers for FR-VIEW-120 and FR-VIEW-200, which nothing outside those files realizes but the configuration types that name their strings and numbers, for FR-VIEW-160, a button that must say what it can do, and for FR-VIEW-190, which the view and the match had both claimed since 2026-09-25 — the match owns the two ends of a game, and the screen that announces one and offers another is this part. `MatchHost.swift` went with them: it is the bridge the window hands the match, and what only the window knows is not the view's business.

**The surroundings gave four files to the map layer.** This is the decision that was reached by being wrong twice. The surroundings held the setting a map's header names, the outline that header's ground floor makes, the field that answers how far a point lies from that outline, and the rectangle of ground both are measured in — and all four are read by play: the passage check asks where the ground ends before it cuts a way through, and the snake asks before it lets the head off the edge. The part's whole reason is that play may not read it (FR-MAP-130). The first attempt took the geometry down into a part of its own and left the description with the scenery; the checker refused it, because `World` holds a `Setting` and the value every part runs on would then have depended on the scenery. The second attempt took the description down too, and the checker refused that as well: the outline is computed in the map's own cells, so a part holding it and a map layer asking it questions lean on each other. The third reading is the one that holds — the four files are computed from the map and belong to the map layer, which already owns the graph, the plan and the line test. The geometry needed no part of its own: `Outline` computes the rounded edge *with* the distance field, so FR-MAP-200 is one obligation realized by both, and one obligation is answered for by one part.

### The four changes to the code

Each was made on its own, with the suite run after it; none changes what the game does.

**`World` left start-up for the map layer.** Eighteen references reached up into `Launch.swift` for the value a match is handed. The match reads it, the squads read it, the scenery reads it, so it has to sit below all three — which rules out the match, where this decision first put it. The map layer produces four of its six parts (the kit, the map, the graph, the plan), and Q-530 had named it as the alternative. It is now `Sources/CrawlCall/Map/World.swift`.

**`Map/SceneBuilder.swift` left for the view.** Fourteen references from one file, and its own header already disowned what it was doing: "How the result is lit and seen is not here but in `View/`", while it called `SceneView.ambient`, `SceneView.light` and `SceneView.camera`. The whole file turns metres into RealityKit entities, which is one act with lighting them and placing the camera. Moved whole, not split.

**The island's edge is computed where the setting is, not where the scenery is.** `Setting.edge(around:)` dispatched to `Greenholm.edge`, which put the one thing play reads inside the file that draws. The seven lines moved into the dispatch, `Greenholm.scenery` is handed the edge it draws along, and the scenery dispatch became an extension beside the scenery — which changed no call site, because an extension in another file is still `setting.scenery(…)`.

**`LungePose.of(_ game: Game)` left the view.** A drawing reaching back into the match for five values, with the pure function it wrapped already taking them plainly (FR-VIEW-030). The convenience is gone and the one caller, the match itself, builds the arguments.

**`GroundRect` left the coverage arithmetic for its own file**, so that the parts that measure in it read it from the level it belongs to rather than from the file that first needed it.

## Consequences

**Every dependency in the code now runs with the order.** Thirteen parts in force and one designed, 31 pairs of parts the code joins, no dependency against the order, no circle, and `srs_arch.py` reports no error and no warning. The configuration contract is the only leaf inside the order; the map layer, which everything above it reads, depends on nothing but that contract.

**The declared model and the code agree, pair for pair.** Seven of the eleven `depends_on` lists the layer held that morning were rewritten in the course of this, every one of them because the checker said the code disagreed — which it could only say because FR-TOOL-330 produces the comparison from the sources (ADR-0072).

**One witness per pair of parts cannot answer a question about a re-cut.** `arch/edges.json` holds one reference per pair, which is enough to compare a model against the code and not enough to predict what moving a file would do: the plan written on 2026-10-11 twice predicted the wrong result because it read the witness instead of the references behind it — the view was thought to reach the match from one file when five do, and the map layer's reach into the surroundings was thought to be the distance field alone when it was the setting as well. Both were caught by the checker within the hour. A re-cut is judged by recomputing every reference, never from the file.

**Three of the five decisions put to the maintainer on 2026-10-11 survived measurement, and two did not.** The order, the pricing and leaving `GameRoot` and `MatchView` in `CrawlCallApp.swift` stand as decided. `World` belongs to the map layer and not to the match. The geometry of the setting's ground needed no part of its own and belongs to the map layer too.

**The suite was run after every change**: 692 tests, no failure, no build warning, four times over the course of the work.
