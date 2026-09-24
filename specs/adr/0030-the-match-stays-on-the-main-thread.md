# ADR-0030 — The match's work stays on the main thread until a record shows it cannot

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** NFR-PERF-010, NFR-PERF-020, NFR-PERF-030, FR-TOOL-230

## Context and problem statement

The game's own step — the match, the bots' deliberation, the see-through check and the update of what is drawn — runs in `SceneEvents.Update` on the main thread, and RealityKit's entities may only be changed there.
On 2026-09-24, after the freezes behind a long snake were removed (ADR-0028), the maintainer still saw one on the phone and asked whether the rendering should stay on the main thread and the calculations move to one of their own, the more so as the commanders' calls to the language model are still to come.
One spike seen by eye names no cause: it could have been the game's step, or the renderer's own work — a shader pipeline built on first use, a material swapped on many modules — which a second thread for the game would not touch.

## Considered options

1. Move the match's step to an actor of its own with a fixed step, the main thread only applying the latest snapshot to the entities.
2. Measure first with the frame record (FR-TOOL-230), and move only what the record shows to be too long.

## Decision outcome

Option 2, and on its first measurement nothing moves.
Three minutes of the maintainer's own play on the iPhone 16 Pro on 2026-09-24, the Debug build with the record on: 10 877 frames, two late, both in the first half second as the match began, at about 34.5 ms — one skipped frame each; after that no interval longer than 20.2 ms. The game's own work at its worst in any frame: the step 2.3 ms, of it deliberation 1.7 ms; the see-through check 1.5 ms; the update of what is drawn 3.1 ms — against a frame of 16.7 ms. In those three minutes the snake ate seven bots, took 112 hits, and 119 modules were cut open by the hole shader for the first time; none of it fell on a late frame. The maintainer played it and saw no freeze.
Option 1 would buy frames nobody is short of, at a price paid on every frame thereafter: the picture a frame behind the match, the player's input carried across to another thread, and the concurrency checking the project runs at `minimal` raised to catch what sharing the match between threads can get wrong.

### How it works

Nothing changes in the code: `GameSession.step` advances the match and places what is drawn in the same call, on the main thread.
The decision is held by measurement rather than by a test: a run with `CRAWLCALL_RECORD` (FR-TOOL-250) names the slowest frames and what each phase of the step cost in them.
It stops holding when a record shows a late frame whose own phases are long — the game's work, not the renderer's — or when the commanders' language-model calls (NFR-PERF-030) arrive: those are asynchronous by the framework's own API and do not block the main thread by themselves, but building a state for the model and applying its answer are work of the match's that the record will then have to show within budget.

### Consequences

The next measurement of note is the same run with the commanders in; the decision is reopened on its result.
NFR-PERF-020's half a millisecond for deliberation in a frame is still exceeded at worst (1.7 ms here), and slots are still handed out by count rather than by time; the requirement stays deferred and is the first thing to build if the record ever shows deliberation on a late frame.
