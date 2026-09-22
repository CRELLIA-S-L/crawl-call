# Technical spike — RealityKit 5 on the iPhone

The three checks of ADR-0001, in one throwaway app.
Nothing here is production code: it lives outside `Sources/`, no requirement's `code` field names it, and it is deleted once ADR-0001 is settled.
The numbers it produces are the first `A` write-ups of the project (`specs/50-verification.md`).

## Build and run

```
open spike/Spike.xcodeproj        # Xcode 27, iOS 27 SDK (CON-PUB-120)
```

Signing comes from the repository-level `Signing.xcconfig` (git-ignored; copy `Signing.example.xcconfig` and fill in your team).
Run on a device with Apple Intelligence enabled — check 3 needs the system model; the simulator has neither the model nor the thermal behaviour.
Measured on the iPhone 16 Pro with a 20 % margin against the iPhone 15 Pro baseline (ADR-0015).

Every second the app appends one row to `spike-<date>.csv` in its Documents folder (Files app → On My iPhone → Spike) and prints the same row to the Xcode console prefixed `[spike]`.

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

## Verdict

All three pass — ADR-0001 becomes `accepted`, the CSVs go under `materials/spike/` with a short write-up, this directory is deleted.
Check 1 or 3 fails — SwiftGodot, per ADR-0001.
Check 2 fails — first Q-140 (60 fps) and Q-020 (4v4) are revisited, then the stack.

## The prompt bench

The commander's prompt is measured, not argued about (FR-TOOL-150). The bench calls the
model directly with no rendering, so a hundred calls take minutes:

```
swiftc -O -target arm64-apple-macos27.0 -parse-as-library \
    Spike/PromptBench.swift Spike/PromptVariants.swift bench/main.swift -o bench
./bench all 5                 # every instruction variant, 5 calls per scenario
./bench v2-soft 10            # one variant
./bench patterns 30           # kept session vs fresh vs fresh-without-schema
./bench anatomy               # where the input tokens go
BENCH_SCHEMA=ranged BENCH_MAX_OUT=80 ./bench v2-soft 10
BENCH_SCENARIOS=grim,grim-soft ./bench v0-baseline,v2-soft 10
```

Every run must include `v4-provocative`, the control written to be blocked (FR-TOOL-160):
a bench that cannot detect a block reads the same as one that found none. It was blocked
in 50 of 50 calls while the game's own configurations were blocked in 0 of 100.

The same bench runs on the phone (`--autopilot --bench all --bench-repeats 5`); the Mac
and the phone gave the same counts, so the Mac is where the work is done.

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

**Check 3 — passed, and the prompt measured with it.** A commander call answers in 2.6 s on average and 3.2 s at worst, far inside its 5–10 s interval; the device reached `fair` and came back to `nominal` over a twenty-minute run without losing frame rate.

The same ten-minute route, before and after the prompt work:

| | before | after |
|---|---|---|
| commander calls answered | 48 of 62 | 61 of 61 |
| blocked | 14 (23 %) | 0 |
| input tokens | 586–590 | 531–537 |
| latency avg / max | 2936 / 3567 ms | 2619 / 3167 ms |

What the bench settled (ADR-0017 carries the reasoning):

- the state's vocabulary and the instructions each block on their own: the same situation written as wounds and bodies was blocked 10 of 10 under the old instructions and 0 of 10 under the new ones, while the control's instructions block even the calmest state, and the old instructions block `./bench anatomy`'s trivial one-character prompt;
- the game's first configuration was blocked in 10 of 100 bench calls, the measured one in 0 of 100, at 324–338 input tokens against 453–467, repeated three times with the same counts;
- `permissiveContentTransformations` does nothing under guided generation, which is what the commander uses;
- one session per call beats a kept session on tokens (402 against about 1150), latency (about 1.6 s against 1.9 s) and robustness — there is no transcript to poison;
- a guide's `.range` is worth its tokens and its description prose is not: dropping the prose saved 72 tokens a call and cost nothing, dropping the range produced 0.8 to 8.0 where the field is 0 to 1;
- leaving the schema out of the prompt saves 206 input tokens and triples the output, with one call past 40 seconds in each of two runs; `maximumResponseTokens` bounds that instead.

**What is still not met.** NFR-PERF-030 asks for every frame under budget while an inference runs. Measured over nine minutes and 61 calls: two missed frames, one at app start and one during the second call — about one frame per sixty calls. Small, real, and not a prompt problem: the fix belongs where the inference is scheduled.
