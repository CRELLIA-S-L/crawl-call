# Verification

How each verification method is carried out in this project.

| Method | Meaning here |
|---|---|
| `T` — test | Automated test in the repository, path listed in the requirement's `tests` field. Game logic — scoring, witnessing, scheduling, configuration reading, the map tools — is tested headless, without rendering; a test that needs the engine running is a `D`. |
| `D` — demonstration | Manual scenario on the device the requirement names — an iPhone for anything the player sees or touches, the Mac for the macOS scheme — with the steps and the expected observation written in the requirement's rationale or in a scenario file named in its `tests` field. Feel, readability and animation are only ever confirmed this way. |
| `I` — inspection | Reading the code, the configuration, the repository or the map confirms conformance. Map-level `I` requirements (FR-MAP-010, FR-MAP-070, FR-MAP-080) are inspected by the validator's report (FR-TOOL-040); repository-level ones (CON-PUB-*) at the pre-publication review. |
| `A` — analysis | A measurement on the baseline device (`30-nfr.md`, ADR-0015) — or, while none is at hand, on the iPhone 16 Pro the maintainer owns, in which case a bound passes only with a 20 % margin (a frame under 13.3 ms where the requirement says 16.6), since the A18 Pro outruns the baseline's A17 Pro by about that much — in a 4v4 match, never in the simulator; the write-up with the numbers is linked from the requirement's `tests` field. Performance and thermal requirements are always measured over the session length they name, never over five minutes, and by an unattended run — the app driven along a fixed route with the checks' toggles on a timeline, its per-second telemetry pulled from the device afterwards (the spike's `materials/spike/instrument/` is the first such instrument) — so that a number can be reproduced by anyone with the device. |

Implemented or partially implemented requirements with an empty `tests` field appear in `90-traceability.md` under “Requirements without listed tests”, whatever their method — as a reminder to either add the test or record how the check was performed.

Test files may additionally carry `verifies:` annotations — a suite that verifies a requirement as a whole says `file verifies:` in its header, and a block over one suite of several ends with `srs-end:` where that suite closes (ADR-0070); the rules are the Annotations section of `srs-dd/standard.md`.

## A change goes on the phone before it is called done

Where a device is connected, a change the build can see — code, configuration, a map, an asset, the project file — is built and installed on it and looked at, and that happens after the suite is green and before the change is reported as finished.
It is not asked for and not waited for; ART-030 says so since 2026-10-11, and this section is how that article is carried out. The suite that comes before it is run on the same terms: when a change is finished, rather than when somebody asks.

A change the build cannot see — a requirement, a decision record, a plan, this document — leaves the app byte for byte identical, and installing it would prove nothing. Those are reported without a device run, saying so.

What the install is for decides what to look at. A change to what the player sees is looked at on the screen and recorded with the frame that shows it; a change to what the game does is driven to the behaviour it changed; a change that is meant to cost less is measured, over the session length the requirement names, by the unattended route rather than by eye. In all three the artefact goes into the report, because a judgement that names none is an opinion (above).

The simulator does not stand in for this. It runs the logic and it draws the scene, and it answers nothing about the frame rate, the heat, or how a thing reads at arm's length on a screen held in the hand — the three questions this game's non-functional requirements are made of (NFR-PERF-010, NFR-PERF-050) — so a change judged only there is a change judged on the wrong machine. The suite on the simulator says the logic still holds; the phone says whether the change was any good.

Where no device is connected, the change is finished, reported with the suite's result, and the report says that it has not been on a phone. That is a statement about the work, not a hedge: the next session installs it.

## What a run on the device is watched with

A run on a real device is not watched over somebody's shoulder. The machine driving it attaches to the phone and takes what it needs off it, and a judgement that names no artefact is an opinion:

- **A `D` judgement is recorded with the frame that shows it.** `xcrun devicectl device capture screenshot --device <id> --destination <path>` for a still, `… capture screen-record …` for a stretch of play. "The tail lies on the ramp" is worth what the image beside it is worth.
- **Telemetry is pulled from the app's container afterwards**, not read aloud from the screen: `xcrun devicectl device copy from --device <id> --domain-type appDataContainer …`, which is how the spike's per-second CSV came back (`materials/spike/instrument/`).
- **The console of a run is kept**, because a launch that failed says so there and nowhere else.

This is the ordinary way to check a result, not a debugging measure of last resort: it is what makes a reading reproducible by somebody who was not in the room, which is what the `A` method above asks for. Attaching to the device, installing on it and capturing from it needs no confirmation and is not waited for (ART-030, amended 2026-10-11), and what is captured goes to the write-up rather than into the repository unless a requirement names it.

## Every run ends with the app closed

