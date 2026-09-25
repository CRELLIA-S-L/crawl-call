# ADR-0031 — The world around the arena is a named setting of scenery, sized by what the match camera can show

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** FR-MAP-120, FR-MAP-130, FR-MAP-140, IF-GREENHOLM-010, FR-GREENHOLM-010, FR-GREENHOLM-020, FR-GREENHOLM-030, FR-VIEW-020, FR-VIEW-130

## Context and problem statement

Around the arena there was nothing — black on the phone, white in the simulator — and the frame showed it at every edge of the arena and more of it from the balcony.
On 2026-09-24 the maintainer asked for a world around it, chose an island for the first one, and decided that settings will vary — a crater, a spaceship, a forest clearing, a building — and that each is a family of its own with a proper name, since there will be more than one island (`materials/plans/surroundings.md`, Q-270).
The released game's camera angle is frozen (FR-VIEW-010), so the world need not be endless, only larger than all the match camera can show; and on an iPad the window can be any shape (FR-VIEW-210), so how much that is depends on the device.

## Considered options

1. A setting as its own family — a name the map gives in its header, a configuration file of its own, a layout of primitive parts — built beside the map into entities of its own and kept out of `ScenePlan`.
2. Scenery as modules of the kit, placed by the map's grids like walls and crates.
3. One fixed world, drawn around every map alike.

## Decision outcome

Option 1.
Option 2 puts every tree into `ScenePlan.pieces`, and so into what the snake collides with (ADR-0021), what the bots see (ADR-0019) and what is cut open (ADR-0020) — the three things FR-MAP-130 keeps scenery out of — and it makes a map's author draw the island cell by cell, out to water tens of metres from the arena.
Option 3 is what the maintainer ruled out: settings vary by map.

### How it works

**Three layers.** A setting is laid out as parts, each a unit box, cylinder, cone or sphere scaled to a size, in one of three layers: the ground around the arena, the water, and the rim that closes the space in (`Scenery`). The backdrop — the sky — is not a part but the environment the scene is drawn against. The parts are data a test reads; `SceneryBuilder` turns them into entities under a `scenery` entity beside the map's, sharing one mesh per shape and one material per colour, each lit by the scene's ambient light like the arena.

**A setting is named.** The map's header says `setting <name>` (IF-MAP-010); the parser only reads the name, and `Setting.load` refuses a name the game does not provide (`SETTING_UNKNOWN`) and reads the setting's configuration from `config/setting/<name>.json` with the same shape check as every configuration (ADR-0012). A new setting is a new case of `Setting.Name`, a new layout beside `Greenholm`, a new file and a new area of requirements; nothing of the others changes.

**Coverage (FR-MAP-140).** `FrameCoverage` finds where a frame's four corner rays meet flat ground. Every coordinate of that footprint is affine in the drop from the point looked at to the ground and in the frame's aspect, so the extremes are at the ends of their ranges; the pitch is sampled every `Coverage.pitchStep` degrees over the range FR-VIEW-010 allows, not only the shipped pitch, and `Coverage.slack` metres on every side pay for what can lie between samples. The point looked at stays inside the arena's footprint (FR-VIEW-020) at any height between the plan's lowest and highest points. The widest frame is the device's: the screen where the window is the screen, and the screen's long side over the smallest window height `GameWindow.minimumSize` allows where windows resize (`GameWindow.widestAspect`). The water is a slab exactly as large as the resulting rectangle at the water's height. A camera whose frame reaches the horizon could see past any finite world, so the launch refuses it (`SETTING_HORIZON_IN_FRAME`); the free camera of debug mode (FR-TOOL-070) is a testing tool and may see past the world's edge. `PerspectiveCameraComponent.fieldOfViewOrientation` defaults to vertical and `far` to infinity in the iOS 27.0 SDK — the second read off a camera made in the test run — so the frame's vertical angle is the configured one and nothing is clipped short of the water.
Tests check the footprint against the corner rays of the camera entity the game itself places (`SceneView.place`), turned by RealityKit's quaternion, and against the figures the plan derived by hand; every corner of every frame of the range, including pitches between samples and aspects up to the widest, falls inside the covered rectangle; and a rectangle short of the slack by a little misses some corner.

**Nothing in front hides the arena.** Only what stands in the arena's own columns and in front of it — between it and the camera — can hide it: a line from the camera to the arena stays over the arena's columns beside it and over its rows behind it. In front, the line to the near edge falls at the pitch itself when the camera looks at that edge and more steeply from anywhere else it can look, so a thing `gap` metres in front of the arena hides nothing if it is no taller than `gap · tan(lowest pitch)` above the underside of the arena's lowest floor (`FrameCoverage.tallestInFront`). Greenholm places a tree there only if it fits, a shrub in its place if that fits, and nothing otherwise; nothing is placed over the arena. That settles the risk the plan named — trees between the camera and the arena — where the scenery is placed, so scenery never needs cutting open (FR-VIEW-150). A test follows lines from cameras over the whole range to points of the arena through something as tall as allowed and finds none crossing it; a tenth taller, the line to the near edge crosses it.

