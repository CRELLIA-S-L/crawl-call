# The strategist: what a commander is for, and what a bot works out for itself

A plan written on 2026-10-12 at the maintainer's request, who said it in one line: a commander is a strategist and should give strategic commands — where the enemy is and how best to press them — while the bots obey those and work out the tactics themselves, who goes round from where, how to cover the enemy best, where to look for cover; and a bot may decide to move or to attack on its own, without waiting to be told.

It is written so that an agent with no memory of the conversation can take it up. What it rests on is in this file or named from it, and every number in it was measured on 2026-10-12 with the command beside it.

**This plan changes the specification in five places and withdraws two requirements.** Nothing goes into `specs/` before the maintainer has said so; a number this plan proposes and the specification does not carry is marked as a proposal.

Under ART-030 of `specs/constitution.md`, amended 2026-10-11, the suite is run when a change is finished and the build goes on the phone where one is connected, neither asked for nor waited for.

## The rule, as the specification would have to carry it

Three sentences, and everything below is one of them being made true:

1. **A commander names what matters and where** — a threat to worry about and a part of the arena — and never which cell a bot stands in.
2. **A bot works out how**, from what it knows (FR-BOT-220 — A bot acts on what it knows (specs/10-fr-bot.md, partial)), and may act with no order at all.
3. **An order biases a bot's choice and never replaces it**, which is what FR-BOT-130 — Discipline decides how far an order is kept (specs/10-fr-bot.md, implemented) already says and what the mechanism must keep true.

## What already follows the rule

**The whole utility layer.** FR-BOT-080 — Action chosen by maximum utility (specs/10-fr-bot.md, partial) knows nothing about whether a commander exists. Measured on 2026-10-12, on the shipped arena with no commander and nobody steering: the squads advance, take cover, fire, reload and finish each other, one squad wiped out by the eighty-fifth second. Sentence 2 is not a wish; it is what a match does today.

**The threat priority.** FR-CMD-030 — The commander sets the threat priority (specs/10-fr-cmd.md, implemented) is already a strategic command in the maintainer's sense: it says which of the three sides matters, and the bot works out what to do about it — with the snake within the override distance beating any order (FR-BOT-120 — Nearby snake overrides the commander's priority (specs/10-fr-bot.md, implemented)).

**Discipline.** The order's term is weighted by the bot's discipline and its own reading by one minus it, so an order is already an argument rather than an instruction.

## What breaks the rule

**The commander rewrites personalities.** FR-CMD-060 — The commander sets personality weights (specs/10-fr-cmd.md, implemented) replaces each bot's panic, courage, discipline, aggression and self-sacrifice with numbers from the answer. That is neither strategy nor tactics: it is the commander reaching inside the soldier. It is also the bulk of the answer — five numbers per soldier, four soldiers a squad.

**The order becomes a cell, and a formula picks it.** ADR-0079 — An order becomes one cell to stand in, and discipline is what the order has to beat (specs/adr/0079-an-order-becomes-one-cell-to-stand-in-and-discipline-is-what-it-has-to-beat.md, accepted) turns each order into one cell per bot: flanking is the reachable cell furthest off the line to the enemy, dispersal the one furthest from the nearest squadmate. So *who goes round from where* is decided by `Orders.zone` and not by the bot — exactly the thing the maintainer says the bots should work out. The bot's only say is whether to go.

**Roles.** FR-CMD-050 — The commander assigns roles (specs/10-fr-cmd.md, implemented) hands out free text that nothing reads; nine calls named fifteen different roles and once answered `flank`, which is an order (Q-630).

**And the thing the rule asks for is missing.** An order has no object. IF-CMD-020 — Commander output (specs/20-interfaces.md, implemented) carries one word from five and nothing to apply it to, so a commander cannot say where the enemy is or where to press them — although the words for places already exist on the way in: the state tells a commander "rival crew: 3 seen, east side and middle" in the arena's own quarters (IF-CMD-010 — Commander input (specs/20-interfaces.md, implemented)). The vocabulary exists on the input and not on the output.

