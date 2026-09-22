# ADR-0018 — iOS and macOS now, visionOS deferred, tvOS closed by the model

- **Status:** accepted
- **Date:** 2026-09-22
- **Related requirements:** CON-PUB-010, FR-VIEW-010, FR-VIEW-020, FR-VIEW-030, FR-VIEW-040

## Context and problem statement

CON-PUB-010 names iOS and macOS, taken from the concept's preamble, and nothing in the repository says why tvOS and visionOS are absent.
"One code base for every Apple platform" reads as an invitation, so the question comes back every time somebody counts the platforms the engine supports, and it came back on 2026-09-22.
RealityKit runs on all four, which is the half of the answer that is easy to see; what each platform does or does not carry underneath is the half that decides.
watchOS is not in the question: it carries `FoundationModels` from 27.0 but no RealityKit at all, so there is nothing to render with.

The availability of the four pieces the game is built on, read from Apple's documentation on 2026-09-22:

| | FoundationModels | RealityKit | `LowLevelMesh` | `CharacterControllerComponent` |
|---|---|---|---|---|
| iOS / iPadOS | 26.0 | 13.0 | 18.0 | 15.0 |
| macOS | 26.0 | 10.15 | 15.0 | 12.0 |
| visionOS | 26.0 | 1.0 | 2.0 | available, no version stated |
| tvOS | **absent** | 26.0 | 26.0 | 26.0 |

## Considered options

1. iOS and macOS only, as today.
2. Add tvOS: the engine is there, the system language model is not.
3. Add visionOS: everything is there, but the camera and the input are somebody else's.
4. All four, with the model made optional where it is missing.

## Decision outcome

**Option 1, and the other three are written down rather than left to be rediscovered.**

**tvOS is closed, and not by effort.** `FoundationModels` is not available there at all, so a tvOS build has no commanders and no generated speech.
ADR-0015 already decided this exact case when it put the floor at the iPhone 15 Pro instead of the iPhone 11: a build that cannot run the model is a different game, and the commanders and the voices are the product (H-040, H-050).
Option 4 is option 2 wearing a coat — it ships that different game under the same name.
Two things would re-open it, and only two: Apple bringing `FoundationModels` to tvOS, or the project taking ADR-0008's second option — a small model shipped with the app through Core AI, which the concept names in §10 and which does not depend on the system model being present.
Core AI is on every Apple platform from 27.0, tvOS and watchOS included, so that route is not the one that closes the door.
ADR-0008 holds that option in reserve for the case where the system model fails its measurements, not for the case where a platform lacks it, so nothing here anticipates the switch; it is named so that a reader who takes it knows this decision changes with it.
Until one of the two happens no amount of input work changes the answer, and input work would be needed too, since a virtual joystick has no touch screen to live on.

**visionOS is deferred, and not by capability.** Every API the spike leaned on is there, the system model included.
What is not there is the game: the camera is a perspective one pitched 50 to 60 degrees above the snake and following its head (FR-VIEW-010, FR-VIEW-020), and on visionOS the camera is the player's head.
The input is a virtual joystick, and there it would be hands and gaze — a third scheme beside FR-VIEW-040's keyboard and mouse, though a cheaper one than it sounds, because the game logic consumes intents rather than device events (FR-VIEW-030) and a scheme is a translation layer.
The camera is the expensive half, and it is expensive because it is a design question rather than a port — a second design, proposed before the first one has answered H-010.
It re-opens when the stage-2 build exists and the question is worth asking with something in hand.

### Consequences

CON-PUB-010 stays as it is; no requirement changes, which is the point.
The table above is the record: a platform question is answered by re-reading it and checking the dates, not by re-deriving it.
Accepted knowingly: the reading is of one moment — Apple ships frameworks with OS releases, so a platform that gains `FoundationModels` later gains a claim on this decision, and the same is true in reverse for anything the game starts depending on.
