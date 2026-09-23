# §2. Overall description

## 2.1 Product perspective

A standalone, paid app in the App Store with open source code (MIT, same as SRS-DD).
The seller and rights holder is the company behind SRS-DD.
One code base targets iOS, iPadOS and macOS; iPhone is the primary target from day one, the Mac is the development environment.

Three sides share the arena: the snake (the player) and two bot squads at war with each other.
The strategic layer follows from that: while the squads fight, the snake picks off the exposed; if one squad wipes the other, the survivors turn on the snake as a group.
Greed is punished by the situation, not by rules.

## 2.2 User classes

- **The player** — steers the snake from a fixed-angle camera above; on iPhone by touch, on macOS by keyboard and mouse. There is one player.
- **The maintainer / level designer** — writes maps as text specifications, runs the debug build to crawl them, records playtest results.
- **Contributors** — build from source; need a bundle ID of their own (the repository ships a placeholder `Signing.example.xcconfig`).

## 2.3 Operating environment

- Platforms: iOS 27+ / macOS 27+ on devices with Apple Intelligence — iPhone 15 Pro and later, Apple silicon Macs (ADR-0015); everything older is out.
- Engine: RealityKit 5 (iOS 27 / macOS 27 SDK) — ECS, `LowLevelMesh` for the per-frame tail mesh. Its character controller is not used — the snake's head is steered over the map's own geometry (ADR-0021) — and neither is its navigation mesh: the bots path over a graph derived from the map grid (ADR-0016).
- On-device language model: the system Foundation Models (AFM 3 Core, 3B) via guided generation; a custom Core AI model only if measurements force it.
- Level editor: Reality Composer Pro 3.
- Fallback stack if the technical spike fails: SwiftGodot (Godot 4 through GDExtension, all logic in Swift).
- Tooling: Python ≥ 3.9 standard library (SRS-DD), Blender with Python for concept renders and possibly USDZ generation (`materials/render/`).

## 2.4 Assumptions and dependencies

- **The technical spike passed on 2026-09-22** (`materials/spike/README.md`, ADR-0001 accepted): a steered snake with a `LowLevelMesh` tail over a ramp, a step and a drop; eight bots deliberating every frame at 60 fps on an iPhone 16 Pro; 121 commander calls in twenty minutes with no failure and no frame missed while an inference ran. Its first form, on RealityKit's navigation mesh, was abandoned along the way (ADR-0016), and the fallback to SwiftGodot is no longer on the table.
- RealityKit 5 shipped in June 2026 and is absent from the training data of coding agents; current SDK documentation has to be supplied to them by hand.
- Toolchain: Xcode 27 with the iOS 27 / macOS 27 SDK is the minimum supported version (CON-PUB-120); the concept's "Xcode 18" came from independent sources and was wrong.
- Thermal throttling on iPhone shows only on sessions of 10–15 minutes and longer; every performance claim is measured on a real device over a long session.
- App Store treats runtime-generated speech as user-generated content (guideline 1.2): bot speech passes a content filter set to the 13+ rating (ADR-0014).
- The working title has not passed a trademark search (classes 9 and 41, EU first); it is used in the repository, code and identifiers only.
