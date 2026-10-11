# The commanders: the half of the game that is written and not built

A plan written on 2026-10-11 at the maintainer's request, alongside `the-arms.md`.
It is written so that an agent with no memory of the conversation can take it up: everything it needs is here or pointed to from here.

**Nothing here changes the specification.** Every requirement named below is already written and `deferred` — approved by the maintainer and awaiting implementation. This file says in what order to build them and what each one lands on; `specs/` and `arch/` are the record, and a decision taken while building goes to `specs/adr/`.

Every number was derived from the tree on 2026-10-11 with the command given beside it. Re-derive rather than trust: the commands are there so the plan can be checked, not believed.

## Why this is the next thing

The commander is the game's distinguishing half and the only large part of the system with no code at all.

```
python3 srs-dd/tools/srs_view.py --coverage
```

gives ten areas, of which CMD is 29 requirements and every one of them `deferred`. The architecture layer has already designed the part that will hold them — E-150 — The commanders (arch/00-elements.md, proposed), 36 obligations, whose files `Sources/CrawlCall/Commander` and `config/commander.json` are not in the repository:

```
python3 srs-dd/tools/srs_arch.py --plan
```

FR-CMD-020 — The commander is called on an interval (specs/10-fr-cmd.md, deferred) is the fourth most constrained requirement in the specification, 15 incoming links (`python3 srs-dd/tools/srs_arch.py --drivers`).

And it is cheaper than it looks, because the hard part was done a year's worth of risk ago.

## What already exists, and is the reason this is not a research project

**The spike answered the feasibility question on 2026-09-22** and wrote it down in `materials/spike/README.md`. On an iPhone 16 Pro, over twenty minutes: 121 commander calls, no failure, 532–536 input tokens, 2.7 s average latency and 3.3 s worst against a 5–10 s interval, 60 fps with one missed frame in 71,820, the device reaching `fair` at fourteen minutes and never `serious`, and no frame missed while an inference ran. NFR-PERF-030 — A commander inference does not break the frame budget (specs/30-nfr.md, deferred), NFR-PERF-040 — Commander answers within its interval (specs/30-nfr.md, deferred) and NFR-PERF-050 — Sustained performance over a long session (specs/30-nfr.md, deferred) all passed there, on throwaway code that was then deleted.

**The prompt bench is in the repository and works** — `Sources/PromptBench/`, which realizes FR-TOOL-150 — The prompt bench (specs/10-fr-tool.md, implemented) and FR-TOOL-160 — The bench carries a control that must be blocked (specs/10-fr-tool.md, implemented). It calls `SystemLanguageModel.default` with `LanguageModelSession`, guided generation and a response schema, and it already measured the things that otherwise get argued about. From its README and ADR-0017:

- one session per call beats a kept session on tokens (402 against about 1150), on latency (about 1.6 s against 1.9 s) and on robustness — there is no transcript to poison. This is FR-CMD-025 — Each commander call is its own session (specs/10-fr-cmd.md, deferred), and it is measured, not assumed;
- leaving the response schema out of the prompt saves 206 input tokens and triples the output, with calls past 40 seconds; `maximumResponseTokens` is the bound instead, which is FR-CMD-027 — Every generation carries a response ceiling (specs/10-fr-cmd.md, deferred);
- a guide's `.range` is worth its tokens and its description prose is not: dropping the prose saved 72 tokens a call and cost nothing; dropping the range produced 0.8 to 8.0 where the field runs 0 to 1. That is why IF-CMD-020 — Commander output (specs/20-interfaces.md, deferred) says every numeric field carries its range as a generation constraint;
- `permissiveContentTransformations` does nothing under guided generation, which is what the commander uses — so content safety is the instructions' job and the filter's, not a flag's;
- the register decides refusals, not only tone: the military register gave 63 restatements of "Snake at flank — advance" with no names and nothing worth replaying; the comedy register gave what the concept describes — "Davis: 'The snake's eating us! Pike, blame the other crew!'" — at six refused calls in sixty against one in sixty-three, and lines averaging 97 characters against 42 (ADR-0017's table).

**The match configuration already carries every key** the commander needs — `config/match.json` holds `commanderInterval` 7.0, `truceSwitch` false, `truceBreakThreshold` 0.3, `stateTokenBudget` 1000, `maximumResponseTokens` 80, `thermalDegradationThreshold` "serious", `thermalDegradationFactor` 2.0, and `commanderEligibleArchetypes`, which is **empty** and is the first thing the work fills.

**The squad already has a state to compress.** `Sources/CrawlCall/Bot/Awareness.swift` holds a per-squad awareness, the meals, the reports and the losses (FR-SCORE-130 — Each squad has an awareness state (specs/10-fr-score.md, implemented)); `Knowledge.swift` holds what each bot has seen of the enemy, the snake and the map. IF-CMD-010 — Commander input (specs/20-interfaces.md, deferred) asks for exactly these, compressed.

**The order has a place to land.** `Deliberation.Situation.orderedZone` exists, is scored with the obedience term, and is multiplied by discipline and — since ADR-0074 — by courage under danger. Today it is always nil in play, because nothing sets it. The commander is what sets it.

## The seam, and why it exists even though the model is available

The maintainer confirmed on 2026-10-11 that the model is available on the development machine, and the project's own prompt bench confirmed it the same day by answering: `./bench anatomy` returned a full token breakdown for the shipping instruction variant — 405 input tokens, of which 56 overhead, 206 schema, 91 instructions and 52 state. So the first worry this plan was written around — that the suite runs where the model does not — is not the blocker it looked like.

That run reproduced two things the spike had already recorded, which is the reason to trust it: the schema costs 206 input tokens, exactly the saving the spike reports for leaving it out, and `v0-baseline`, the game's first instruction variant, was blocked on a trivial probe with "guardrail: May contain unsafe content" — which is the line `materials/spike/README.md` already records, that the old instructions block even `./bench anatomy`'s one-character prompt.

It also turned up a discrepancy, and Q-540 holds it: the model answered that its maximum context is 8192 tokens, where CON-CMD-010 — The system language model's context and cache (specs/40-invariants.md, deferred) gives 4096 as the spike's measurement. **Nothing in this plan waits on it.** The requirement is a ceiling, a larger window cannot make a fitting call stop fitting, and the commander is nowhere near either number: 405 input tokens on the bench, 531–537 in the spike's play runs — an eighth of the smaller window, with no transcript to accumulate and the response capped at 80. Build to 4096 and the headroom is eightfold.

**The commander is still built behind a seam**: a protocol with the real `LanguageModelSession` on one side and a scripted double on the other. The reason is not the test environment but CON-CMD-020 — The model refuses a share of calls (specs/40-invariants.md, deferred), which obliges the game to keep working, with no voice missing and no order lost, when up to one call in five is refused. No real model refuses on demand, so the only way that constraint is verifiable at all is a double that refuses when told to. The same seam makes the suite fast, since a test that waits 2.7 s for an inference is a test nobody runs.

So the real call is exercised where it belongs — on the phone, after every change, which this project already does — and the behaviour around it is exercised in the suite against the double.

That seam is an architectural decision and goes to `specs/adr/` when it is made.

## The order the steps go in

Taken from `depends_on`, not from the numbers. Each step names the requirements it builds, cited at first mention; each ends with the project's loop — statuses, `code`, `tests`, the checker.

Under ART-030 of `specs/constitution.md`, amended 2026-10-11, the suite is run when a change is finished and the build goes on the phone where one is connected, neither asked for nor waited for. No step below is marked "requires confirmation": the standing confirmation is the article.

### Step 1 — The seam

Define the protocol the commander calls through, with two implementations: the real one over `LanguageModelSession`, and a double a test scripts — answers, malformed answers, refusals, and silence.

The availability check belongs in the real one, before the first call, as the bench already does it: `SystemLanguageModel.default` is asked for its availability and an unavailable model is reported with its reason rather than read as a run with no blocks (`Sources/PromptBench/PromptBench.swift`). A game that cannot reach the model falls back to pre-written lines and no orders, which is the same path FR-CMD-120 and NFR-PERF-070 already describe.

Nothing in this step calls a model. It is the step that makes every later one testable.

### Step 2 — The role-holder, and the contract around the call

Build:

- FR-BOT-040 — One bot per squad holds the commander role (specs/10-fr-bot.md, deferred) — exactly one bot per squad, of any archetype `commanderEligibleArchetypes` allows, with no visual marker. **`commanderEligibleArchetypes` is empty in `config/match.json` and must be filled**; an empty list today would designate nobody. The concept makes the role a listening puzzle — the holder is the one who speaks the orders — so no marker is added.
- IF-CMD-010 — the compressed world state from one squad's point of view, within the 1000-token budget, written in the vocabulary that IF-CMD-060 — What a generated line may and may not contain (specs/20-interfaces.md, deferred) allows.
- IF-CMD-020 — the structured response, every numeric field carrying its range.
- IF-CMD-040 — Instructions for a commander's decision (specs/20-interfaces.md, deferred).

Verification: all four are `T`. The state and the response are pure data structures and test without a model at all — which is the point of writing them before the call.

**The token budget is a test, not a hope.** IF-CMD-010 names 1000 tokens and the spike measured 532–536 in a comparable state. A test that builds the worst state the game can produce — eight bots, a full event list, a pending truce — and asserts the count stays under the budget belongs here, and the bench's token counting is the instrument.

**ADR:** the shape of the seam, the vocabulary chosen for the state, and what is left out of it to stay inside the budget.

### Step 3 — The call

Build FR-CMD-010 — One commander per squad (specs/10-fr-cmd.md, deferred), FR-CMD-020, FR-CMD-025, FR-CMD-027, FR-CMD-080 — The two commanders run out of phase (specs/10-fr-cmd.md, deferred), and FR-CMD-070 — Awareness gates what the commander is told (specs/10-fr-cmd.md, deferred).

FR-CMD-070 is cheap and belongs here rather than later: a calm squad's commander is not told about the snake, and the awareness it reads is already built.

FR-CMD-080 — the two commanders at least half an interval apart — is what keeps two inferences off the same frame, and it is the cheapest half of NFR-PERF-030.

NFR-PERF-080 — The language model costs the app no memory or download size (specs/30-nfr.md, deferred) is satisfied by the choice of model and verified by inspection: nothing is bundled.

**Where the call runs matters.** The spike missed no frame during an inference over 121 calls, on code that is gone. Rebuilding that property means the call never blocks the frame: it is started, it is awaited off the render path, and its result is applied at a frame boundary. NFR-PERF-030 is a `T` over a frame record, and `CRAWLCALL_RECORD` already produces one (FR-TOOL-250 — A run on the device reports its slowest frames (specs/10-fr-tool.md, implemented)).

### Step 4 — What the response does

Build FR-CMD-030 — The commander sets the threat priority (specs/10-fr-cmd.md, deferred), FR-CMD-040 — The commander issues an order (specs/10-fr-cmd.md, deferred), FR-CMD-050 — The commander assigns roles (specs/10-fr-cmd.md, deferred), FR-CMD-060 — The commander sets personality weights (specs/10-fr-cmd.md, deferred).

This is the step that lights up what is already built and currently runs on nothing:

- the obedience term in `Deliberation.scores` gets an `orderedZone` for the first time, and with it discipline and courage reach play (ADR-0074);
- FR-BOT-120 — Nearby snake overrides the commander's priority (specs/10-fr-bot.md, partial) can close: it stands at `partial` only because there is no commander whose priority to override;
- FR-BOT-130 — Discipline decides how far an order is kept (specs/10-fr-bot.md, deferred) becomes buildable, and should be built here rather than later, because it is the formula the order's term was always meant to have.

FR-CMD-060 clamps each weight to the archetype's allowed range in `config/bot.json` — the `allowedRanges` block that has been in the file since the beginning and that nothing has ever read. Courage joined it on 2026-10-11.

### Step 5 — Collapse

Build FR-CMD-120 — Losing the role-holder silences the commander (specs/10-fr-cmd.md, deferred), FR-CMD-125 — Losing the role-holder voids orders and roles (specs/10-fr-cmd.md, deferred), FR-CMD-130 — Collapsed bots keep their last weights, with more panic (specs/10-fr-cmd.md, deferred).

Three small requirements that together are the player's main lever on the war, and the reason the role has no marker. `collapsePanicIncrement` is already 0.3 in `config/bot.json`.

This step is where the game becomes playable in the way the concept describes: eat the right bot and a squad falls apart. It is worth putting on the phone and looking at before going further.

### Step 6 — Speech

Build IF-CMD-030 — Speech configuration (specs/20-interfaces.md, deferred), IF-CMD-050 — Instructions for a bot's line (specs/20-interfaces.md, deferred), IF-CMD-060, FR-CMD-140 — Bots speak on events (specs/10-fr-cmd.md, deferred), FR-CMD-150 — Speech is rate-limited and queued (specs/10-fr-cmd.md, deferred), FR-CMD-160 — Every line passes a content filter (specs/10-fr-cmd.md, deferred), FR-CMD-165 — A refused generation falls back to a pre-written line (specs/10-fr-cmd.md, deferred).

ADR-0017 already settled the register and the content list, and the bench already measures blocks. **Build the pre-written line set first**: FR-CMD-165 and FR-CMD-160 both fall back to it, NFR-PERF-070 — Under thermal pressure speech falls back to pre-written lines (specs/30-nfr.md, deferred) serves from it, and a speech system whose fallback is written last has no fallback during the whole of its development.

The filter of FR-CMD-160 is testable with no model at all: feed it the lines the bench's CSV already collected and assert which ones it rejects.

**Run the bench before this ships.** Its README is explicit: a measurement is a reading of four things at once — instructions, schema, state vocabulary and model version — and changing any of them voids the reading. The game's instructions will not be the bench's variants verbatim, so the configuration the game ships must be measured in the bench, control included, before it is called done — which is what FR-TOOL-170 — A bench measurement names the configuration it covers (specs/10-fr-tool.md, deferred) will oblige once it is built, and what the bench's README asks for already.

### Step 7 — The truce

Build FR-CMD-090 — A commander may propose a truce (specs/10-fr-cmd.md, deferred), FR-CMD-100 — A truce stops fire between the squads (specs/10-fr-cmd.md, deferred), FR-CMD-105 — A truce turns both squads on the snake (specs/10-fr-cmd.md, deferred), FR-CMD-110 — A truce is fragile (specs/10-fr-cmd.md, deferred).

Last of the behaviour, and behind a switch: `truceSwitch` is `false` in `config/match.json`, so this ships off and is turned on when it is worth looking at. The concept calls it the natural punishment for greed — eat too much too fast and they gang up on you — and it is the one place the model is doing something a utility function could not.

FR-CMD-110 has four triggers and is the one requirement here that deserves a decision table before a line is written: hit by the other squad, panic over the threshold, either commander ordering withdrawal, either squad losing its role-holder.

### Step 8 — Thermal degradation, and the constraints

Build NFR-PERF-060 — Under thermal pressure the commander interval stretches (specs/30-nfr.md, deferred) and NFR-PERF-070.

**Q-180 is open and sits in this step**: the degradation factor has no measurement behind it. The spike never reached `serious` over twenty minutes, so the threshold defaults to the first state whose cost is unmeasured and the factor of 2.0 is a guess. Build the mechanism, ship the guess, and say in the report that the number is unmeasured — do not invent a measurement for it.

Then the two constraints:

- CON-CMD-010, verification `A` — instructions, transcript and prompt inside 4096 tokens. With one session per call (FR-CMD-025) there is no transcript, which is most of why this holds; the rest is that the call is an eighth of the budget. Q-540 notes that the Mac's model reported a larger window on 2026-10-11 and that it changes nothing here.
- CON-CMD-020 — the game keeps working, no voice missing and no order lost, when up to one call in five is refused. **This is the requirement the seam exists for**: the test scripts a double that refuses one call in five and asserts that every event still got a line and every squad still has an order.

### Step 9 — Close the loop

- Every requirement above to `implemented` or `partial`, with real `code` and `tests`, and every file named there saying so back with `file implements:` / `file verifies:`.
- **E-150 flips from `proposed` to `built`** — a person's act, never the layer's (`.claude/skills/srs-arch/SKILL.md`). The checker says when all its files and obligations are in place.
- FR-BOT-120 to `implemented`; FR-BOT-080 — Action chosen by maximum utility (specs/10-fr-bot.md, partial) keeps its remaining gap, which is the arms, not the commander.
- `python3 srs-dd/tools/srs_check.py`, `srs_arch.py`, `srs_grounds.py`, then the `srs-check` procedure.
- A performance measurement on the phone under `CRAWLCALL_RECORD`, run unattended, because NFR-PERF-030, -040, -050 and -055 are all `T` over a long run and the spike's numbers belong to code that no longer exists.

## What stands on a bet, and what does not

`python3 srs-dd/tools/srs_grounds.py --blast` over the commander's files will name these once they exist. Today:

- **H-040 — An LLM commander makes a difference the player can see** is the hypothesis this whole plan is an investment in, and it is `assumed`.
- **H-050 — Bot lines are worth replaying for** carries the speech half, and several IF-CMD records already bet on it (B-590, B-600, B-620).

Neither is settled, and both are the maintainer's with their own population, threshold and date. That is the honest state: this is the most expensive layer in the game and the one whose payoff is least proven.

## Risks, named

**The model's availability is a property of the machine, not of the code.** It is available on the development machine today (the maintainer, 2026-10-11), and an OS update, a disabled setting or a different machine can take it away. That is the argument for the double being the suite's default and the real call the marked exception: a suite that goes red because Apple Intelligence was switched off is a suite that stops being read.

**The register that makes the game funny is the register that gets refused.** ADR-0017's table: six refused calls in sixty for the comedy register against one in sixty-three for the military one. The mitigations are written — FR-CMD-160, FR-CMD-165, CON-CMD-020 — and all three must be built before the speech is judged, or the first bad run will read as "the model does not work".

**The spike's numbers are not this code's numbers.** Everything in `materials/spike/README.md` was measured on an app that was deleted. The plan treats them as evidence that the approach is sound, never as measurements of what gets built.

**Q-180 is unmeasured and will stay so** until a device reaches `serious`, which twenty minutes of a worst case never achieved. Say it in the report rather than closing it quietly.

**Q-540 is open and is not a risk.** It is a stale number in a rationale, kept so the next reader is not misled; the budget it concerns has an eightfold margin and nothing in this plan is written against the difference.

## What this plan deliberately leaves out

- Anything in `the-arms.md`. The two are independent: the commander does not need the weapons, and the weapons do not need the commander.
- FR-SCORE-060 — Target-value multiplier for commander, heavy and medic (specs/10-fr-score.md, deferred) and the rest of the scoring that depends on the role-holder — they are the SCORE area's and have their own shape.
- A voice for the lines. FR-CMD-140 says "generate and play"; how a line reaches the player — text, speech synthesis, a bubble — is the VIEW area's and is not written yet.
