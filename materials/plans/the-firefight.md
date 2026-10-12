# The firefight: what a squad does once it has met the other one

A plan written on 2026-10-12 at the maintainer's request, after watching a match: the squads gather at sight range, stand in two clumps shooting at each other, sometimes stop shooting and look about, and never look like they are trying to win.

It is written so that an agent with no memory of the conversation can take it up — everything it needs is here or pointed to from here. The measurements it rests on are in `specs/91-open-issues.md` as Q-600 and Q-610, both recorded on 2026-10-12 in commit `4153af5`; this plan does not repeat their tables, it says what to do about them.

**Three steps change the specification outright and are marked**, and step 8 changes two more statements if its decision is answered yes. The rest build what is already written. A number this plan proposes and the specification does not carry is marked as a proposal, and nothing goes into `specs/` before the maintainer has said so. What is said here of a file was read off it on 2026-10-12, and the command that answers a question is beside it; re-derive rather than trust.

Under ART-030 of `specs/constitution.md`, amended 2026-10-11, the suite is run when a change is finished and the build goes on the phone where one is connected, neither asked for nor waited for. No step is marked "requires confirmation": the standing confirmation is the article.

## What is actually wrong

Four mechanisms, three of them in the bot and one in the commander. They are independent, and the first three each on its own is enough to produce the standstill the maintainer saw.

**A bot already hidden is still given something to do about cover.** `Deliberation.cover` answers with the best hidden cell the walk reaches, and the walk starts at the bot's own cell; the one filter that could have dropped it tests distance rather than identity — `Sources/CrawlCall/Bot/Deliberation.swift:462` keeps a cell when `$0.metres > .zero`, and the distance from a bot to the centre of the cell it stands in is small but never zero — while nearness is what ranks the candidates, so the cell under the bot's feet ranks first by construction. A bot standing in cover therefore scores an action that goes nowhere instead of having no cover to take. The measured consequence is in Q-600: five bots, each choosing `takeCover` at the cell it occupies, at utilities from 0.072 to 0.167.

**A goal under the bot's feet is cleared instead of excluded.** `Sources/CrawlCall/Bot/Execution.swift:288` finds the route empty and sets the action to nil, and the next slot scores the same list and chooses the same cell again. This is the loop FR-BOT-167 — An unreachable target sends the bot back to deliberation (specs/10-fr-bot.md, deferred) was written against: it obliges the system to give the bot a slot with *that action excluded* until the slot after. The comment at that line cites FR-BOT-167, and the requirement is `deferred` and carries no `code` and no `tests` field — `python3 srs-dd/tools/srs_view.py FR-BOT-167 --where` prints that no annotation names it. Half of it is built: the action is spent. The half that matters here, the exclusion, is not.

**Pressing the attack is only a fallback.** `Deliberation.choose` consults `quiet` — FR-BOT-360 — An idle bot advances on the enemy (specs/10-fr-bot.md, implemented) and FR-BOT-370 — An idle bot goes to see what it has not seen (specs/10-fr-bot.md, implemented) — only where the best scored action is worth nothing at all. That is not an accident of the code: it is the statements' own condition, "while every other action available to a bot scores nothing", and the decision behind it is ADR-0059 — A bot with nothing to do advances, looks and looks round, and never weighs it against a threat (specs/adr/0059-a-bot-with-nothing-to-do-advances-looks-and-looks-round-and-never-weighs-it-against-a-threat.md, accepted), whose option 1 was exactly the other way and was rejected because a score below every other action and above nothing could be beaten by accident. What it did not foresee is a scored action that means standing still: cover in the bot's own cell at 0.07 is above zero, so advancing and exploring are unreachable for the rest of the match.

**The commander cannot see the fight and cannot say much about it.** `Game.dueCalls` builds every state with `events: []`, and nothing anywhere appends to it, although IF-CMD-010 — Commander input (specs/20-interfaces.md, partial) obliges the state to carry the events since the previous call. Its order is one of five words and becomes one cell within five metres (ADR-0079 — An order becomes one cell to stand in, and discipline is what the order has to beat (specs/adr/0079-an-order-becomes-one-cell-to-stand-in-and-discipline-is-what-it-has-to-beat.md, accepted)), so there is nothing it can say that moves a squad across a room. And the role it hands out is read by nobody: FR-CMD-050 — The commander assigns roles (specs/10-fr-cmd.md, implemented) stores it and its own rationale says what a role does to utility is still nothing.

## What the suite does not catch today

