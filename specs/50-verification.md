# Verification

How each verification method is carried out in this project.

| Method | Meaning here |
|---|---|
| `T` — test | Automated test in the repository, path listed in the requirement's `tests` field. Game logic — scoring, witnessing, scheduling, configuration reading, the map tools — is tested headless, without rendering; a test that needs the engine running is a `D`. |
| `D` — demonstration | Manual scenario on the device the requirement names — an iPhone for anything the player sees or touches, the Mac for the macOS scheme — with the steps and the expected observation written in the requirement's rationale or in a scenario file named in its `tests` field. Feel, readability and animation are only ever confirmed this way. |
| `I` — inspection | Reading the code, the configuration, the repository or the map confirms conformance. Map-level `I` requirements (FR-MAP-010, FR-MAP-070, FR-MAP-080) are inspected by the validator's report (FR-TOOL-040); repository-level ones (CON-PUB-*) at the pre-publication review. |
| `A` — analysis | A measurement on the baseline device (`30-nfr.md`, ADR-0015) — or, while none is at hand, on the iPhone 16 Pro the maintainer owns, in which case a bound passes only with a 20 % margin (a frame under 13.3 ms where the requirement says 16.6), since the A18 Pro outruns the baseline's A17 Pro by about that much — in a 4v4 match, never in the simulator; the write-up with the numbers is linked from the requirement's `tests` field. Performance and thermal requirements are always measured over the session length they name, never over five minutes, and by an unattended run — the app driven along a fixed route with the checks' toggles on a timeline, its per-second telemetry pulled from the device afterwards (the spike's `materials/spike/instrument/` is the first such instrument) — so that a number can be reproduced by anyone with the device. |

Implemented or partially implemented requirements with an empty `tests` field appear in `90-traceability.md` under “Requirements without listed tests”, whatever their method — as a reminder to either add the test or record how the check was performed.

Test files may additionally carry `verifies:` annotations — see the Annotations section of `README.md`.

## How the frame rate is measured

A frame-rate claim is only as good as its instrument, and two instruments that look right are not:

- **The engine's own `deltaTime` is not one.** It jitters against the display — 17 to 21 ms while the display held a steady 16.67 ms — so a run reads as if it were missing frames when it is not.
- **`CADisplayLink`'s timestamps are the measure**, and a missed frame is an interval longer than one and a half times the target period of 16.67 ms. The target is fixed, never taken from `CADisplayLink.duration`: on a ProMotion display that property drops to 8.3 ms, which turns honest 60 Hz frames into counted "drops" — 33 of them in one twenty-minute run before the reference was fixed.

The same rule holds for anything measured while a language-model call is running: what NFR-PERF-030 asks about is the interval between displayed frames, not the time some function took.

## What the technical spike verifies

The spike (concept preamble, ADR-0001, `materials/spike/README.md`) is an `A` over three requirements before any of them is built for real: FR-SNAKE-010 and FR-SNAKE-020 over a ramp, a step and a drop, NFR-PERF-020 at the worst case — every bot every frame — and NFR-PERF-030.
Its numbers are recorded as the first `A` write-ups of the project and settle ADR-0001 either way.

## Hypotheses are not verification

A requirement's method says how conformance is confirmed.
Whether the requirement was worth building is a different question, answered by the grounds register (`grounds/`) — a passing test on FR-CMD-060 says the weights are applied, not that a player can tell (H-040).
