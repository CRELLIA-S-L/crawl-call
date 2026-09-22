# The technical spike — what it checked and what it measured

The 2–3 day check of the RealityKit 5 stack that settled ADR-0001, run on 2026-09-22 on an iPhone 16 Pro (iOS 27.0 24A437, Xcode 27.0 27A5218g) with a 20 % margin against the iPhone 15 Pro baseline (ADR-0015).
This is the write-up, not the code: the throwaway app — its arena, its snake, its bots, its commander and its Xcode project — was deleted once the decision was taken, and lives on only in the history of this repository.
What outlived it is here and in two places named at the end.
The numbers below are the project's first `A` write-ups (`specs/50-verification.md`), and every requirement that cites a spike measurement cites this file.

## What the three checks asked

The app was built to answer three questions and nothing else; each was judged against the criteria below, which are kept as they were written before the run.
All three passed, and ADR-0001 became `accepted` — but not in the form the first check was written in: RealityKit's navigation mesh failed on the way and was replaced by a steered snake over a grid graph (ADR-0016), which is what the criteria were then judged against.

## Check 1 — the snake-spline on a navmesh with a vertical transition (FR-SNAKE-010, -020, -220)

Tap the floor: the head pathfinds there over the navigation mesh; the tail follows as a tube rebuilt every frame through `LowLevelMesh`.
The arena has a ground floor, an upper floor 3 m up on the right, a ramp between them at the back, a 3 m ledge at the front with a one-way drop connection, and six cover boxes.

Look for (a `D`, judged by eye):

- the tail lies on the ramp on the way up, not through it and not floating;
- the tail follows the head down the drop as a vertical portion, unbroken;
- the tail wraps around a cover box rather than cutting through it;
- at tail length 100 the tube neither tears nor lags the head.

Pass: all four. Anything else is written down with what was seen.

## Check 2 — eight bots deliberating every frame (NFR-PERF-010, -020)

Eight bots choose an action by utility on every frame — the worst case, no queue, no budget — and request paths on a change of action.
`repath every frame` makes them also request a path every frame: the upper bound for pathfinding cost.

Read off the HUD / CSV after two minutes with the snake moving among them:

- `fps` ≥ 60 and `frame max` ≤ 13.3 ms (16.6 with the 16 Pro margin) — pass;
- `deliberation avg` — the cost of eight utility evaluations per frame; the concept's budget is 0.5 ms with a queue, so this number with no queue should be well under it;
- `path requests/s` and `deliberation max` with `repath every frame` on — the pathfinding cost, for the record.

## Check 3 — one Foundation Models call beside rendering (NFR-PERF-030, -040, -050)

Switch `commander` on: every 7 s the app sends the squad state to the system model and receives a `CommanderOrder` through guided generation — threat, order, three weights, a callout.
The first call is a warm-up and is logged as such.

Read off after 15–20 minutes with everything running (this is the thermal check):

- `worst frame during inference` ≤ 13.3 ms — NFR-PERF-030 pass;
- `inference max` < 7000 ms — NFR-PERF-040 pass;
- `thermal` over time and `fps` in the last minute against the first — NFR-PERF-050; the point at which `thermal` reaches `serious` is the number the degradation threshold (NFR-PERF-060) is set from;
- `fail` stays 0; a callout that reads like a soldier is a bonus, not a criterion.

## Findings (2026-09-22, iPhone 16 Pro, iOS 27.0 24A437, Xcode 27.0 27A5218g)

### First form — RealityKit's navigation mesh — abandoned (ADR-0016)

The tail through `LowLevelMesh` is fine by eye at 10, 40 and 100 segments; 60 fps by `CADisplayLink`, no dropped frames; RealityKit's own `deltaTime` jitters and must not be used as a frame-time measure.
The navigation mesh builds correctly from the arena geometry (from one merged `MeshDescriptor` — `NavigationMeshResource(mesh:)` given a multi-part `MeshResource` lost the upper floor), the ramp ↔ upper floor seam holds and the one-way `OffMeshConnection` drop works.
But `NavigationController` resolves a position — target *and* start — to a polygon by XZ, taking the polygon with the lowest index among those overlapping the column, ignoring height: two points on one plane, requested at y=0 and at y=3 with the same XZ, return the same path, and which floor it lies on depends on polygon order.
Per-level resources do not help (an agent with `layer: nil` sees only the first), thickness changes nothing, Apple's Chaparral Village sample calls the API the same way, and the documentation states no further condition.
On a map with balconies this makes the built-in queries unusable; the maintainer chose to drop the navmesh altogether.

### Second form — steered snake, grid graph — the checks

**Check 1 — passed.** The head is a `CharacterControllerComponent` (radius 0.3, height 0.6, slope 50°, step 0.4) driven by a virtual joystick; the arena's slabs are static collision shapes.
By the maintainer's eye: climbs the ramp, drops off the ledge with the tail following down the drop unbroken, wraps around cover, tail length 100 without tearing or lag.
The bots path over the grid graph (`Grid.swift`, ADR-0016): cell 0.5 m, 48×32 cells, 1990 walkable surfaces, 616 cells with two levels; all ten startup probes reach the right floor, including the two same-XZ pairs that broke the navmesh.