`Tests/CrawlCallTests/IdleTests.swift` has `testInAMatchTheSquadsGoOutAndFindEachOther`, and it passes: at the start of a match no bot knows of an enemy, so there is no danger, no cover action, nothing scores, and the quiet motives walk the squads together. The test stops at first contact. **Nothing in the suite asserts anything about the match after the squads have met**, which is the whole of what the maintainer is complaining about. Step 1 is that test.

## What this plan does not cover

FR-SCORE-150 — The match ends when no bot is left (specs/10-fr-score.md, partial) stays `partial`. A match of standing bots never ends; if the fight resumes the freeze goes with it, but the requirement's own gap is somebody else's step.

The commander's voice and the truce — steps 6 and 7 of `materials/plans/the-commanders.md` — are untouched, so `decision.line` and `decision.truce` go on being parsed and dropped.

The fifth order, destroying the enemy's cover, names no cell until a bot can wreck a wall: FR-BOT-070 — Heavy and sapper weapons destroy cover (specs/10-fr-bot.md, deferred).

No step here produces an autopilot, so no step produces a verdict on NFR-PERF-030 — A commander inference does not break the frame budget (specs/30-nfr.md, deferred) or NFR-PERF-040 — Commander answers within its interval (specs/30-nfr.md, deferred) either. Device runs below are price comparisons between two builds measured the same way, which is what `specs/50-verification.md` says a change is priced by.

## The steps

Ordered by what each lands on, not by number. Steps 1 to 4 are the bot and wait on nothing but the statement step 2 authors; steps 5 to 9 each wait on a decision listed at the end of this file.

### Step 1 — A measurement that outlives the session

No behaviour changes. Add to `Tests/CrawlCallTests/IdleTests.swift`, beside the test that stops at first contact, one that runs a match **past** it: the two squads in an arena they can cross, the snake out of sight, advanced for ninety seconds of match time, asserting that after contact the squads keep deciding — the distance between the two squads' centres changes by more than a bot's body over the last thirty seconds, and at least one bot chose a move action in the last ten.

It verifies FR-BOT-360 and FR-BOT-370 by method `T`, and it is written to fail now: the numbers Q-600 records — the same distances to a tenth of a metre at the eleventh and the hundred and thirty-first second — are what it refuses. A test that does not go red before step 2 is decoration, and the step is not finished until it has been seen red.

Keep the diagnostic reading beside it as a scratch script rather than a test, in the session scratchpad: twelve windows of sixty frames, the actions chosen in each, the distance per bot to its nearest enemy. It is what tells the maintainer in step 4 whether the squads look like they are fighting, which no assertion answers.

### Step 2 — A bot in cover stays in it *(waits on decision 1)*

**Changes the specification.** Nothing in `specs/` says what a bot that is already hidden does about cover: FR-BOT-118 — A bot flees to somewhere it can get to (specs/10-fr-bot.md, implemented) is about reachability, FR-BOT-200 — The actions a bot can choose from (specs/10-fr-bot.md, implemented) lists moving to a cover position without saying from where, and FR-BOT-330 — A bot hides from the enemy as from the snake (specs/10-fr-bot.md, implemented) says what counts as watched and nothing about the cell the bot is in. So the first act is authoring, through the `srs-new` dialog, and the statement this plan proposes is:

> **FR-BOT-119 — A bot in cover stays in it** *(a proposal; the specification does not carry this number)*
>
> While nothing a bot knows of watches the cell it stands in, the system **shall** leave taking cover out of the actions available to it.

The rule is the maintainer's, settled on 2026-10-12: a bot whose position already shields it from what it knows of has no business looking for another wall, and the thing that moves it off that position is a threat that reaches it or an order, not a better hiding place. One capability, confirmable by a test on a bot standing in an unwatched cell, and it says what and not how. The number is free: `python3 srs-dd/tools/srs_view.py --list --area BOT` prints 118 and 120 with nothing between them.

It does not say "some other cell", on purpose. Hunting for a different wall while the present one holds is the behaviour the statement forbids, and it is also unnecessary: `cover` rejects a watched cell by the sight test it already makes, so once a bot whose own cell is unwatched has no cover action at all, the own cell can never be the answer — it is either unwatched, and there is no action, or watched, and the function skips it like any other watched cell. One rule covers both halves of the defect.

