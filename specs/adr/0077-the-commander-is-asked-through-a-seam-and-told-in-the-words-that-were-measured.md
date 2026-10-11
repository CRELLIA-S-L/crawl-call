# ADR-0077 — The commander is asked through a seam, and told in the words that were measured

- **Status:** accepted
- **Date:** 2026-10-11
- **Related requirements:** IF-CMD-010, IF-CMD-020, IF-CMD-040, FR-CMD-025, FR-CMD-027, FR-CMD-070, CON-CMD-020, NFR-PERF-080, FR-TOOL-170

## Context and problem statement

The CMD area is twenty-nine requirements and no code. Before any of it can be built, three things have to exist: what a commander is told, what it is allowed to answer, and what it is told beforehand — IF-CMD-010, IF-CMD-020 and IF-CMD-040.

Two forces shape all three, and both are measurements rather than opinions.

**The state is read by the same guardrail as the instructions.** The spike measured it: the same situation written as wounds and bodies was blocked in 10 of 10 calls, and in the game's own words in 0 of 10 (ADR-0017). So the words a soldier's health is reported in are not a matter of style; they decide whether the call happens at all.

**A measurement covers one configuration and no other** — the instructions, the response schema, the vocabulary of the state and the model version, together (FR-TOOL-170). The project's standing reading of "0 blocks in 100" belongs to `v2-soft` with the spike's schema and the spike's states. Everything this decision writes is a change to at least three of those four.

## Considered options

For the surface the game calls:

1. A protocol, with the real session behind one implementation and a scripted answerer behind another.
2. A direct call to `LanguageModelSession` wherever a decision is wanted.

For the generated type:

1. Two types — one shaped for the generator, one the game holds, with the crossing between them the place a response is accepted or rejected.
2. One `@Generable` type used throughout the game.

For how the crew is carried in the answer:

1. An array of one described soldier type.
2. A field per soldier, per weight.

For where the instructions live:

1. `config/commander.json`, read at launch like every other configuration.
2. A string constant in the code.

## Decision outcome

**The surface, option 1 — a protocol.** The reason is not the test environment, which can reach the model: CON-CMD-020 obliges the game to keep working, with no voice missing and no order lost, when up to one call in five is refused, and **no real model refuses on demand**. A scripted answerer that refuses when told to is the only thing that constraint can be checked against.

Two consequences fall out of it and both are wanted. The suite never waits on an inference, which at 2.7 s a call would make it a suite nobody runs. And availability stops being something the code depends on: a device without Apple Intelligence returns `unavailable` down the same path as a refusal, and the squad behaves as it does for any other missed cycle.

**The generated type, option 1 — two types.** `SystemModelCommander.swift` is the only file in the game that imports FoundationModels, which is what makes every other file in `Commander/` testable without one. The crossing between the generated shape and `CommanderDecision` is where IF-CMD-020's "rejecting any response that does not parse into this shape" lives — rejection and never repair, because an unparseable answer is a missed cycle the squad survives while a repaired one is an order nobody gave.

**The crew, option 1 — an array.** A described type costs its schema once however many elements the array holds; a field per soldier per weight would be thirty described fields for a squad of six, and the schema is already the largest single part of the input (206 tokens of 405 measured on 2026-10-11).

**The instructions, option 1 — a file.** A prompt that needs a rebuild to try is a prompt nobody measures, and every change to it voids the bench's reading (FR-TOOL-170). `config/commander.json` is read at launch beside the other six.

### The words, and where they come from

Nothing in the state is invented. The six names are the bench's — Davis, Pike, Marsh, Otto, Beans and Kit — paired to the archetypes in order, because a seventh name is a word the guardrail has never seen in this register. Both squads use the same six, which never collide because no commander is told the other crew's names.

What is left of a soldier is one of three bands — `up`, `up but wobbly`, `flat on his back` — and not a number. A commander deciding whether to pull somebody out needs to know which of three states they are in; `health 37` costs tokens to say the same thing less safely. A pouch is `running low` or `pouch empty` and is said at all only below half, because a soldier with half a magazine is a soldier the commander needs to hear nothing about.