There is also no word for attacking. Of hold, flank, withdraw to a zone, disperse and destroy cover, none of them says *go at them*.

## What the change is worth, measured

The bench, on the Mac, on 2026-10-12, under the shipping instructions, over the three states the game itself builds, with the control in every run (`BENCH_SCHEMA=<flavour> BENCH_SCENARIOS=game-calm,game-pressed,game-last-stand ./bench v5-game,v4-provocative 3`):

| answer shape | calls | blocked | input tokens | output tokens, worst | median latency |
|---|---|---|---|---|---|
| what the game asks for today | 9 | 0 | 762–823 | 283 | 4399 ms |
| threat, order, one number, speaker, line | 9 | 0 | 540–601 | 59 | 2059 ms |
| threat, order, line | 9 | 0 | 516–577 | 43 | 1771 ms |

The control `v4-provocative` was blocked in 9 of 9 in every run, so none of them is void (FR-TOOL-150 — The prompt bench (specs/10-fr-tool.md, implemented), FR-TOOL-160 — The bench carries a control that must be blocked (specs/10-fr-tool.md, implemented)). The answer this plan proposes — threat, order, the part of the arena, speaker, line — sits between the second and third rows and nowhere near the first.

**That is the same lever Q-570 has been waiting on.** ADR-0078 — The commander's frames are lost to the clock and not to the code, so the only lever left is the work asked of the model (specs/adr/0078-the-commander-s-frames-are-lost-to-the-clock-and-not-to-the-code.md, accepted) measured the frames going into generating tokens, and found no other handle: not the thread, not the priority, not the cache, not the field names. Here the token count falls by four fifths because the game stops asking for something it should not have been asking for. The frame rate is a consequence of the design decision, not a thing traded against it.

**And it dissolves Q-640.** An order that names a region instead of a cell needs no fifteen-metre walk per bot per slot: the bot scores the cells it is already scoring. The 0.484 ms median deliberation goes back to where it was.

**Two numbers this does not buy.** The phone, not the Mac, decides whether NFR-PERF-030 — A commander inference does not break the frame budget (specs/30-nfr.md, deferred) and NFR-PERF-040 — Commander answers within its interval (specs/30-nfr.md, deferred) are met, and neither is verifiable at all without the autopilot Q-570 asks for. Step 6 re-measures on the phone; it does not promise a verdict.

## What the concept says, and why this is a change to it and not a reading of it

Concept §9.1 is explicit, and against the maintainer's new rule: "Веса личности — самая важная часть. Именно через них LLM влияет на поведение, не участвуя в покадровых решениях." §9.2 builds on it: "Веса от командира входят в формулу как множители."

The intent behind that sentence is the maintainer's own — the model shapes behaviour and takes no per-frame decisions — and this plan keeps the intent and changes the instrument: a strategic order with an object shapes behaviour at least as well as editing a soldier's character, and it is the one of the two that a squad can disobey. The same section already describes the other half of the rule, in §9.2: "Приоритет задаёт командир, но utility-слой корректирует его локально... Дисциплина определяет, насколько бот держится приказа вопреки локальной обстановке."

**This is recorded as an amendment to the concept, not as an interpretation of it.** The requirement rationales that cite §9.1 for the weights are rewritten in the same change.

## The steps

### Step 1 — The answer the commander may give *(changes the specification)*

Reword IF-CMD-020. The proposal:

> When a commander responds, the system **shall** accept only a structured response carrying: a threat priority from {enemy, snake, withdraw}; an order from {hold, press, flank, withdraw, disperse}; the part of the arena the order names, in the words IF-CMD-010 uses for a place, or none; a truce action from {none, propose, accept, reject}; and, for a speech call, the speaker's name and one line of at most the line length of the speech configuration; rejecting any response that does not parse into this shape; every numeric field carrying its permitted range as a generation constraint.