**Check 2 — passed.** Eight bots deliberating every frame: 0.05–0.15 ms average, ~1 ms worst per frame; 60 fps, 0 dropped frames by vsync; ~30 path requests/s.
One A* path costs 2–120 µs in the probes and up to ~1 ms in play for a far or unreachable target (a full search of 1990 nodes at ~0.5 µs per node), after the open list became a heap, the search state flat arrays and the smoothing bounded.
So a single path can exceed the 0.5 ms per-frame budget of NFR-PERF-020 on its own; the budget is met by handing out at most one path request per frame, which is what the concept's slot scheduling does, not by a faster A*.
Confirmed over ten minutes with the autopilot: 60 fps, two missed frames in the whole run, deliberation worst frame 1.9 ms.

**Check 3 — passed, and the prompt measured with it.** A commander call answers in 2.6 s on average and 3.2 s at worst, far inside its 5–10 s interval; the device reached `fair` at fourteen minutes of a twenty-minute run and never `serious`, without losing frame rate.

The same ten-minute route, before and after the prompt work:

| | before | after |
|---|---|---|
| commander calls answered | 48 of 62 | 61 of 61 |
| blocked | 14 (23 %) | 0 |
| input tokens | 586–590 | 531–537 |
| latency avg / max | 2936 / 3567 ms | 2619 / 3167 ms |

What the bench settled (ADR-0017 carries the reasoning):

- the state's vocabulary and the instructions each block on their own: the same situation written as wounds and bodies was blocked 10 of 10 under the old instructions and 0 of 10 under the new ones, while the control's instructions block even the calmest state, and the old instructions block `./bench anatomy`'s trivial one-character prompt;
- the game's first configuration was blocked in 10 of 100 bench calls, the measured one in 0 of 100, at 324–338 input tokens against 453–467, repeated four times with the same counts;
- a variant is safe only in the configuration it was measured in: the shortest instructions passed 150 calls with the shipping schema and were blocked 6 times in 100 with the previous one, every block on the same scenario, while the shipping instructions have never been blocked in either — which is why the 28 tokens the short ones save are not taken;
- `permissiveContentTransformations` does nothing under guided generation, which is what the commander uses;
- one session per call beats a kept session on tokens (402 against about 1150), latency (about 1.6 s against 1.9 s) and robustness — there is no transcript to poison;
- a guide's `.range` is worth its tokens and its description prose is not: dropping the prose saved 72 tokens a call and cost nothing, dropping the range produced 0.8 to 8.0 where the field is 0 to 1;
- leaving the schema out of the prompt saves 206 input tokens and triples the output, with one call past 40 seconds in each of two runs; `maximumResponseTokens` bounds that instead.

**Over twenty minutes, everything passes.** 121 commander calls with no failure, 532–536 input tokens, 2.7 s average and 3.3 s worst against a 5–10 s interval; 60 fps with one missed frame in 71,820, and that one in the first ten seconds; the device reached `fair` at fourteen minutes and never `serious`; no frame missed while an inference ran.

**NFR-PERF-030, the one that was not met, was met here.** The nine-minute run missed one frame during an inference in 61 calls; the twenty-minute run missed none in 121. Over 182 calls that is one frame, at the start of a session. Left as a watch item rather than a defect: the reading is a rate, and one occurrence does not settle a rate.

**A note on the worst-case mode.** With `repath every frame` on for the first two minutes the bots asked for about 91,000 paths and 943 of them found none, roughly one in a hundred — a wander target that landed in a blocked cell. The frame budget held throughout (worst deliberation frame 3.5 ms), so it is a property of the random targets in this throwaway arena rather than of the search.

**One criterion was not answered as planned.** Check 3 expected the degradation threshold of NFR-PERF-060 to be read off the moment `thermal` reached `serious`; over twenty minutes the device never got there. The threshold therefore defaults to `serious` as the first state whose cost is unmeasured (IF-BOT-010), and the factor by which the intervals stretch has no measurement behind it at all — it is Q-180 in `specs/91-open-issues.md`.

## Where the pieces went

- **The prompt bench** — `Sources/PromptBench/`: the only implementation of FR-TOOL-150 and FR-TOOL-160, and a tool the project keeps using. Its own README carries the protocol and the commands.
- **The measurement instrument** — `instrument/` beside this file: `run-autopilot.sh`, `analyze.py` and the on-device `Autopilot.swift` that drove the fixed route. They ran against the spike's app and cannot run without it; they are kept as the working example of the unattended run that `specs/50-verification.md` requires of every performance measurement, for the game's own autopilot to be built from.
- **The raw CSVs** — not here. The per-second telemetry the runs produced stays out of the repository by the maintainer's decision; the numbers taken from it are the tables and paragraphs above, and `bench.csv` is git-ignored for the same reason.
- **Everything else** — the app, the arena, the grid, the commander, the Xcode project — deleted. What it proved is in ADR-0001, ADR-0016 and ADR-0017; what it measured is above.
