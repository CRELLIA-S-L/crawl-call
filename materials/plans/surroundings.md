# Surroundings — the world around the arena: handoff

A plan agreed with the maintainer on 2026-09-24 and not yet started. It is written so that an agent with no memory of the conversation can take it up; everything it needs is here or pointed to from here.
This file is not the specification. `specs/` is, and the first step of the work below is to write the requirements into it; until then nothing here binds anybody (ART-020 of `specs/constitution.md`, and `AGENTS.md`).
The open question that points here is Q-270 in `specs/91-open-issues.md`.

**Built (2026-09-24)** through step 6 — the requirements, ADR-0031, the coverage, the setting, Greenholm with its sky, and the birds; step 7, wind, was not asked for. What changed from this plan on the way is in ADR-0031.

**Step 1 is done (2026-09-24).** The requirements are written: FR-MAP-120, FR-MAP-130 and FR-MAP-140 in `specs/10-fr-map.md`, *Surroundings*; the island as the area GREENHOLM in `specs/10-fr-greenholm.md` — the maintainer asked for an area per setting, each with a proper name, since there will be more than one island; and IF-MAP-010 names the setting in the header, `partial` until the parser reads it. The three texts below were split into six there, and are kept here as they were agreed; where they differ, `specs/` wins.

## What the maintainer asked for, and what they decided

The request, in their words: a surrounding world — sky, space beyond the map, maybe some birds and vegetation, "or something like that".

Decided by the maintainer on 2026-09-24:

- **The first setting is an island.** The arena stands on a grassy island; the maintainer had the same idea independently.
- **The world is finite.** The camera's pitch changes only for testing (the free camera of debug mode, FR-TOOL-070, ADR-0023); in the released game the angle is frozen (FR-VIEW-010). So the world does not have to be endless — it has to be larger than the area the match camera can ever show.
- **Settings will vary.** Later maps may stand in a crater, a spaceship, a clearing in a forest, a closed building and the like. The design must let a new setting be added without reworking the others.
- **The approach below, and the three requirement texts in it, are agreed in substance.** Their numbers are not assigned and their exact wording is settled when they are written into `specs/` (see *Steps*).
- **Work was not to start in that session.** This file was asked for instead, so that the work can be picked up later from a clean slate.

## What the match camera can show

The numbers below are what the requirements and the tests rest on. Re-derive them from the code rather than trusting the tables: they follow from the values cited here.

The camera, as the code has it:

- A perspective camera with a vertical field of view of 50 degrees: `SceneView.camera(for:pitchDegrees:)` in `Sources/CrawlCall/View/SceneView.swift` sets `fieldOfViewInDegrees = 50`, and `PerspectiveCameraComponent.fieldOfViewOrientation` defaults to vertical (RealityFoundation, iOS 27.0 SDK: "This property defaults to ``CameraFieldOfViewOrientation/vertical``").
- Pitch 55 degrees as shipped (`config/view.json`, `cameraPitch`); FR-VIEW-010 allows 50 to 60.
- Distance to the point looked at: 1.1 times the larger side of the arena (`CrawlCallApp.swift`, `max(world.plan.bounds.extent.x, world.plan.bounds.extent.z) * 1.1`) — 13.2 m for the blockout, whose arena is 12 × 8 m.
- The point looked at follows the head and stops where the frame would show ground past the arena (FR-VIEW-020, `SceneView.focus`). It never leaves the arena's bounds.
- The phone's screen is 2622 × 1206 pixels in landscape (the iPhone 16 Pro the game is tried on, read off its screenshots).

**The sky is never in the match frame.** The top edge of the frame looks down at the pitch less half the field of view: 25 degrees below the horizon at a pitch of 50, 30 at 55, 35 at 60. The horizon and everything above it stay out of frame at any pitch FR-VIEW-010 allows. The sky is seen only by the free camera tilted below 25 degrees, and it matters to the match only as the light the scene is lit by.

**How much ground it shows.** Around the point looked at, a trapezoid: far edge away from the camera, near edge towards it. For the blockout, on that screen:

