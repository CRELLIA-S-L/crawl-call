# ADR-0046 — The frame is budgeted at the phone's sustained GPU clock, and the figures and shrubs are drawn with the game's own shapes

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** NFR-PERF-010, NFR-PERF-050, FR-VIEW-070, FR-VIEW-240, FR-MAP-210, FR-TOOL-230, FR-GREENHOLM-070

## Context and problem statement

On 2026-09-28 the maintainer found the frame rate on the iPhone 16 Pro falling during play, and asked first what caused it, then what caused the GPU to slow, and then what in the game loaded the GPU so.
The frame record (FR-TOOL-230) showed the game's own phases flat at 0.3–0.5 ms a frame. The cause was elsewhere, and finding it took the measurements below; they are kept here because the next person to see the frame rate fall will need the same method and the same numbers.

### How it was measured

- **The GPU's time a frame**: Metal's performance HUD, switched on at launch with `MTL_HUD_ENABLED=1` and read off screenshots taken by `devicectl`. Instruments could not attach to the phone over the network.
- **The GPU's clock**: a probe built for the investigation and removed after it — a fixed compute kernel dispatched every half second, timed by the command buffer's `gpuStartTime` and `gpuEndTime`, beside a fixed loop on the CPU. The same work taking longer is the clock running slower. Under a saturated GPU the probe waits behind the frame and reads long, so its absolute numbers after the drop are an upper bound.
- **What each part costs**: a build with launch switches that took one part of the scene away at a time. Each run started from a phone left to cool for two and a half minutes, because a warm phone's GPU is slower and swamped every difference at first — the thermal column of the frame record, added for this, showed it.

### What was found

1. **The drop is the phone moving from its burst clock to its sustained one.** About twenty seconds after heavy rendering begins, the GPU's clock falls to between a half and a third of its peak while the CPU's does not move. `ProcessInfo.thermalState` stays `nominal` through it and reaches `fair` from five to thirty seconds later. The twenty seconds are counted from the load, not from launch: with the scene hidden for its first thirty seconds, the drop came at fifty. Idle, the GPU's clock sits lower still — the probe read 515 µs against 130–170 µs under load.
2. **Nothing switches on at twenty seconds.** The birds' first flight is at fourteen; without the birds, without shots and with the bots held still, the drop came at the same time.
3. **After the drop the frame no longer fits.** At its peak clock the scene took 11 ms of GPU a frame; at the sustained clock it took 19–20 ms, and the frames came 16.7, 20.8 and 29.2 ms apart — about 44 a second, missed vsyncs on a 120 Hz panel, the "micro stutter" of WWDC18 612. A lighter scene of 8.4 ms at peak slowed to 11.2 ms and held sixty.
4. **Where the GPU's time goes**, at peak clock on a cool phone, from a total of about 11 ms:

   | Part taken away | GPU saved a frame |
   |---|---|
   | The water's waves, before ADR-0045 | 3.6 ms |
   | The bots' figures | 1.4–1.7 ms |
   | The arena's modules | 1.7 ms |
   | The sun's shadows | 1.5 ms |
   | The water | 1.5 ms |
   | Multisampling (4×) | 1.5 ms |
   | The floor under the water | 1.0 ms |
   | High dynamic range | 0.4 ms |
   | The island's ground and trees, the birds, the shots | nothing measurable |

   An empty scene, the camera alone, took 2.0 ms. The arena's 714 floor and ground slabs cost nothing measurable in draws: drawn as instances they were no cheaper, and not drawn at all the frame was no cheaper either. The time is in the pixels — lit, shadowed, blended and multisampled at 2622 × 1206 — not in the number of objects.
5. **Two things were far out of proportion, and both were ours.** The waves (ADR-0045). And the eight bots: their figures were built from RealityKit's `generateBox(cornerRadius:)`, 13 068 triangles a part at any size, and `generateSphere`, 8064, which made 1 137 688 of the scene's 1 404 118 triangles, drawn twice with the shadow pass. The shrubs were the same sphere, 96 768 more. Q-420 and Q-450 had asked about both.

### What Apple and others say

- The `com.apple.developer.sustained-execution` entitlement (iOS 17+) "tells the system to maintain a consistent performance state over your app's lifecycle": "the system avoids letting your app run higher performance levels for a period of time, which avoids transitions to other levels later on" (Apple Developer Documentation, the entitlement's page). WWDC25 209 and the Meet with Apple session "Explore power, performance, and scale for games on iPhone and iPad" describe it as limiting a game to the steady state from launch; the latter lists marking the app as a game first, which enables Game Mode, and this mode next.
- WWDC18 612: design for sustained performance; hold thirty if sixty cannot be held for ten minutes.
- RealityKit's "Reducing GPU utilization in your RealityKit app": transparency runs the fragment shader once a layer, shadows and lights add fragment work, fewer polygons help most where there are shadows. `RealityView` gives no control of the frame rate or of the render resolution; `ARView` has a content scale factor, and `RealityRenderer` hands both to the caller.
- No Apple document states how long the burst lasts or that the clock falls before the thermal state changes; that is what this investigation measured, not what it read.

## Considered options

1. The figures and shrubs drawn with the game's own shapes: the extruded rounded box of ADR-0037 at the figure's own radii, and the game's sphere of FR-VIEW-260.
2. The sun's shadow cast only by what shows it — not by the slabs of the lowest level or the water.
3. The arena's slabs drawn as instances (`MeshInstancesComponent`).
4. The sustained-execution entitlement.
5. A lower render resolution.
6. Multisampling off; Game Mode on.

## Decision outcome

Option 1: the frame is 1.4 ms of GPU lighter at peak, 9.7 ms against 11.1, and the figures and shrubs look as they did — the figure keeps each part's radius up to just under half the part's smallest side. The eight figures are 28 504 triangles, the dozen shrubs 3 456.
Option 4 is in the build: the entitlement is signed and in the provisioning profile. Alone it changed nothing measured — the burst and the drop came as before — which fits Apple's order of marking the game as a game first; it is kept for the Game Mode step, which will show whether it takes effect.
It did, on 2026-09-29: with the app also marked as a game — `LSApplicationCategoryType` `public.app-category.games` and `LSSupportsGameMode` in the Info.plist — the phone ran at a steady level from launch, 35–39 frames a second with the scene of that day and no drop at twenty seconds; Game Mode without the entitlement changed nothing either. Both are kept: the steady level is the one a match lives at, and a build is judged there from its first second.
Option 2 saved about 0.1 ms, inside the noise, and the first attempt at it took the island's shadow off the shallows; it was taken back. Option 3 saved nothing, for the reason in finding 4.
Option 5 the maintainer ruled out on 2026-09-29. Option 6 the maintainer set aside, to be done last and on its own; Game Mode came in with the entitlement, as above.

### Consequences

The frame is still above what the phone holds at sixty once its clock drops: 9.7 ms at peak against the 8.4 ms that held. The budget a scene is judged by is the sustained clock's, and a frame measured in its first twenty seconds overstates what the phone gives it.
A thermal ladder keyed on `thermalState` would come too late for this drop, which happens while the state is still `nominal`.
The launch switches and the probe are gone; the method is here, and the thermal column stays in the frame record.
