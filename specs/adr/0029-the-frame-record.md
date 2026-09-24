# ADR-0029 — The frame record is a fixed ring in memory, written at a match's edges and on SIGTERM

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** FR-TOOL-230, FR-TOOL-240, FR-TOOL-250

## Context and problem statement

FR-TOOL-230 asks the game to record every frame's interval, the time of each phase of its own step and the events in it; FR-TOOL-240 asks for the record in a file the run tool can take; FR-TOOL-250 asks the run tool to name the slowest frames.
The instrument exists to find a spike, so it must not make one: no allocation on a frame, no file written during play.
A run on the device ends with SIGTERM (FR-TOOL-180), and a process that dies of it writes nothing.

## Considered options

1. A ring of fixed size allocated at launch, a frame a value with its phases in a `SIMD4<Double>` and its event counts in a `SIMD8<UInt16>`; the file written at a match's end, on leaving the foreground and on SIGTERM.
2. Frames appended to a growing array, events as a dictionary per frame.
3. A line written to the file every frame, or every second.
4. `os_signpost` intervals read in Instruments.

## Decision outcome

Option 1.
Option 2 allocates on the frame it measures; option 3 writes during play, the very work that stalls a frame; option 4 needs Instruments attached and a person to read it, where FR-TOOL-250 asks the run tool to answer on its own.

### How it works

`FrameRecorder` exists only where the launch environment has `CRAWLCALL_FRAMES=1`; it owns a `FrameRecord` whose ring of `FrameRecording.capacity` frames — ten minutes at 60 a second — is allocated when the recorder is made, and a full ring overwrites its oldest frame and counts it as dropped.
`GameSession.step` times the match's step with `ContinuousClock` ("suitable for high resolution measurements of execution"), `Game.advance` reports its deliberations and their time and the hits on the snake, `place` times the see-through check apart from the rest of the drawing, and `SeeThrough.show` reports the modules that changed their look and those drawn through the hole shader for the first time. The interval is the renderer's own `deltaTime`, unclamped.
Events noted between frames — a match begun — are carried into the next frame; a meal's beginning and end are seen by comparing frames.
The record is written as CSV to `Documents/frames.csv`: in the background from a copy taken at a match's end — the text is built there too, and the copy costs the main thread one copy of the ring's storage when the next frame writes to it — before returning from `sceneDidEnterBackground`, and on SIGTERM. A signal dispatch source "cannot catch signals to prevent termination" (Apple, *Concurrency Programming Guide*), so while the record is on `signal(SIGTERM, SIG_IGN)` sets the default aside, as the guide's own listing does, and the handler writes the file and calls `exit(EXIT_SUCCESS)`.
The run tool launches with the variable where `CRAWLCALL_RECORD` names a file, and after it has closed the app takes `Documents/frames.csv` with `devicectl device copy from --domain-type appDataContainer` and sorts it by interval, numerically.
Invariants, held by `FrameRecordTests`, `StepReportTests` and the runner's self-test: the ring keeps the newest frames in order and numbers them from the first ever recorded; an event lands in exactly one frame; a phase is never negative and the step holds the deliberation; the file is the record as it was when the write was asked for; the record is taken only after the app is gone.
It stops working where the app is killed by SIGKILL — `terminate --kill` — which no process can catch, and where the ring is full, which drops the oldest frames and says so in the frame numbers.

### Consequences

A frame's cost is named by phase and event; a late frame with short phases is the renderer's or the GPU's, not the game's.
The first run on the iPhone 16 Pro recorded 1230 frames in 20 s with one late, at the match's start.
An autopilot for a repeatable route is still to come (Q-250).