A run is over when the app is terminated on the device, not when the numbers have been read. Whoever started it closes it — a person by hand, a script as its last step before it reports, which FR-TOOL-180 requires of the tool.
`CRAWLCALL_DEVICE=<id> sh scripts/run-on-device.sh <app> [screenshot]` is that script — with `CRAWLCALL_RECORD=<file>` it also switches the app's frame record on, takes the record off the device once the app has written it on its way out, and names the slowest frames (FR-TOOL-230, FR-TOOL-240, FR-TOOL-250): it installs, launches, waits, captures if it was asked to, and closes — on the way out as well as at the end, so a run that stopped early closes too. The device is given to it by the environment because the repository carries no device identifier — a standing rule of the maintainer's rather than a requirement, since CON-PUB-040 covers signing identifiers and CON-PUB-060 secrets, and a device is neither.
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
   A booted simulator is not a destination unless its runtime is the one the app is built for: on 2026-09-25 a booted `iPhone 17 Pro` on iOS 26.5 was refused with "Unable to find a destination matching the provided destination specifier", and the list `xcodebuild` prints under that error names the ones it will take, with iOS 27.0 beside them.
2. `xcodebuild … -destination "id=<id>" build-for-testing` — compiles the app and the test bundle, needing no device.
3. `xcodebuild … -destination "id=<id>" test-without-building` — installs, launches and runs.

The single `test` action does all three and reports one number for them, which is why it is not used here. On 2026-09-22 it sat repeatedly for minutes with no output and no compiler under it; the phases run apart so that a stall says which of the three it is in, and that is how this one was pinned down — it is after the tests, in `xcodebuild`'s own exit, with the verdict already printed. A phase is therefore ended on its own report rather than on its process (FR-TOOL-190), and the run's result is read from that report too: whatever the ending, the script prints the build's errors or the count of tests with every failed one named, and exits zero only where all of them passed (FR-TOOL-210). The split is also faster to work in: step 2 answers in seconds, so a compile error is found without touching a simulator at all.

A clean run — caches cleared, built from scratch — is still made before anything is called stable, and it is made the same way, by the same script with its derived data removed first.

## Geometry is compared with a tolerance, never for equality

A test that checks a position, a size, an orientation or anything derived from them compares within a tolerance. Exact equality on a floating-point number is a test that fails for a reason that has nothing to do with the behaviour under test, and it fails later rather than sooner — when a constant changes, when the arithmetic is reordered, when the same value arrives by a different route.

Both halves of that have already happened here:

- a test keyed pieces by `"\(x),\(y),\(z)"` to find what a wall stands on, and three walls of ninety-three "stood on nothing" because `1.49 - 1.5 + 0.01` is `1.39e-17` and not `0`;
- a test asserted that a camera's right vector equals `(1, 0, 0)` and got `(0.99999994, 0, 0)` — the same direction, a different representation.

Neither was a defect in the game. Both cost a run and read, for a moment, like one.

So: `XCTAssertEqual(_:_:accuracy:)` for a number, a component-by-component comparison for a vector, and a named epsilon where a test needs its own. Where a test really does mean "the same value", it compares integers — a cell index, a count, a floor number — and those the grid has in abundance.

## A test that fails reports a failure, never a crash

Whatever goes wrong in a test's own code — a fixture that will not load, a value that is not there, an error it did not expect — is reported as that test's failure. A crash ends the run, not the test: on 2026-09-25 a fixture that could no longer load the map took the test process down, and the run ended at its watchdog's limit with no count of the suite and no name for the test that failed — and macOS offered to report the crash to Apple.

A crash of the game's own code under test is different: it is a defect of the game, and the crash is how it is found.

So: a fixture is loaded where an error can fail the test — `setUpWithError`, a throwing test, `XCTUnwrap` — and never with `try!` or a forced unwrap.
An element of a collection is taken with `element(_:of:)`, or `checkedIndex(_:of:)` where the test changes it (`Tests/CrawlCallTests/TestSupport.swift`), and never by a subscript of a number: a missing one then fails the test and says which it was and how many there were. A dictionary keyed by numbers is looked up by a named key. A subscript by a variable is safe where the variable walks the collection's own indices; where the index comes from the code under test, it goes through the same helpers.
`TestHygieneTests` reads the suite's source and fails on any `try!`, `as!`, forced unwrap or subscript by a number, naming the file and the line, so the rule holds without anybody having to remember it.

## How the frame rate is measured

A frame-rate claim is only as good as its instrument, and two instruments that look right are not:

- **The engine's own `deltaTime` is not one.** It jitters against the display — 17 to 21 ms while the display held a steady 16.67 ms — so a run reads as if it were missing frames when it is not.
- **`CADisplayLink`'s timestamps are the measure**, and a missed frame is an interval longer than one and a half times the target period of 16.67 ms. The target is fixed, never taken from `CADisplayLink.duration`: on a ProMotion display that property drops to 8.3 ms, which turns honest 60 Hz frames into counted "drops" — 33 of them in one twenty-minute run before the reference was fixed.