| Pitch | Beyond the point | Towards the camera | Either side at the far edge | Either side at the near edge |
|---|---|---|---|---|
| 50° | 13.2 m | 5.8 m | 22.0 m | 9.6 m |
| 55° | 11.2 m | 5.7 m | 19.9 m | 10.1 m |
| 60° | 9.7 m | 5.6 m | 18.3 m | 10.5 m |

Derivation: with `d` the distance, `p` the pitch and `f` the vertical field of view, the camera stands at height `h = d sin p` above the point it looks at, `d cos p` behind the point on the ground. A ray at `a` degrees below the horizontal meets the ground `h / tan a` in front of the camera: the far edge is the ray at `p − f/2`, the near edge the ray at `p + f/2`. The corners take the horizontal half-angle from the aspect: the corner ray is `right · (aspect · tan(f/2)) ± up · tan(f/2) + forward` in the camera's frame, followed to the ground. The table came from a script of these lines on 2026-09-24; the implementation should compute this, not copy the table.

The table takes the ground at the height of the point looked at. It is not always there: the point follows the head up to the balcony, a floor higher (FR-VIEW-020, `SceneView.focus` sets its height to the head's), while the ground around the island stays at the bottom — and water below the shore is lower still. The rays then run further before they meet it. With the point a floor, 3 m, above the ground:

| Pitch | Beyond the point | Towards the camera | Either side at the far edge | Either side at the near edge |
|---|---|---|---|---|
| 50° | 19.6 m | 5.0 m | 28.5 m | 12.5 m |
| 55° | 16.4 m | 5.1 m | 25.4 m | 12.9 m |
| 60° | 14.0 m | 5.3 m | 23.1 m | 13.3 m |

So the coverage is computed for the highest floor the point can be on and the lowest surface of the surroundings, not for the ground floor alone; the same derivation with the camera raised by the difference gives it. Both tables were computed on 2026-09-24 and each was reproduced by a second, independent derivation.

What the tables mean for the surroundings: they must cover the arena's bounds grown by those margins, for every pitch FR-VIEW-010 allows and every floor the camera can look at. The margins scale with the arena, because the distance does, and with the screen's aspect ratio, so they are computed from the camera and the map, never written down as numbers. The maintainer asked, in the same session, that sizes not be hard-coded in the code (see ADR-0022, where the bots' size went into configuration for that reason).

The free camera of debug mode can zoom out to 20 m and tilt to 10 degrees (`config/view.json`), and so can see past any finite world and up into the sky. That is acceptable: it is a testing tool, and the requirement below is about the match camera only.

## What RealityKit offers, checked in the iOS 27.0 SDK

Read from the SDK's own interfaces on 2026-09-24, not from memory. The paths are under the iPhoneOS 27.0 SDK.

- **A sky.** The game renders through SwiftUI's `RealityView`. Its content, `RealityViewCameraContent`, has `environment: RealityViewEnvironment`, which is `.default` or `.skybox(EnvironmentResource)` — iOS 18.0 and later (`_RealityKit_SwiftUI.framework`). An `EnvironmentResource` can be made from a picture in code: `EnvironmentResource(equirectangular: CGImage, withName:)` (RealityFoundation); the SDK marks it to be replaced by `init(equirectangular:options:)` in future. The game already does exactly this: `SceneView.ambient(for:)` paints a flat daylight colour into an equirectangular bitmap and lights the scene with it through an `ImageBasedLightComponent`. A painted sky gradient could be the same picture, so that the sky and the light match. *Not checked:* whether setting `.skybox` also changes how the scene is lit; FR-VIEW-130 requires a single daylight source and a readable ambient, and that must still hold.
- **Particles.** `ParticleEmitterComponent` (RealityFoundation), with ready-made emitters in `ParticleEmitterComponent.Presets` — `fireworks`, `impact`, `magic`, `rain`, `snow` — iOS 18.0 and later (RealityKit). Enough for weather, dust, fluff in the air; not for birds.
- **Primitives.** `MeshResource.generateBox`, `generateSphere`, `generateCylinder`, `generateCone`, `generatePlane` (cone and cylinder since iOS 18.0). Trees, shrubs, rocks, reeds are built from these the way the bot figures are (`Sources/CrawlCall/View/Figure.swift`, ADR-0022): described as data a test can read, built into entities afterwards.
- **Movement.** Transform animations (`FromToByAnimation`), or the per-frame update the game already runs (`GameSession.step`). Birds: a few small primitive figures flying loops over the arena, now and then flapping.
- **Wind.** `CustomMaterial` takes a `geometryModifier` besides its surface shader (RealityFoundation), so foliage can sway in a Metal shader, beside the hole shader the game already has (`SeeThroughHole.metal`, ADR-0020).
- **Not there.** No terrain system, no vegetation or bird assets, no flocking, no fog or haze to hide a world's edge. Everything is built from primitives, or taken from a CC0 pack such as Quaternius under CON-PUB-030 (third-party assets keep their licences; `ATTRIBUTION.md`). The island hides its edge by being an island: water reaches the edge of what the camera can show.

## The design agreed

**A setting has three layers.**

1. *The ground around the arena*, over the whole area the match camera can show: grass and shore for the island, a crater floor, a hangar deck.
2. *The rim* that closes the space in: trees and shrubs, crater walls, bulkheads, the walls of a building. For the island the rim is its ring of trees and shrubs with the shore beyond them, and water stretches from the shore to the edge of what the camera can show.
3. *The backdrop*: sky, space, a ceiling. Never in the match frame (above); it lights the scene and is what the free camera sees.

**A map names its setting.** One header line in the map file, for example `setting greenholm`, beside the existing `kit` and `transition` lines. IF-MAP-010 says the header "names the module kit and the transitions between floors", so the statement changes to include the setting, and `MapParser` learns the line — it is in `Sources/CrawlCall/Map/MapSpecification.swift`, where the header's `kit` and `transition` lines are read. Settings are families of scenery like module kits: a new one is a new family, not a change to the others. Where a setting's own numbers live — heights of trees, water colour, how often birds fly — is configuration beside the kit (`config/kit/<kit>/legend.json` is the precedent), not code.

**Scenery is for the eye only.** It takes no part in movement, in what the bots see, in the navigation graph or in what is cut open for the snake. In the code that means it stays out of `ScenePlan.pieces`: the plan's pieces are what `Surfaces` collides the snake with (ADR-0021), what `Sight` tests lines of sight against (ADR-0019) and what `SeeThrough` cuts open (ADR-0020). Scenery gets its own entities under the scene, built from its own description.

## The requirements agreed in substance

Numbers are unassigned; they are proposals until written into `specs/` and approved there. The wording is the one put to the maintainer on 2026-09-24:

> While a match is running, the system **shall** fill every part of the frame the match camera can show — at any pitch FR-VIEW-010 allows, over any point the camera can look at — with the map's surroundings, leaving no part of it empty.

> A map **shall** name the setting its arena stands in, from the settings the game provides; a setting is scenery only and takes no part in movement, sight, navigation or what is cut open for the snake.

> The system **shall** provide the island setting: the arena on a grassy island ringed by trees and shrubs, with a shore and water reaching the edge of what the match camera can show, a daylight sky above, and birds that now and then cross over the arena.

The first two belong to the VIEW and MAP areas; the third may sit in VIEW or be a kit-level requirement like FR-MAP-100. `python3 tools/srs_view.py --areas` and the neighbours of FR-VIEW-130 and FR-MAP-100 decide where they sit. The first one is verified by `T`: coverage is arithmetic, and a test computes it for the pitch range and several aspects and checks the surroundings' extent against it. The other two are `D`, judged on the phone.

A decision record goes beside ADR-0022 and ADR-0023 in `specs/adr/`: the three layers, settings as families, scenery out of the plan, the coverage rule, and why the sky is lit rather than seen.

## Risks already known

- **Near-edge scenery between the camera and the arena.** The camera stands on the +z side of the point it looks at, `d cos p` from it across the ground — 7.6 m for the blockout at 55 degrees — and the frame shows 5 to 6 m of ground on that side, depending on the pitch and the floor (above). Trees in that strip stand between the camera and whatever of the arena lies behind them. Either they are kept low there, or they are left out of that side, or they are cut open like map modules — which would bring scenery into FR-VIEW-150, against the second requirement. Decide this in the ADR.
- **Frame rate.** A world of trees, water and birds costs drawing time, and the frame rate is not measured (Q-250, NFR-PERF-010 `deferred`). Keep the part count modest and share materials and meshes, as `Figure` shares materials per squad.
- **Lighting.** FR-VIEW-130 asks for one daylight source and an ambient that keeps back faces from reading black. A sky must not become a second light or dim the ambient. Check it on the phone.
- **The camera stop at the arena's edge (FR-VIEW-020).** With a world around the arena, the reason for that stop — "ground beyond the arena is nothing" — no longer holds. The maintainer was asked whether to relax it, with the suggestion to leave it as it is since the free camera shows the surroundings anyway, and agreed to the proposal as a whole. Do not change it as part of this work.

## Steps

In order, each through the project's procedures:

1. Write the three requirements into `specs/` with the `srs-new` skill, and change IF-MAP-010's statement for the `setting` line. Put the texts to the maintainer before they are marked approved (`AGENTS.md`, rules 4 and 8).
2. Write the ADR.
3. The coverage computation, as a pure function with tests: the trapezoid for a camera, a pitch range, an aspect and the height between the highest floor and the lowest surface of the surroundings, and the arena's bounds grown by it. Test it against an independent derivation, not against the tables above.
4. The setting as a description (layers, parts, paints) built into entities, kept out of `ScenePlan`; the map's `setting` line parsed; `maps/blockout.map` names `greenholm`.
5. The island: ground, shore, water to the coverage edge, trees and shrubs on the rim, then the sky as the environment and the ambient light.
6. Birds.
7. Wind in the foliage, as a second pass if the maintainer wants it.

Run each through `build-loop` and then `review-loop`, as the maintainer asked for the changes made on 2026-09-24. Those two are the maintainer's own skills, kept in their user directory (`~/.claude/skills/`) and not in this repository; an agent without them follows what they ask by hand — a list of what must exist, a test that fails without each item, the whole suite passing twice with the second run from a clean build, then two review passes by different methods. Install on the phone at the end, and only when the maintainer names it.

## How this project is worked, for an agent starting cold

- Read `AGENTS.md` and `CLAUDE.md` first; `specs/README.md` wins on any conflict about the specification.
- Talk to the maintainer in Russian. The specification, code, comments and commit messages are in English.
- Cite a record at its first mention in a message from the tool: `python3 tools/srs_view.py --cite <ID>`, `python3 tools/srs_arch.py --cite <ID>`, `python3 tools/srs_grounds.py --cite <ID>`.
- Tests: `sh scripts/run-tests.sh <simulator-udid>`. The phone: `CRAWLCALL_DEVICE=<device-udid> sh scripts/run-on-device.sh <app> [screenshot]`, which closes the app when the run is over. No device or simulator identifier goes into the repository.
- The simulator shows no controls and no bot movement in its first seconds; a build of commit `935d0f8`, made on 2026-09-24 to check exactly this, does the same, so it is the simulator and not a regression.
- Commits are the maintainer's unless they ask the agent to make them. The pre-commit hook regenerates `specs/90-traceability.md` from the working tree, so two changes in one tree cannot be committed apart with `git add -p`; reduce the tree to the first change, commit, and restore the rest.
- Checkers: `python3 tools/srs_check.py`, `python3 tools/srs_arch.py`, `python3 tools/srs_grounds.py`. At commit `b249987`, which this file was written on top of, they report no errors, and three warnings about FR-TOOL-150, FR-TOOL-160 and FR-TOOL-190 that predate this work.
