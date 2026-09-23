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

## What a run on the device is watched with

A run on a real device is not watched over somebody's shoulder. The machine driving it attaches to the phone and takes what it needs off it, and a judgement that names no artefact is an opinion:

- **A `D` judgement is recorded with the frame that shows it.** `xcrun devicectl device capture screenshot --device <id> --destination <path>` for a still, `… capture screen-record …` for a stretch of play. "The tail lies on the ramp" is worth what the image beside it is worth.
- **Telemetry is pulled from the app's container afterwards**, not read aloud from the screen: `xcrun devicectl device copy from --device <id> --domain-type appDataContainer …`, which is how the spike's per-second CSV came back (`materials/spike/instrument/`).
- **The console of a run is kept**, because a launch that failed says so there and nowhere else.

This is the ordinary way to check a result, not a debugging measure of last resort: it is what makes a reading reproducible by somebody who was not in the room, which is what the `A` method above asks for. Attaching to the device and capturing from it needs the maintainer's confirmation each time, like any run (ART-030), and what is captured goes to the write-up rather than into the repository unless a requirement names it.

## Every run ends with the app closed

A run is over when the app is terminated on the device, not when the numbers have been read. Whoever started it closes it — a person by hand, a script as its last step before it reports, which FR-TOOL-180 requires of the tool.
`xcrun devicectl device process terminate --device <id> --pid <pid>` is how: it sends SIGTERM, which the app may handle, and it ends the way it would if the player left it. Its `--kill` flag sends SIGKILL instead, which the process cannot handle — that is the one to avoid, and the run confirms the app is gone rather than assuming it. On 2026-09-22 a process of the app was found running on the device after a SIGKILL had reported success and the listing had shown none, with no run since that had launched it; what put it there was never established, which is reason enough to end a run by the verb meant for it and to look afterwards.

The reason is the next measurement rather than tidiness. NFR-PERF-010 asks for 60 frames per second *cold*, and thermal requirements are read against a device that started cool (NFR-PERF-050, NFR-PERF-060): an app left rendering in the background keeps the GPU busy and the device warm, so the following run begins somewhere in the middle of its own thermal curve and reports a number nobody can reproduce. An inference left running warms the device the same way rendering does, so a run with a commander in it is closed no differently.

This holds for every run — a two-minute check by eye as much as a twenty-minute unattended one — and for runs that failed or were interrupted, which are the ones most likely to be left behind.

## A run is timed, and a run that takes longer than usual is a finding

Every run is measured — the tests, and the command that launches them — and the time is read, not just the verdict. A suite that passes in nine minutes where it passed in twenty-five seconds has told you something, and waiting for it to finish is a way of not hearing it.

What the numbers are here, so that a departure is recognisable, measured on 2026-09-22 with 138 tests: building the test target takes 2 to 8 seconds against warm derived data and about 14 from empty, the run phase takes 8 to 10, and the tests themselves 1.5 of those. `/usr/bin/time -p` in front of the command, and `IDETestOperationsObserverDebug: N elapsed` in the log, are where those come from.
A baseline is only useful while it is current: the suite took 5.6 seconds earlier the same day with eleven fewer tests in it, and what moved it was one change — the scene's materials being made once per module type rather than once per piece — which is exactly the kind of thing this section exists to notice, in the direction nobody complains about.
The phases are run apart for that reason, which is the next section.

When a run departs from that, the first questions are cheap and they are about the run rather than the code: is the process using a processor or waiting on something, is a compiler under it at all, and which device did the destination actually resolve to. On 2026-09-22 a run sat for nine minutes at no output; it was not compiling — no `swift-frontend` was running — and it was reported as contention with another project before anything had established that. The watchdog settled it three stalls later: the suite had finished, printed its counts and its verdict, and `xcodebuild` then sat blocked at no processor until something killed it. The result had been ready in five seconds and was being waited away. What the evidence did show was that simulator names are not unique: this machine carries two devices called `iPhone 17 Pro` and two called `iPhone 17 Pro Max`, one of them unavailable for want of a runtime profile, and the run had been addressed by name.

So: address a simulator by its identifier, not its name; boot it before the run so that its time is its own and not hidden inside the run's; and when the time is wrong, find out why before running it again, because a second run is the slowest possible way to ask the same question.

## A test run is three commands, not one

The automated tests are run by `scripts/run-tests.sh`, which does the three phases below, each under a watchdog (FR-TOOL-190), and prints what each one took:

1. `xcrun simctl boot <id>` — the simulator is booted before the run and addressed by its identifier. Names on a machine are not unique: this one carries two devices called `iPhone 17 Pro` and two called `iPhone 17 Pro Max`, one of them unavailable for want of a runtime profile, so a destination given by name is a destination somebody else chose.
2. `xcodebuild … -destination "id=<id>" build-for-testing` — compiles the app and the test bundle, needing no device.
3. `xcodebuild … -destination "id=<id>" test-without-building` — installs, launches and runs.

The single `test` action does all three and reports one number for them, which is why it is not used here. On 2026-09-22 it sat repeatedly for minutes with no output and no compiler under it; the phases run apart so that a stall says which of the three it is in, and that is how this one was pinned down — it is after the tests, in `xcodebuild`'s own exit, with the verdict already printed. A phase is therefore ended on its own report rather than on its process (FR-TOOL-190). The split is also faster to work in: step 2 answers in seconds, so a compile error is found without touching a simulator at all.

A clean run — caches cleared, built from scratch — is still made before anything is called stable, and it is made the same way, by the same script with its derived data removed first.

## Geometry is compared with a tolerance, never for equality

A test that checks a position, a size, an orientation or anything derived from them compares within a tolerance. Exact equality on a floating-point number is a test that fails for a reason that has nothing to do with the behaviour under test, and it fails later rather than sooner — when a constant changes, when the arithmetic is reordered, when the same value arrives by a different route.

Both halves of that have already happened here:

- a test keyed pieces by `"\(x),\(y),\(z)"` to find what a wall stands on, and three walls of ninety-three "stood on nothing" because `1.49 - 1.5 + 0.01` is `1.39e-17` and not `0`;
- a test asserted that a camera's right vector equals `(1, 0, 0)` and got `(0.99999994, 0, 0)` — the same direction, a different representation.

Neither was a defect in the game. Both cost a run and read, for a moment, like one.

So: `XCTAssertEqual(_:_:accuracy:)` for a number, a component-by-component comparison for a vector, and a named epsilon where a test needs its own. Where a test really does mean "the same value", it compares integers — a cell index, a count, a floor number — and those the grid has in abundance.

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