Three changes to the sentence, each with its reason: the crew disappears, which is the roles and the weights going; the order gains the part of the arena it names; and `press` joins the five words while `destroyCover` leaves them, having named no cell since it was written and needing a bot that can wreck a wall (FR-BOT-070 — Heavy and sapper weapons destroy cover (specs/10-fr-bot.md, deferred)).

The clause about numeric fields stays although nothing numeric is left: it binds the next field somebody adds, and that is what it was written for.

Then the code: `GeneratedDecision` in `Sources/CrawlCall/Commander/SystemModelCommander.swift` loses its `crew`, `CommanderDecision` loses its leans, and the crossing between them — the only place an answer is accepted or rejected — loses the per-soldier matching by name.

### Step 2 — An order has an object *(changes the specification)*

Reword FR-CMD-040 — The commander issues an order (specs/10-fr-cmd.md, implemented). The proposal:

> When a commander's response arrives, the system **shall** set the squad's current order to the one the response names — hold, press, flank, withdraw or disperse — together with the part of the arena the response names with it, for use in its bots' deliberation.

The place vocabulary is the one `SquadView.place` already writes on the way in — the arena's quarters, with the middle its own answer — so the commander answers in the words it was spoken to in, and nothing new has to be measured for safety (ADR-0017 — The model speaks in the comedy register, and one list says what a line may contain (specs/adr/0017-comedy-register-and-a-single-content-list.md, accepted), ADR-0077 — The commander is asked through a seam, and told in the words that were measured (specs/adr/0077-the-commander-is-asked-through-a-seam-and-told-in-the-words-that-were-measured.md, accepted)).

### Step 3 — A named part raises what a position is worth *(changes the specification: a new requirement)*

The mechanism, and the heart of the plan. A bot already scores a position by what it is worth: its height above the snake (FR-BOT-110 — Height advantage enters position scoring (specs/10-fr-bot.md, implemented)), its distance along the snake's path (FR-BOT-115 — Distance along the snake's path enters position scoring (specs/10-fr-bot.md, implemented)), and, while its squad is alarmed, lying near a squadmate (FR-BOT-190 — Alarmed squads keep together (specs/10-fr-bot.md, implemented)). The order becomes a fourth term in the same sum:

> **FR-BOT-116 — An order's part of the arena raises what a position is worth** *(a proposal; the specification does not carry this number)*
>
> When scoring a position for a bot whose squad is under an order naming a part of the arena, the system **shall** raise the score of positions in that part.

That is the whole of it, and it is why the bots come to do the tactics: cover is still chosen by what is hidden, flight by what is far, firing by what is in view — and every one of them now leans towards where the commander pointed. Who ends up on the flank is whoever was nearest it with a wall to hide behind, not whoever `Orders.zone` named.

What each word of the order does with its part is a decision for the ADR, and the proposal is this table:

| order | what it does |
|---|---|
| hold | the part the squad is in is the named one; the obedience term keeps a bot from leaving it |
| press | positions in the named part are worth more, and the threat priority does the rest |
| flank | positions in the named part are worth more, and positions on the straight line to the enemy are worth less |
| withdraw | positions in the named part are worth more, and nearness to the enemy is worth less |
| disperse | positions near a squadmate are worth less, which is FR-BOT-190 turned around |

`Orders.zone` and the fifteen-metre walk go; `Situation.orderedZone` becomes a part of the arena rather than a cell, and the obedience term of FR-BOT-090 — Personality weights multiply utility (specs/10-fr-bot.md, implemented) scores it where it scores it now.

### Step 4 — Withdraw what the rule forbids *(changes the specification)*

**FR-CMD-060 — withdrawn.** Nothing requires it: `python3 srs-dd/tools/srs_view.py FR-CMD-060` prints no incoming link. The weights go back to being the archetype's own (FR-BOT-030 — Archetype sets base personality weights (specs/10-fr-bot.md, implemented)) and the bot's, which is what the silhouette promises the player. The rationale says why, names the concept sentence it reverses, and the number stays dead.