Where somebody stands is a quarter of the arena — `west side`, `north-east`, `middle`, with `, upstairs` for a floor above the ground — and never a pair of metres. The compass is this build's and is arbitrary the way a compass is: −z north, +z south, +x east, −x west.

**The whole state is built from the role-holder's knowledge and never from the arena.** That is the literal reading of "from its own point of view": the commander is told what its squad has seen and been told (FR-BOT-310), and a commander that knew where the snake truly was would be acting on the truth, which FR-BOT-220 forbids the bots themselves.

### What the state looks like, and why the common one is short

Five lines, in the bench's own order, for a squad with nothing extra to say:

```
crew: Davis, Pike, Marsh and Otto up, west side
rival crew: not seen
snake: not seen
awareness: calm
your last call: none
```

Roles, a pending truce and the events since the last call each add a line only when there is one, so the ordinary call stays the shape that was measured. Those standing the same way in the same quarter are named together, as the bench's own states name them, so four soldiers cost four names and one clause.

A budget check without a model needs an estimate, and the estimate here is three characters to a token — deliberately short of the 3.23 that today's bench run measured on its `alarm` state, so that it over-counts rather than under-counts. The true count comes back in `usage.input` from every real call.

## Consequences

**IF-CMD-010 and IF-CMD-020 are `partial`, not `implemented`.** Both are written as obligations on a call — "when calling a commander", "when a commander responds" — and there is no call yet. They close when FR-CMD-020 does.

**The bench grew a fifth variant and three scenarios.** `v5-game` reads `config/commander.json` rather than carrying a copy, so a measurement cannot drift from the text it claims to cover; the three new scenarios are the states the game builds, written out by hand as every other scenario is, because the bench is a separate instrument and must keep running without the game.

**`#filePath` is the path the compiler was handed.** The first attempt at `v5-game` resolved the instructions through `#filePath`, which is relative when the build command is and resolves against the working directory at run time: the variant silently returned nil, the run measured only the control, and the summary named no variant that was missing. It takes `BENCH_INSTRUCTIONS` or a path under the working directory instead. A run that cannot find the file leaves the variant out rather than measuring a copy.

**The configuration was measured, and the measurement found two things the design did not.** The bench was given a fifth variant that reads the shipped instructions and a `game` schema flavour that mirrors `GeneratedDecision`, and run on the states the game builds:

| | instructions and vocabulary only | with the game's own schema |
|---|---|---|
| calls / blocked | 12 / 0 | 12 / 0 |
| input tokens | 624–679 | 762–817 |
| output tokens, worst | 55 | 397 |
| latency, median / worst | 1.8 s / 1.9 s | 5.6 s / 9.2 s |

The control was blocked 12 times in 12 in both runs, so neither is void.

Nothing is blocked, which is the thing that had to be true: the longer instructions and the game's own words pass the guardrail as the measured ones did. What the schema costs is time. **FR-CMD-027's default of 80 response tokens is a quarter of what one answer needs**, and the requirement's own escape clause — "never below what the answer's own structure needs" — is what the configuration now follows, at 500; the sentence that also says "80 by default" is Q-560. **And the worst call took 9.2 seconds against a 7-second interval**, which is Q-570 and is measured on a Mac rather than on the phone NFR-PERF-040 is judged on.

**The model answers about soldiers that are gone.** In the state where one of six is left standing, three of four answers came back with leans for all six by name. So whatever applies a decision must apply it to the living bots of that squad by name and ignore the rest — which FR-CMD-060 has to do anyway, and which this measurement turns from a nicety into a case with evidence behind it.

**The six new files are carriers no element claims, and that is the layer working.** E-150 is `proposed`, and a proposed part owns none of its files until it is built (`srs-dd/arch.md`). The six warnings `srs_arch.py` prints are the layer saying what is true: the files exist and the part that will own them is still a design. They go when E-150 is flipped, which is a person's act at the end of the work and never the layer's.

**The instructions are four and a half times the length of the measured ones.** `v2-soft` is 91 input tokens; the shipped text is about 420. The five obligations IF-CMD-040 lists are the reason — the rival crew, that the answer is a decision, the meaning and range of every field, that nothing beyond the squad's own knowledge may be assumed, and the content rules — and `v2-soft` establishes two of the five.