Then the code, in `Deliberation.cover`: before the ranking, ask of the bot's own cell the same question the loop asks of every candidate — is it watched by a part of the snake or by an enemy's eyes where the bot last saw it — and answer nil where it is not. `Deliberation.isWatched` is that question already, over the same two sets the function hides from, so the two cannot disagree. The filter at line 462 stays as it is; nothing else in that function changes. `post` keeps the bot's own cell on purpose — firing from where you stand is a fine answer, and FR-BOT-420 — A bot fires from beside cover (specs/10-fr-bot.md, implemented) and FR-BOT-425 — A bot reloads behind cover (specs/10-fr-bot.md, implemented) rest on it — and `away` already refuses a cell that gains no ground.

What a bot in cover does instead is score fire, reload, flight, obedience and the quiet motives. An order still moves it: `moveToOrderedZone` is a different action and is scored by the obedience term whatever cover the bot is in, which is where a commander that wants the position changed says so (FR-BOT-130 — Discipline decides how far an order is kept (specs/10-fr-bot.md, implemented)). A danger that comes close enough still moves it too, through flight and through the courage term holding its ground down (ADR-0074 — Courage multiplies firing, and holding ground by how near the danger has come (specs/adr/0074-courage-multiplies-firing-and-holding-ground-under-danger.md, accepted)).

Tests in `Tests/CrawlCallTests/DeliberationTests.swift`: a bot standing in an unwatched cell scores no cover at all, whatever the snake and the enemy are doing; a bot standing where an enemy can see it still takes the hidden cell beside it; a bot standing watched with nowhere hidden within reach scores no cover either; a bot in cover under an order still scores the ordered zone; and the negation — take the new answer out and the first test goes red.

The decision goes to `specs/adr/`: cover becomes an action about going somewhere better rather than about being somewhere good, and being somewhere good is then worth nothing in the scores, which is what makes the other actions reachable.

### Step 3 — A goal under the bot's feet is excluded, not cleared

Build FR-BOT-167, which is approved and unbuilt. It `depends_on` FR-SNAKE-040 — Tail blocks bots (specs/10-fr-snake.md, deferred); that dependency is the motivating case and not a condition — a route that comes back empty already happens without a tail across a passage, which is why `Execution.swift:288` has the branch — so this step is not blocked by it, and the step says so in its report.

The behaviour: when the route to a chosen action's goal is empty, the bot gets a slot at once with **that action** left out of the scoring, until its next slot after. `Sources/CrawlCall/Bot/Slots.swift` is where a slot is granted and `Sources/CrawlCall/Bot/Interrupts.swift` is where a reason for one is named, so the exclusion is a one-slot memory on the bot, read by `Deliberation.scores` and cleared when the slot after it is taken.

This is the one change that makes the standstill impossible by construction rather than by arithmetic: a goal that resolves to the cell the bot occupies is a route of no steps, whichever action proposed it — cover after step 2 cannot, but `hold` from a commander's order (`Sources/CrawlCall/Commander/Orders.swift`) returns exactly that cell, and flight, flanking and dispersal can each land on it, because every one of them compares a cell's centre against the bot's exact position and the two differ by a fraction of a cell.

Tests in `Tests/CrawlCallTests/InterruptTests.swift` and `DeliberationTests.swift`: a bot whose only cover is cut off chooses something else on the very next slot and the cover again on the slot after; a bot under a `hold` order does not spend every slot on a route of no steps; and the negation.

Close the loop on FR-BOT-167 — `implemented`, `code`, `tests`, the annotations, and the requirement into E-090 — The squads (arch/00-elements.md, built).

### Step 4 — Read the result, and put the design question to the maintainer

No code. Run the suite, run the scratch reading of step 1 on the shipped arena, put the build on the phone with `CRAWLCALL_RECORD` (FR-TOOL-250 — A run on the device reports its slowest frames (specs/10-fr-tool.md, implemented)), and look at it.

Then report, with the numbers beside the ones in Q-600: whether the squads move after contact, whether anybody advances, whether a match ends. And ask the question step 5 waits on, which cannot be answered before this: steps 2 and 3 remove the standstill, and the maintainer wanted a squad that looks like it is trying to win. Those are not the same thing, and Q-600 says so.

### Step 5 — Advance and explore are scored beside the rest *(waits on decision 3)*

**Changes the specification**, and reverses a decision: ADR-0059 chose its option 2 deliberately. A new ADR supersedes it, and its context is what the old one could not know — that a scored action can mean standing still, so "a threat is something that scores" did not hold.

Three statements change. The links they already carry stay as they are — FR-BOT-250 — What a bot knows at the start (specs/10-fr-bot.md, implemented) for the enemy's starting area, and FR-BOT-230 — A bot remembers the map it has seen (specs/10-fr-bot.md, implemented) for the cells a bot does not know. The wording this plan proposes is:

