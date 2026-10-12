# ADR-0078 — The commander's frames are lost to the clock and not to the code, so the only lever left is the work asked of the model

- **Status:** accepted
- **Date:** 2026-10-12
- **Related requirements:** NFR-PERF-030, NFR-PERF-040, IF-CMD-020, FR-CMD-025, FR-TOOL-250

## Context and problem statement

Q-570 priced the commander on the phone and found a fifth of the frames over budget: 58.4 frames a second without it against 45.7 with it, the median frame unchanged at 16.7 against 16.9 ms, and the app's own work inside a frame under two milliseconds either way.
That left the drop unexplained. The time was going somewhere the app was not running, and "the device is doing the inference" is a direction, not a mechanism — it does not say what to change, and without a mechanism every candidate fix is a guess. Three had already been guessed and had cost a day between them: serialising the two commanders (Q-570), lowering the quality of service (Q-580), and the three levers of Q-590.

The question this decision answers is which of the two possible shapes the loss has. Either the main thread is being kept off the processor — by contention, by a core it was moved to, by work the model adds to the process — in which case there is something in the game's code or its scheduling to change. Or the processor itself is running slower, in which case there is not.

## Considered options

1. Find the cost in the game's code or its scheduling — a thread the inference blocks, an allocation the response provokes, a demotion to an efficiency core — and change that.
2. Take the inference off the main thread or off its actor, which is what had been planned for months.
3. Accept the frames and shrink the work asked of the model: call less often, ask for less, generate fewer tokens.
4. Leave Apple's model for one of our own, run through Core AI, where the compute unit can be chosen.

## Decision outcome

**Option 3, and nothing in the code.** Options 1 and 2 were refuted by measurement rather than rejected by argument: there is no cost in the code to find, and no thread to move the work off. Option 4 was read to the bottom and is not available today without a different game.

**What was ruled out, each by its own measurement, all on the iPhone 16 Pro with thermal state `nominal` throughout.**

| candidate | what refuted it |
|---|---|
| the main thread waiting to be scheduled | System Trace, 40 s: `Runnable` 0.096 s with the model against 0.087 s without |
| the GPU | 59.99 frames a second median in both, GPU Active Time 14.6 against 14.7 ms a frame |
| thermal throttling | `nominal` in every run, in all of them |
| the frame clamp of `Frame.longest` | 0.04 s of 44.6 |
| more deliberation | 12.5 bot deliberations a real second against 12.6 |
| two inferences at once | serialised; 495 frames over budget of 1986 against 481 of 1998 |
| the Debug build | Debug and Release differ by 1.1 frames a second |
| **a demotion to the efficiency cores** | **Time Profiler, from the same two System Trace runs: 87.7 % of the main thread's 14 977 samples on performance cores with the model, 86.7 % of 15 575 without** |
| **new work in the process** | **the same two runs by library: CoreRE 21.1 against 20.7 %, libswiftCore 3.0 against 3.0, libsystem_malloc 1.2 against 1.2, libobjc 0.9 against 0.7** |

The last two are the ones that close option 1. The main thread is on the same cores doing the same mix of work, to tenths of a percent; nothing the model does appears in the process as work.

**What the counters show.** Two 45-second runs under Instruments' CPU Counters template, the shipping build against a control built with `ScriptedCommander` in place of `SystemModelCommander`, main thread, performance cores only:

| | with the model | control |
|---|---|---|
| time in state Running | 11.56 s | 11.93 s |
| cycles a second | **1.770 GHz** | **2.332 GHz** |
| micro-operations a second | 6.95 G | 9.05 G |
| **cycles a micro-operation** | **0.255** | **0.258** |

Cycles per micro-operation are equal to the third decimal. That is the whole finding: the same instruction stream, retiring at the same cost per instruction, with no added stalls and no memory effect — and 24 % fewer cycles arriving a second to run it on. The work done per tick falls by 23 %, which is the frame rate. The clock distribution says the same thing more plainly: the control sits on a single frequency step, 1.943 GHz at the tenth percentile and 1.944 at the median, while the run with the model has a tenth percentile of 1.260 and a median of 1.620.

**Why the clock falls.** The Neural Engine is busy almost all the time the match is running: under the Core AI template, 1 375 intervals labelled `Neural Engine Prediction` averaging 27.7 ms, merging to 38.417 seconds of 44.217 — 87 % — with 1 346 gaps that total 5.8 seconds and only one gap over 200 ms, at the 2.5th second before the match gets going. At a seven-second call interval and answers of 10 to 19 seconds there is nearly always an inference in flight, which is why the loss is a steady 24 % and not a spike every seven seconds. The accelerator and the processor share one power budget on the package; with the accelerator holding it, the performance cores are given lower frequency steps. Thermal state stayed `nominal`, so this is the budget being shared, not the phone protecting itself.

