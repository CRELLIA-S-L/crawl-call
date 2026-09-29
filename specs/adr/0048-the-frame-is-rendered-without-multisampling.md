# ADR-0048 — The frame is rendered without multisampling

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** NFR-PERF-010, NFR-PERF-050, FR-VIEW-130

## Context and problem statement

With the ground slabs joined (ADR-0047) a match held sixty frames a second at the phone's steady performance level, and after five minutes it had warmed the phone to `serious` and slipped to 52 by the ninth (2026-09-29, a ten-minute run): the GPU was busy for 14.8 ms of each 16.7 ms frame at the first minute and 17 ms by the ninth.
`RealityView` renders with 4× multisampling unless told otherwise (`RealityViewRenderingEffects.antialiasing`, `AntialiasingMode.multisample4X` or `.none`, iOS 27.0 SDK), at the phone's full 2622 × 1206. The maintainer ruled out lowering the resolution on 2026-09-29.

## Considered options

1. No multisampling.
2. 4× multisampling, as before.

## Decision outcome

Option 1. Measured by the method of `specs/50-verification.md` ("How the work of a frame is measured"), in turns, the same build with and without it: the GPU's work a frame fell from 14.47 and 14.31 ms to 13.33 and 13.29 ms, its load from 85.8 and 85.2 % to 78.5 and 78.0 %; the CPU did not change. At about 460 pixels to the inch, an edge left unsmoothed steps by a pixel the eye barely resolves at the distance a phone is held; the maintainer judges it on the phone.

### Consequences

Thin, high-contrast edges — a wall's top against the floor, a bot's outline against the sand — can crawl by a pixel as the camera moves.
The value is `Rendering.antialiasing`, set on the `RealityView`'s content when the scene is built.