> **FR-BOT-360 — An idle bot advances on the enemy** — reworded:
> When a bot has somewhere it believes the enemy squad to be, the system **shall** score going towards it — the latest place it saw or was told of an enemy bot, or, where it knows of none, the enemy's starting area (FR-BOT-250) — among the actions available to it, by its aggression.
>
> **FR-BOT-370 — An idle bot goes to see what it has not seen** — reworded:
> When a bot can reach a cell that is not in its knowledge of the map (FR-BOT-230), the system **shall** score going to the nearest such cell among the actions available to it, by what its aggression leaves.
>
> **FR-BOT-200 — The actions a bot can choose from** — the list gains two members:
> … fire at the current target, move to a cover position, move to an ordered zone, flee from the snake, reload, advance on where it believes the enemy to be, go to the nearest cell it has not seen, and — for a medic — heal a squadmate within reach.

The titles of the first two stop being true the moment their statements do: an idle bot is no longer what either describes, so they are proposed as **A bot advances on the enemy it believes in** and **A bot goes to see what it has not seen**.

The new terms take weights in `config/bot.json` under `utilityTermWeights`. FR-BOT-080 — Action chosen by maximum utility (specs/10-fr-bot.md, partial) keeps its statement, because what the bot knows of the enemy and of the map is already in its list of inputs, and IF-BOT-010 — Bot and match configuration (specs/20-interfaces.md, partial) covers the weights without naming a term — it asks for the weight of each term in an action's score — so neither statement needs an interface change.

The test that pins the old decision is `testAMotiveForTheQuietNeverOutweighsAThreat` in `IdleTests.swift`, and it must keep passing in substance: a bot with the snake two metres off does not go for a stroll. Under scored motives that is no longer true by construction and becomes a statement about the weights, so the test stays and the weights are what answer to it — which is the objection ADR-0059 raised against option 1 and the thing the new ADR has to answer with numbers rather than with an argument.

### Step 6 — The commander is told how the fight is going *(waits on decision 4)*

Build the half of IF-CMD-010 that is not built. The material is already computed every frame and thrown away: `Interrupts.find` returns, per bot, the first of `hit`, `snakeClose`, `allyDied`, `magazineEmpty` and `sawEating`, and `Stealth` holds the meals, the reports and the losses (FR-SCORE-130 — Each squad has an awareness state (specs/10-fr-score.md, implemented)). An accumulator on `Game`, filled where the interrupts are read (`Sources/CrawlCall/Game.swift:418`) and emptied when a call is built (`dueCalls`), is the whole mechanism; `SquadView.state` already takes `events:` and `CommanderInput.prompt` already renders the line as `just happened: …`.

What it may cost is bounded and has to be measured, not estimated. The state is held to the state token budget of `config/match.json`, 1000 tokens, and IF-CMD-010's own record is 624 to 679 input tokens over twelve calls, with 768 measured on the phone (Q-590). So the events line has a few hundred tokens of room and no more, and it is capped in the code rather than by hope. The direction is the cheap one: ADR-0078 — The commander's frames are lost to the clock and not to the code, so the only lever left is the work asked of the model (specs/adr/0078-the-commander-s-frames-are-lost-to-the-clock-and-not-to-the-code.md, accepted) measures the cost in generated tokens, and events add input only.

Every change to the state's vocabulary voids the project's prompt measurements (FR-TOOL-170 — A bench measurement names the configuration it covers (specs/10-fr-tool.md, deferred)), so the step ends at the bench — `Sources/PromptBench/`, FR-TOOL-150 — The prompt bench (specs/10-fr-tool.md, implemented) — over the new state, and at the words it may use (IF-CMD-060 — What a generated line may and may not contain (specs/20-interfaces.md, deferred)): a squad that lost two is told so in the words that measured clean, which is `gone missing` and not a casualty count.

Tests in `Tests/CrawlCallTests/CommanderContractTests.swift`: a squad that was hit, lost somebody and emptied a magazine between two calls is told all three; the list is emptied by the call that carries it; a squad with a quiet seven seconds gets no line at all; the cap holds when a frame produces more events than the budget allows; and the rendering of the four other lines is byte for byte what the bench measured, because that is what FR-TOOL-170 is about.

### Step 7 — An order reaches further than a step *(waits on decision 5)*