The same rule holds for anything measured while a language-model call is running: what NFR-PERF-030 asks about is the interval between displayed frames, not the time some function took.

A frame record is a measurement only of the run it came from, and three things make a run's numbers mean something other than they seem, all met on 2026-09-25:

- **A change is priced against a run without it, made the same way.** RealityKit's rounded box showed 387 frames in a ten-second run, 201 of them late; that meant something only beside the 673 frames, 2 late, of the same build without the change, run straight after on the same phone for the same ten seconds of watching (ADR-0037). A number with nothing beside it is a number, not a cost.
- **A run the phone was used in is not a measurement.** Two runs came back from a phone that was in use while they ran: in one the free camera had been moved off the snake, in the other the app had left the screen — its screenshot showed the home screen and its record stopped at 6.8 s of the ten. The screenshot and the time of the record's last frame are read before its numbers, and a run whose screenshot is not the match, or whose record ends early, is run again.
- **A phone that has run a dozen builds back to back is warm**, and a warm phone slows itself (NFR-PERF-050). A run meant to price something is made cold, or said to be warm.

The record's first frame is read too: it is the time from launch to a match on screen, and it moved from 0.48–0.58 s to 0.97–1.57 s when the water got its shaders (Q-440).

## How the work of a frame is measured

Once a match holds sixty frames a second, the frame rate says nothing more: it stands at the display's ceiling whatever the frame costs, and a cheaper frame shows only as the phone running longer before it heats. Nor is the GPU time the Metal performance HUD shows a measure of work: the system sets the GPU's clock to the load, so a lighter frame can read the same milliseconds at a lower clock, and one screenshot of it differs from the next by a millisecond on the same build (ADR-0046). What a change is priced by is the work of the app's own frames, measured the same way for each build compared:

- **The phone runs at its steady level from launch.** The game carries the `com.apple.developer.sustained-execution` entitlement and is marked as a game with Game Mode (`LSApplicationCategoryType`, `LSSupportsGameMode`); the entitlement took effect only with both (ADR-0046). Without them the first twenty seconds or so run at a burst clock no match keeps.
- **Instruments' Game Performance Overview is the instrument** (WWDC26, "Find and fix performance issues in your Metal games"), recorded from the Mac: `xcrun xctrace record --template 'Game Performance Overview' --device <udid> --time-limit 42s --output <trace> --launch -- <bundle id>`, one trace a build, the variant given by `--env` where one build carries several. Its tables are read with `xcrun xctrace export`: per frame of the app's layer, `metal-perf-overview-layer-per-frame-metric` — `GPU Active Time` and `GPU Usage %` are the GPU's work and load for the app's frames, `CPU Begin to Present` the CPU's time on a frame; per five seconds of the process, `metal-perf-overview-process-metric` — `CPU Instructions/s`, `CPU Cycles`, `User Time`, `System Time`. The window read is the 10th to the 40th second, past the launch.
- **Builds are compared in turns**, A B A B, each run after two and a half minutes of the phone lying still, on a phone left alone beforehand — runs taken soon after an update of iOS, or with the phone in use, fell to twenty frames a second and priced nothing (ADR-0047).
- **The method is trusted when a build repeats itself.** On 2026-09-29 the same build twice gave 14.47 and 14.31 ms of GPU work a frame and 85.8 and 85.2 % GPU load, and without multisampling 13.33 and 13.29 ms and 78.5 and 78.0 %: a difference between builds counts when it is several times the difference within one.

What the other instruments do on iOS 27, found the same day: the Performance Trace control of Control Center fails to produce traces (iOS 27 release notes, 184729556); the RealityKit Frames and RealityKit Metrics instruments of the RealityKit Trace template run only on visionOS; `metalperftrace collect` gathers the Mac's own recording, not a phone's. Where `xctrace` answers "Timed out waiting for device to boot", the phone is opened once in Xcode's Devices and Simulators window, which restored the connection after Xcode had been reinstalled. What a single draw costs is read from a GPU frame capture — `MTLCaptureManager` writing a `.gputrace` from a build made for it, opened in Xcode — which gave the draw counts of ADR-0047.

## What the technical spike verifies

The spike (concept preamble, ADR-0001, `materials/spike/README.md`) is an `A` over three requirements before any of them is built for real: FR-SNAKE-010 and FR-SNAKE-020 over a ramp, a step and a drop, NFR-PERF-020 at the worst case — every bot every frame — and NFR-PERF-030.
Its numbers are recorded as the first `A` write-ups of the project and settle ADR-0001 either way.

## Hypotheses are not verification

A requirement's method says how conformance is confirmed.
Whether the requirement was worth building is a different question, answered by the grounds register (`grounds/`) — a passing test on FR-CMD-060 says the weights are applied, not that a player can tell (H-040).