**Greenholm (FR-GREENHOLM-010).** Grass is the smallest ellipse round the arena grown by a margin, its top at the underside of the arena's lowest floor — `ScenePlan.underside`, not the plan's lowest point, which the blockout's stair reaches three metres below its floor; the first screenshot laid the island there and showed the water's edge in the frame's top corners. A shore ellipse lies lower and wider, the water lower still out to the covered rectangle, and the rim is a ring of trees with shrubs between them, spaced by Ramanujan's perimeter and drawn at scales taken in turn.

**The sky (FR-GREENHOLM-020).** An equirectangular picture, zenith colour fading to the horizon colour at its middle, is made into an `EnvironmentResource` and set as the `RealityView`'s environment with `.skybox` (iOS 18 and later, `_RealityKit_SwiftUI` in the iOS 27.0 SDK). The scene's light stays what FR-VIEW-130 asked for — the one sun and the flat ambient every model receives explicitly through `ImageBasedLightReceiverComponent`. Checked on the simulator on 2026-09-24: the match frame with the skybox and without it were identical in every pixel sampled, 64,875 of them. The match camera never shows the sky; the free camera, which can tilt to 10 degrees below the horizontal (`config/view.json`), looks up into it with the top of its frame 15 degrees above the horizon. The simulator takes no two-finger gestures, so the sky was first seen on the phone.

**What the sky turned out to be, 2026-09-25.** On the phone the sky showed a pale grey-blue, and a probe on the simulator — a build that tilts the free camera to its lowest as the match starts, not kept — found out why:

- The picture set with `.skybox` is what is drawn: painted pure red, the sky was red.
- Its colour space is honoured: painted in linear sRGB rather than device RGB, it drew the same to the third decimal. RealityKit converts the picture itself, so what a picture of this kind needs is the right colours, in whatever space it declares.
- RealityKit tone-maps the whole frame by default, and the curve pulls light, saturated colours towards grey: a blue of about 0.73, 0.83, 0.95 showed as 0.70, 0.78, 0.84.
- `ToneMappingComponent`, new in the iOS 27.0 SDK, set on the camera entity, changes that curve for the frame: `exposure`, and a toe and a shoulder (`toeStrength`, `toeLength`, `shoulderStrength`, `shoulderLength`, `shoulderAngle`). The SDK documents none of it; observed, an exposure of −1 darkens without restoring the colour, and a flat curve restores the sky's colour and washes out the lit scene, which was set by eye under the default curve.
- A colour for the sky is therefore a colour after tone mapping, and a sky that is to look a given colour needs its picture painted for the curve in force; what was chosen is Q-350's.

**Birds (FR-GREENHOLM-030).** A flock in a V crosses the frame at intervals from the configuration, above everything the arena holds. From the match camera a thing that high is seen where the line through it meets the floor, far beyond where it is, so a line fixed over the arena was seen off the frame's top edge on the simulator. A flight is therefore chosen when it starts, from where the camera then looks — the point and its height — and how wide the frame then is: its line is the flock's height above that point over the shipped pitch's tangent towards the camera, spread either side by half the arena's depth shrunk by how many times the camera is higher above the point than above the flock; and its ends are a wingspan outside the frame at the farthest such line, which is that line's depth along the view times the tangent of half the field of view, times the frame's aspect. The flight then holds until it ends. The first build started every flight at the edge of the covered water instead, and on an iPad, where the water is sized for the widest window, a flock never reached the frame within its interval; a test now places the game's camera over the arena at three points and four window shapes on both devices' widest frames and finds every flight's ends out of the frame and its middle in it, reached in time. The birds keep their own clock and fly on through a pause.

### Consequences

A new setting needs no change to the map layer, the view or the match, and a map moves to another setting by one header line.
The world's size follows the device and the arena: on a 13-inch iPad, whose window can be more than seven times as wide as it is tall, the water reaches over a hundred metres to either side of the blockout, at the cost of one slab.
The blockout's arena is no longer surrounded by nothing, so the reason FR-VIEW-020 gives for stopping the camera at the arena's edge — "ground beyond the arena is nothing" — no longer holds; the rule stays, as agreed in the plan, and its rationale says so.
How the island and the birds look — the numbers of `config/setting/greenholm.json` — is judged by eye on the phone (the `D` of FR-GREENHOLM-010, -020 and -030), not by the tests.