**FR-CMD-050 — withdrawn**, with one dependant to settle first, as the `srs` skill asks. FR-CMD-125 — Losing the role-holder voids orders and roles (specs/10-fr-cmd.md, implemented) obliges a squad that lost its commander to clear its order *and* every bot's role. With roles gone it is narrowed, not cascaded:

> When the bot holding a squad's commander role is consumed or killed, the system **shall** clear the squad's current order.

Its title changes with it. `Bot.role` leaves the model, and `SquadView` stops writing `jobs you gave:` into the state — which is a change to the state's vocabulary and so another bench run (FR-TOOL-170 — A bench measurement names the configuration it covers (specs/10-fr-tool.md, deferred)).

Q-630 is settled by this step: the question was whether to close the role vocabulary or say out loud that a role is something a commander says to itself, and the answer is a third thing — there are no roles.

### Step 5 — The code

In the order the parts depend on each other: the generated shape and the crossing (step 1), the command the squad holds (`SquadCommand`), the scoring term (`Deliberation.worth` and `Situation`), then `Orders.swift` deleted, then `Game` and the state.

Nothing in `Sources/CrawlCall/Bot` learns what a commander is: the deliberation gains a named part and a term, which is the same shape it already has for the snake's path and for squadmates.

### Step 6 — Measure, twice

The bench over the new state and the new schema, with the control, because three of FR-TOOL-170's four axes move at once: the schema, the state's vocabulary (no more `jobs you gave:`) and nothing else. Then the phone, with `CRAWLCALL_RECORD`, against the run of 2026-10-12 recorded in the plan beside this one: 2010 frames, 43.7 a second, the app's own work 1.60 ms median and 3.28 at the 95th, deliberation 0.484 ms median in a deliberating frame, thermal `nominal`.

What to expect, and what to report honestly if it does not happen: the commander's answer should cost about a quarter of what it costs now, the deliberation should fall back to about 0.2 ms, and the frame rate should move towards the 58.4 a second the no-commander control gives.

### Step 7 — Close the loop

Statuses, `code`, `tests` and annotations; the withdrawn numbers into their rationales; E-150 — The commanders (arch/00-elements.md, proposed) loses the requirements that no longer exist; the concept amendment; `python3 srs-dd/tools/srs_check.py`, `srs_arch.py`, `srs_grounds.py`, `scripts/arch-edges.py`, the `srs-check` procedure, the whole suite, the phone.

## What this plan does not touch

The commander's voice and the truce — FR-CMD-090 — A commander may propose a truce (specs/10-fr-cmd.md, deferred), FR-CMD-140 — Bots speak on events (specs/10-fr-cmd.md, deferred) and IF-CMD-030 — Speech configuration (specs/20-interfaces.md, deferred) — are steps 6 and 7 of `materials/plans/the-commanders.md` and are unbuilt either way. The speaker and the line stay in the answer's shape because that is where they were written, and they are still parsed and dropped.

Q-620 — the two survivors of a won match pacing — is untouched, and so is the half of FR-SCORE-150 — The match ends when no bot is left (specs/10-fr-score.md, partial) that lets a won match run on.

The interval, the stagger and the thermal degradation are unchanged.

## The decisions that belong to the maintainer

1. **`press` in, `destroyCover` out.** The first is the word the rule asks for and the game has no way to say; the second has named nothing since it was written and comes back with FR-BOT-070.
2. **The places are the arena's quarters** — north, south, east, west, the middle, and "upstairs" — because that is what the commander is already told. The alternative is named landmarks, which would need a map to name them and a vocabulary nobody has measured.
3. **Whether a bot keeps a personality the commander can no longer touch.** This plan says yes: the archetype's, moved by nothing but the collapse of its squad (FR-CMD-130 — Collapsed bots keep their last weights, with more panic (specs/10-fr-cmd.md, implemented)). If the maintainer wants the model to shape a squad's mood at all, the smallest honest form is one number for the whole squad rather than five per soldier — and it is not in this plan.
4. **The concept amendment**, which is the maintainer's document: §9.1's sentence about the weights is the one this plan reverses.
