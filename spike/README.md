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

## Findings so far (2026-09-22, iPhone 16 Pro, iOS 27.0 24A437, Xcode 27.0 27A5218g)

**Check 1 — mixed.**
The tail through `LowLevelMesh` is fine by eye at 10, 40 and 100 segments; 60 fps by `CADisplayLink`, no dropped frames; RealityKit's own `deltaTime` jitters and must not be used as a frame-time measure.
The navigation mesh builds correctly from the arena geometry — the ramp ↔ upper floor seam holds (`ramp mid → upper far: REACHED 1.5 → 3.0`) and the one-way `OffMeshConnection` drop works, ignored by the bots through a flag.
Two things do not:

1. `NavigationMeshResource(mesh:)` given a multi-part `MeshResource` built the navmesh from part of the geometry (the upper floor was missing). Building from one merged `MeshDescriptor` gives the whole mesh.
2. `NavigationController` resolves a position — target *and* start — to a polygon by XZ, taking the polygon with the lowest index among those overlapping the column, ignoring height. Shown by polygon indices (24 < 25 → upper floor wins on that half; 56 < 62 → ground wins on the other; 58 < 67 → ground under the ramp wins), by tapping, and by the startup probes. Splitting the mesh into per-level resources does not help: an agent with `layer: nil` sees only the first resource. Giving the floor and ramp thickness changes nothing. On a map with balconies this makes the built-in queries unusable as they are.

Decision pending: own polygon A* over the resource's `vertices`/`polygonIndices`/`heightData` (keeping RealityKit for navmesh generation, rendering, ECS and the model) versus the SwiftGodot fallback of ADR-0001.

**Check 2 — preliminary.** Eight bots deliberating every frame: 0.08–0.11 ms average, 0.6 ms worst, at 60 fps with 0 dropped frames; path requests ~30/s after fixing the arrival loop. Not yet run with `repath every frame` or for two minutes with the snake among the bots.

**Check 3 — not run.**
