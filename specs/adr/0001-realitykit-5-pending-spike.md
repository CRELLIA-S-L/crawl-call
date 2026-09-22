# ADR-0001 — RealityKit 5 is the engine, pending the technical spike

- **Status:** proposed
- **Date:** 2026-09-21
- **Related requirements:** FR-SNAKE-010, FR-SNAKE-020, FR-MAP-020, FR-TOOL-050, NFR-PERF-010, NFR-PERF-030, CON-PUB-010

## Context and problem statement

The game needs pathfinding for eight bots and a steerable snake, a procedurally rebuilt tail mesh every frame, an entity-component structure for the three-tier AI, and on-device language-model calls from the same process as the game loop — on iPhone, in one code base for every Apple platform.
A year ago RealityKit had no navigation; RealityKit 5 (WWDC26) added it, which removes the main argument against.

## Considered options

1. RealityKit 5 — native, ECS, `LowLevelMesh` for the tail, a kinematic character controller, Foundation Models in-process, one build for iOS/iPadOS/macOS/tvOS/visionOS.
2. SwiftGodot — Swift bindings to Godot 4 via GDExtension; mature engine, all logic in Swift, direct Core AI access; non-native rendering and bindings kept by a small team.
3. SceneKit — wound down by Apple.
4. Unity — vendor lock-in the project does not want.
5. A custom Metal engine — half a year to reach what option 1 ships.

## Decision outcome

Option 1, on the assumption that a two-to-three-day spike passes three checks: (1) a spline snake through `LowLevelMesh`, its head a character controller steered by the player, crossing a ramp, a step and a drop, looks and feels right — originally "crawling a navmesh", redefined by ADR-0016 after the spike found RealityKit's navmesh queries unusable on overlapping floors; (2) eight navmesh entities with utility-AI action choice fit the frame on a real iPhone at the worst case, every bot every frame; (3) one Foundation Models call beside rendering neither drops the frame nor heats the device unduly.
All three green — this ADR becomes *accepted*.
Check 1 or 3 fails — option 2, at the cost of three days rather than six months, and this ADR is superseded.

### Consequences

Easier: no runtime bridges, one build, the editor (Reality Composer Pro 3) is Apple's.
Harder: RealityKit 5 shipped in June 2026 and is absent from coding agents' training data, so SDK documentation is supplied to them by hand; the ecosystem is thin — no character controllers, no asset store, everything is written; profiling for games is weaker than Unity's; devices without Apple Intelligence are out (ADR-0015).
The toolchain is Xcode 27 with the iOS 27 SDK, the minimum the project supports (CON-PUB-120); the concept's "Xcode 18" was a guess from independent sources, settled by the maintainer on 2026-09-22.