**Why option 4 is not available.** Core AI is a framework for running models the app itself ships: `AIModel`, `AIModelAsset`, `InferenceFunction`, `NDArray`, an `.aimodel` compiled ahead of time by `coreai-build`. It has no handle on the system language model the commander uses. Its one relevant knob — `SpecializationOptions(preferredComputeUnitKind:)`, `.cpuOnly`, `allowedComputeUnitKinds` over `ComputeUnitKind { cpu, gpu, neuralEngine }` — is the only place in any of Apple's frameworks that touches the mechanism above, and it governs a model we would have to bring ourselves. Foundation Models exposes nothing of the kind: a search of the whole installed iOS 27 interface for `computeUnit`, `neuralEngine`, `priority` and `qos` matches nothing.
There is a route — iOS 27 made `LanguageModel` and `LanguageModelExecutor` public protocols, so a model of our own can sit behind the same `LanguageModelSession`, and the game's `Commander` seam (ADR-0077) already makes the swap a one-file change. What it costs is the reason it is not taken: the weights ship in the app, every prompt measurement the project holds is voided because it covers one pairing of instructions, schema, vocabulary and model, Apple's guardrail belongs to Apple's model so the whole blocked-and-refused measurement set loses its subject (CON-CMD-020), and the quality of the answer IF-CMD-020 asks for from a small model is unproven. It would also not remove the mechanism, only shrink it: a smaller model on the accelerator holds the power budget for less of the time.

### How it works

**How a counter run is read**, written down because nothing in the export says any of it. `xcrun xctrace export` gives the table `kdebug-counters-with-time-sample` with `counting-mode="bottleneck bottlenecks EL0"` and twelve unnamed values a sample; the names are not in the trace. The formulas are in `/Applications/Xcode.app/Contents/SharedFrameworks/RecountDT.framework/Versions/A/Resources/Analysis/bottleneck.json`, whose platform entry for `t8140` — the chip in this phone — gives `useful = RETIRE_UOP / slot` with `slot = CORE_ACTIVE_CYCLE * MAP_BW`, `processing = MAP_STALL_NONRECOVERY / CORE_ACTIVE_CYCLE`, `delivery = MAP_DISPATCH_BUBBLE_SLOT / slot` and `discarded = (MAP_UOP - RETIRE_UOP + MAP_RECOVERY * MAP_BW) / slot`. Which column is which is then settled behaviourally: column 0 is the cycle counter because its rate against wall time caps at exactly 4.044 GHz on performance cores and 2.42 GHz on efficiency cores, which are this chip's two maxima.
The ratio is what the conclusion rests on, not the rate. An effective frequency is cycles over elapsed time and could in principle be bent by how the thread is scheduled; cycles per micro-operation cannot, and it is the number that came back unchanged.

**How a trace is recorded on the phone at all.** Two of these templates ask for consent before recording, because they capture prompts and responses, and `xctrace` asks on standard input. A run whose output is redirected hangs at "Starting recording…" with the prompt sitting in a buffer nobody sees, producing a 40 KB bundle that holds only `RunIssues.storedata`, while the app sits on a black screen on the phone. The flag is `--no-prompt`, documented in `xcrun xctrace help record` as skipping the privacy warnings; with it, and with standard input from `/dev/null`, both templates record to completion. Two more things learned the hard way: `--attach` resolves its process on the Mac and never on the device, by pid or by name, so a trace is taken with `--launch`; and `xctrace record` ignores SIGTERM and needs `kill -9`.

**What the Core AI template actually contains**, since `--instrument 'Core AI'` alone produces no rows for this game: the three instruments of the template are the Core AI instrument over the `com.apple.ane` subsystem, a high-frequency Time Profiler, and the Metal GPU instrument. The game uses Foundation Models rather than the Core AI framework, so the signpost instrument sees nothing and the hardware tables — `ane-hw-intervals`, `mps-hw-intervals` — are what carry the measurement. The whole template is recorded, not the instrument.

### Consequences

**NFR-PERF-030 cannot be met by anything written in this repository while the commander asks what it asks.** The frames are not recoverable in the code, and the planned move of the inference to a thread or an actor of its own — long deferred, and the thing to do next on every earlier reading — would buy nothing: the main thread is not waiting on it. That plan is closed by this decision rather than postponed.

**What is left is the size of the request**, which puts the whole weight on the decision Q-570 is still waiting for: the shape of the answer IF-CMD-020 asks for. A smaller answer is now the only lever that moves the frame rate, and the four ways written in Q-570 are no longer a matter of latency alone.

**The accelerator's occupancy is the measure to watch**, and a cheap one: a 45-second trace under the Core AI template gives the busy fraction directly. 87 % is where the shipping build stands. Anything that lowers it is worth frames, and anything that does not, is not.

**One number here has no control.** The occupancy was measured on a run with the model and not on one without, so a share of it may belong to other users of the accelerator on the device rather than to the commander. The conclusion does not rest on it — the counter comparison does, and that one has its control — but the figure itself is a single-run reading.