**Changes the specification**, in one enumeration. `Orders.reach` is the grouping distance, five metres, because ADR-0079 had nothing else to use. An order that can move a squad across a room needs its own distance, and IF-BOT-010 enumerates the distances it reads — "the override, interrupt and grouping distances" — so the statement gains a fourth:

> … the override, interrupt, grouping and order distances; …

with `orderReach` in `config/bot.json` beside `groupingDistance`. ADR-0079 took the grouping distance because it is the reach cover and flight are already found within, and that is the choice this step reverses; the new ADR says what an order reaches instead and what keeps a squad together while it carries one out (FR-BOT-190 — Alarmed squads keep together (specs/10-fr-bot.md, implemented) is the other force on the same bots).

The flank rule goes with it: today a flanking cell may not be further from the enemy than the bot already stands, which over five metres means there is no going round anything.

### Step 8 — Whether five words are enough *(waits on decision 6)*

FR-CMD-040 — The commander issues an order (specs/10-fr-cmd.md, implemented) and IF-CMD-020 — Commander output (specs/20-interfaces.md, implemented) carry the vocabulary: hold, flank, withdraw to a zone, disperse, destroy the enemy's cover. A commander cannot say take the upstairs, leave the room, gather at the gate, or wait until they reload. Any addition changes both statements and the generated schema, and costs one word of output — the cheap end of ADR-0078 — but each new word needs a cell rule in `Orders.zone` that is honest about what a bot can do, which is where the real cost is.

This step is deliberately last of the commander steps: steps 6 and 7 may be enough on their own, and a vocabulary chosen before the squad can carry out the five words it already has would be five more words nobody obeys.

### Step 9 — A role does something *(waits on decision 7)*

FR-CMD-050's own rationale records the gap: a role is stored, and what it does to utility is nothing. Three roles — holding a stair, covering, distracting — each a bias in one bot's utility, which is tuning rather than a new mechanism, over terms that already exist. It is listed here because it is the fourth route by which the commander's answer reaches the squad and the only one still inert, and it is last because it is worth nothing until the squads fight.

### Step 10 — Close the loop

Statuses, `code`, `tests` and annotations for everything built; the requirements that reached `implemented` into their element — E-090 for the bot steps, E-150 — The commanders (arch/00-elements.md, proposed) for the commander steps, whose `carrier-unclaimed` warnings clear when it is flipped to `built`, which is a person's act and not this plan's.

Then `python3 srs-dd/tools/srs_check.py`, `python3 srs-dd/tools/srs_arch.py`, `python3 srs-dd/tools/srs_grounds.py`, `python3 scripts/arch-edges.py` staged where source files were added, the `srs-check` procedure over every requirement touched, the whole suite on the simulator, and the build on the phone.

## The decisions that belong to the maintainer

1. **Settled in substance on 2026-10-12** — a bot in cover stays in it, and only a threat or an order moves it — and open on the words: the statement quoted in step 2 is what would be written into `specs/10-fr-bot.md`, and nothing in steps 2 to 4 moves before it is confirmed or reworded.
2. **Settled on 2026-10-12.** IF-CMD-010 went to `partial`, with the reason in its rationale and in Q-610; it goes back to `implemented` at the end of step 6.
3. **Whether step 5 happens at all**, answered after step 4's numbers. Steps 2 and 3 end the standstill; step 5 is what makes a squad press an attack while a far danger scores. It reverses ADR-0059 and is the largest behaviour change in this plan.
4. **What a call carries of the fight.** Three sizes. Only losses and hits taken, which is two short clauses and nearly free. Those plus a shot fired, a magazine emptied and a squadmate seen eaten, which is what `Interrupts` already computes and about a line of text. Or those plus a trend — ground gained or lost, who is firing at whom — which needs state nothing keeps today and is the only one of the three that cannot be built from what the frame already has. The plan builds the second unless told otherwise, and whichever is chosen goes in the ADR rather than into IF-CMD-010's statement, which already obliges "the events since the previous call" and needs no rewording to permit any of the three.
5. **What an order's reach is.** A number for `orderReach`, and the plan's own proposal is fifteen metres — three times the distance a squad stays together over, far enough to name another room in the shipped arena and short enough that a squad under one order does not string out across the island.
6. **Whether the five orders stay five.**
7. **What each of the three roles biases**, if step 9 happens.

Decisions 4 to 7 all add to what the commander is told or answers, and every one of them is bound to Q-570, which is still open: the shape of IF-CMD-020's answer is the only lever left on the frame rate, and no step here may be reported without the device run that prices it.
