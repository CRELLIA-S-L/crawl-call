# The reload, the rush, and a grenade you can see

A plan written on 2026-10-13, the day after the arms were built (ADR-0086, ADR-0087, ADR-0088), from six things the maintainer asked for after watching what the squads had become.
It is written so that an agent with no memory of that conversation can take it up: everything it needs is here or pointed to from here.

**Nothing here is in the specification yet.** Every `FR-` number below is a proposal and is marked as one; the first step of each pass is the authoring dialog (`srs-new`), and the maintainer decides whether each is written at all. Numbers were taken as the next free ones in their areas on 2026-10-13 — BOT ran to 520 and VIEW to 340 — and a number that turns out to be taken by then is renumbered without anything else changing.

Every number of the shipped tuning below is a proposal too, and the maintainer's to feel out on the phone.

## What was asked

1. Reloading the primary should take longer.
2. The number of spare magazines should be limited — three may be enough.
3. The choice between hiding to reload and drawing the pistol or the knife to rush in should depend on the bot's courage.
4. A thrown grenade must be drawn, with the physics of a thrown thing, and bouncing off surfaces would be good.
5. The blast must be drawn.
6. A bot choosing where to go must take into account the cells other bots hold, and the cells other bots are already making for, and not try to get into them.

Five of the six change behaviour; two of those five also change what is on the screen. The sixth is the smallest and makes every other one look better, which is why it goes first.

## What is being built

| Proposed | What it would oblige | Ask |
|---|---|---|
| FR-BOT-530 *(proposed)* — A bot does not set out for a cell another bot holds or is making for | every cell a bot picks to move to leaves out the occupied and the claimed | 6 |
| FR-BOT-540 *(proposed)* — Each firearm that is not full is a reload of its own | one reload action per weapon, as FR-BOT-460 gives one fire action per weapon | 1, 2 |
| FR-BOT-550 *(proposed)* — A reload takes the weapon's own time | the magazine fills only after that weapon's reload time of unbroken reloading | 1 |
| FR-BOT-560 *(proposed)* — A bot carries a limited number of spare magazines | each reload spends one; with none left the weapon stays empty | 2 |
| FR-BOT-570 *(proposed)* — A bot closes with what its weapon does not reach | a weapon that would reach from a nearer cell makes that cell an action | 3 |
| FR-BOT-580 *(proposed)* — A thrown grenade falls and bounces | an arc under gravity, and a bounce off what it meets | 4 |
| FR-VIEW-350 *(proposed)* — A thrown grenade is drawn where it is | the grenade on screen while its fuse burns | 4 |
| FR-VIEW-360 *(proposed)* — A blast is drawn where it went off | the explosion on screen for a moment after it | 5 |

And four records already written would be amended:

- **FR-BOT-090 — Personality weights multiply utility (specs/10-fr-bot.md, implemented)** — its courage bullet gains the other half of ask 3. It is the enumeration of what each weight scales, and the project has amended it before rather than writing a second requirement beside it: courage itself was added to that list on 2026-09-25. The amended bullet, as it would be written:

  > - courage, scaling the terms for facing danger — firing at it, holding ground under it, closing with it — up, and the term for stepping out of it to reload down;

- **IF-BOT-010 — Bot and match configuration (specs/20-interfaces.md, implemented)** — each firearm's reload time and the spare magazines each archetype carries (asks 1 and 2), and the bounce the tuning gives a thrown thing (ask 4), unless that last one belongs in IF-MAP-020 — Tuning configuration for destruction and maps (specs/20-interfaces.md, implemented) beside the gravity it falls under.
- **FR-BOT-425 — A bot reloads behind cover (specs/10-fr-bot.md, implemented)** — its rationale says in so many words that "a reload takes no time of its own" (ADR-0063). Ask 1 reverses that, and the ADR gets a superseding record rather than an edit.
- **FR-BOT-500 — A bot does not throw where it would catch a squadmate (specs/10-fr-bot.md, implemented)** — see pass D: once a grenade bounces, where it was thrown and where it goes off are two places, and the requirement has to say which one it refuses.

## What is already there to build on

**The claimed cell already exists, in one place.** `Deliberation.post(for:aim:in:)` builds a set of the cells its squadmates have taken as their firing post and their refuge and leaves them out — "a squadmate's cells are its own: two bots making for one cell push each other off it for as long as both want it". Ask 6 is that rule, generalised to the other four places a cell is chosen. ADR-0064 is the other half of it: a bot walking already stops against a bot standing on the cell it is making for, which is FR-BOT-300 — Bots do not pass through one another (specs/10-fr-bot.md, implemented).

The five places that choose a cell, all in `Sources/CrawlCall/Bot/Deliberation.swift`:

```
cover(for:from:enemies:in:)   taking cover (FR-BOT-119 — A bot in cover stays in it (specs/10-fr-bot.md, implemented))
away(from:for:in:within:)     fleeing (FR-BOT-118 — A bot flees to somewhere it can get to (specs/10-fr-bot.md, implemented))
ordered(for:in:)              an order's place (FR-BOT-116 — An order's part of the arena raises what a position is worth (specs/10-fr-bot.md, implemented))
quiet(for:in:)                advancing and exploring
post(for:aim:in:)             where it fires from (FR-BOT-420 — A bot fires from beside cover (specs/10-fr-bot.md, implemented)) — already done
```

The two the quiet motives use are FR-BOT-360 — An idle bot advances on the enemy (specs/10-fr-bot.md, implemented) and FR-BOT-370 — An idle bot goes to see what it has not seen (specs/10-fr-bot.md, implemented).

Four of the five walk the graph through one function, `walk(from:within:for:in:)`, so the filter has one place to live.

**A timed act has a precedent.** FR-SNAKE-090 — Eating takes time and holds the snake in place (specs/10-fr-snake.md, implemented) is the shape ask 1 asks for, and its rationale is the argument for it: "instant eating makes 'eat or leave' a free and therefore nonexistent choice". A reload that takes no time is a free choice in exactly the same way, which is why a bot with a dry rifle reloads rather than drawing anything (ADR-0086 measured it: `fire sidearm` was chosen zero times in a hundred and fifty seconds).

**A pool of entities for something that comes and goes.** `Sources/CrawlCall/View/ShotEntity.swift` makes a bar per round a bot can have in flight, once, and moves them; `Tracers` in `Sources/CrawlCall/Config/Drawing.swift` holds its numbers. Asks 4 and 5 are two more of those, and FR-VIEW-170 — A round is drawn in flight (specs/10-fr-view.md, implemented) is the requirement to read first.

**The grenade is already a value that lives across frames.** `Sources/CrawlCall/Bot/Blast.swift` holds `Thrown` — where it lies and how much fuse is left — and `Game.grenades` carries them. Ask 4 adds a velocity to it and a step to `Blast.burn`; ask 5 adds what is left behind when one goes off.

**Gravity and what a line meets are both already read.** `config/tuning.json` has `dropGravity` at 9.8, which FR-SNAKE-220 — A drop is a path, not a fall (specs/10-fr-snake.md, implemented) falls under, and `Sight.firstStop(from:to:through:)` gives the share of a segment at which it first meets something solid — the same call `Flight.fly` uses for a round (FR-BOT-405 — A round stops at what it meets (specs/10-fr-bot.md, implemented)).

Measure the starting point before changing anything:

```
grep -rn "arms.reload()" Sources Tests      # 3 on 2026-10-13
grep -rn "walk(from:" Sources               # 4 on 2026-10-13, the cell searches of pass A
```

## The passes, in order

Four passes. Each is finished — suite green, build on the phone, loop closed — before the next begins. Under ART-030 of `specs/constitution.md`, amended 2026-10-11, the suite runs when a change is finished and the build goes on the phone when one is connected, neither asked for nor waited for.

**Passes C and D end differently from the others.** Pass C changes how the squads behave in a way only an eye at the camera's distance can judge, and pass D changes what is drawn; the maintainer's standing instruction for visual work is one change at a time, installed and then looked at before the next. So those two stop at the device and wait for a word, where A and B report and go on.

### Pass A — Nobody walks into anybody (ask 6)

Build FR-BOT-530 *(proposed)*.

**The statement, as it would be written:**

> When a bot chooses a cell to move to, the system **shall** leave out the cells a bot it sees stands in and the cells its own squad is already making for.

**Why those two sets and not one.** A bot acts on what it knows (FR-BOT-220 — A bot acts on what it knows (specs/10-fr-bot.md, partial)). Where a bot stands is something it can see, so an enemy in view occupies a cell as much as a squadmate does; where a bot is *going* is something only its own squad can know, because nobody tells it the other crew's plans. An enemy it remembers and does not see now occupies nothing: the memory is of a place it was.

**Where a claim comes from.** `Execution.destination(of:)` already answers "where is this bot's action sending it" for every action that sends it anywhere, and every bot's last decision is on the bot. The claimed set is that over the living squadmates, computed once per deliberation — at most one entry per bot of a squad, which is what keeps this inside NFR-PERF-020 — Deliberation costs at most 0.5 ms per frame (specs/30-nfr.md, deferred). The function is pure and is moved where both files can use it rather than being written twice.

**The decision table, written before the code:**

| The cell | Chosen? |
|---|---|
| where the bot itself stands | yes — it is not somewhere it is going, and FR-BOT-119 already says what being there means |
| where a squadmate stands | no |
| where a squadmate's action is sending it | no |
| where an enemy in view stands | no |
| where an enemy it remembers and cannot see stood | yes — it knows nothing about now |
| where a body lies | yes — nothing in the game treats a body as an obstacle: `Execution.separate` pushes only the living apart, saying that a body "lies on the floor and is stepped over" (FR-BOT-320 — A bot with no health left is a body (specs/10-fr-bot.md, implemented)) |
| the only cell left after the exclusions | there may be none, and the action is then not on the list at all, as every action with nothing to act on is |

**Negation for this pass:** put two bots a step apart with one cover cell between them, give both a slot in the same frame, and confirm a test goes red when the filter is removed — the second bot picks the cell the first is walking to.

### Pass B — A reload costs time and magazines, and courage decides whether to pay (asks 1, 2, 3)

Build FR-BOT-540, FR-BOT-550, FR-BOT-560 *(all proposed)*, and amend FR-BOT-090.

**The three statements, as they would be written:**

> **FR-BOT-540** — When scoring actions for a bot, the system **shall** score reloading each firearm it carries that is not full and has a spare magazine left as an action of its own.
>
> **FR-BOT-550** — When a bot has chosen to reload a firearm for that firearm's reload time without choosing anything else in between, the system **shall** fill that firearm's magazine.
>
> **FR-BOT-560** — When a bot's reload fills a magazine, the system **shall** take one spare magazine from what that bot carries for that firearm.

The other half of ask 2 — that a firearm with no spare left cannot be reloaded at all — is a condition of FR-BOT-540 above and not a second sentence here: one requirement, one obligation, and "there is nothing to reload with" belongs where the action is offered.

**One reload per weapon, which is a change to a decision made this morning.** ADR-0086 settled that one reload fills everything a bot carries, "because one reload is one act". With a time per weapon that reading stops working: the primary's reload is to be the longer one, and a single act cannot take two lengths. So the reload joins the fire action in being one per weapon (FR-BOT-460 — Each weapon that reaches is an action of its own (specs/10-fr-bot.md, implemented)), the action carries the slot, and the ADR for this pass supersedes that part of ADR-0086. What it costs is in the table below; it is also what makes a bot with a full pistol and a dry rifle choose which to fill.

**Abandoning a reload loses it.** A bot that chose to reload and then chose anything else at its next slot has gained nothing, and starting again starts from the beginning. That is the decision to record, and the alternative — progress kept per weapon and resumed — was left alone for one reason: a bot that can duck out, fire, and duck back without losing the reload is a bot for which reloading is free again, which is the thing this pass exists to end.

**What it does not do is hold the bot.** FR-SNAKE-090 holds the snake in place while it eats; a reload does not hold a bot. It can walk, it can be interrupted (FR-BOT-170 — Interrupts grant a slot at once (specs/10-fr-bot.md, partial)), and anything else it decides ends the reload. A bot frozen for two seconds while the snake arrives is the standing still the concept calls the signature stupidity.

**The state, and where it lives.** One field on the bot — which firearm is being filled and at what time of the match the filling ends — set when the action is first chosen, cleared by any other action, read every frame in `Execution`. A bot that reaches the end of the time and still wants it gets the magazine and spends the spare.

**The numbers to ship, and why:**

| | reload time | spares |
|---|---|---|
| every primary | 2.0 s | 3 |
| the pistol | 1.0 s | 2 |

Two seconds is ten deliberation slots and about a third of a commander's interval: long enough that a bot which starts one is out of the fight for a visible moment, short enough that a magazine of thirty rounds spent in six seconds of firing is not mostly waiting. Three spares is what was asked for, and it makes a primary good for four magazines in all: 120 rounds, which at a round every 0.2 s is twenty-four seconds of unbroken firing. The match the arms now produce is over at the fifty-third second (ADR-0088), and in it the bots reloaded long before running out — the reload term climbs as the magazine empties and wins well short of the last round. So four magazines may not bite at all on the shipped arena, and the measurement after this pass is what says whether a bot ever reached its last one. **Say in the report that it did not bite**, if the measurement says so, rather than letting the requirement look exercised.

**Courage, and the two terms it pulls on.** The amendment to FR-BOT-090 above is the whole of ask 3's first half: the reload term is scaled by what is left of the bot's courage. The shape follows the one the project already uses for health and cover — a share rather than the whole, so that a bot of courage 1.0 still reloads when there is nothing else to do:

```
reload = empty × spent² × (whole − courage × reloadCourageShare)      shipped share: 0.5
```

Worked through at today's weights, for a bot with a dry primary and an enemy a metre away: reloading is worth `1.2 × (1 − 0.5c)` and a knife strike `2.0 × 0.833 × aggression × c`, which for an assault's aggression of 0.7 cross at a courage of about **0.68**. The shipped courages are assault 0.7, heavy 0.8, sapper 0.5, scout 0.3, sniper 0.5, medic 0.4 — so the assault and the heavy would close and the other four would duck away and fill the magazine, which is the split ask 3 describes and a good sign that the share is in the right place.

**That arithmetic is to be re-derived in the pass and not trusted from here**: this pass changes the reload term itself, because a reload is per weapon from now on and `spent` stops meaning the emptiest of two.

**Negation for this pass:** three, one per requirement. Remove the time and confirm a test goes red that asserts a magazine is still empty one frame after the reload began; remove the spare count and confirm a test goes red that asserts a bot which has reloaded four times cannot reload a fifth; remove the courage share and confirm a test goes red that asserts two bots differing only in courage choose differently between reloading and striking.

**Measure the match after it**, with the probe used for the arms: a temporary test that runs the shipped arena for 150 seconds with nobody steering and prints what was chosen, what was left and who died when, deleted before the commit. What to look for: whether `fire sidearm` and `throw knife` — both built and chosen zero times on 2026-10-12 — are chosen now.

### Pass C — A bot rushes in (ask 3, second half)

Build FR-BOT-570 *(proposed)*. This is the first of the two passes that end at the maintainer's eye.

**The statement, as it would be written:**

> When a bot carries a weapon with ammunition whose range does not cover its target, and a cell it can reach would bring that target within that weapon's range, the system **shall** score moving to that cell as an action of its own.

**Why it is shaped like FR-BOT-460 and not like an order to charge.** Each weapon that reaches is already an action; this is each weapon that *would* reach, and the same chooser decides. A bot with a loaded primary is not a candidate — its weapon reaches already — so this never turns a firefight at range into a rush. The bot it describes is the one with a dry rifle, a pistol good for six metres and an enemy at eight: a rule would make it either always charge or never, and the score makes it depend on how brave it is and on what else there is to do.

**What the cell is.** The nearest cell within the cover search distance, over the graph, from which the distance to the target is inside the weapon's range — and it is subject to pass A, so a cell a squadmate has claimed is not it.

**What it is worth.** What firing with that weapon from that cell would be worth, scaled by how near the cell is — the same `nearness` within the search distance that cover already uses for how handy it is. A cell a step away costs almost nothing and one at the edge of the search costs most of what it would gain, which is what keeps a bot from crossing a room under fire for a pistol shot. Courage multiplies it, by the amendment in pass B.

**A knife rush is the same action.** The knife's reach is a bot's arm, so the cell it asks for is the one the enemy is standing beside — which pass A will have taken out if a squadmate is already there, and which the enemy itself occupies. Read that case in the test: the cell chosen is *next to* the target and never the target's own.

**Negation for this pass:** remove the action and confirm a test goes red that asserts a bot with an empty primary, a full pistol and an enemy a metre beyond the pistol's range moves instead of standing.

**Then the phone, and then stop.** Install, watch a match, and ask the maintainer whether the rushes read as brave or as suicidal. The requirement is cheap to narrow — by courage above a threshold, by health, by how many of its squad are still up — and all three of those are the maintainer's to pick between after seeing it.

### Pass D — A grenade you can see, and an explosion (asks 4, 5)

Build FR-BOT-580, FR-VIEW-350, FR-VIEW-360 *(all proposed)*. This pass ends at the maintainer's eye as well, and it is the one with real unknowns.

**The statements, as they would be written:**

> **FR-BOT-580** — While a thrown grenade has fuse left, the system **shall** move it along a path falling under the tuning's gravity, and **shall** turn it back off any surface it meets, keeping a share of its speed.
>
> **FR-VIEW-350** — While a thrown grenade has fuse left, the system **shall** draw it where it is.
>
> **FR-VIEW-360** — When a grenade goes off, the system **shall** draw the blast at the place it went off, out to the blast radius, for a moment after it.

**The arc.** A throw gets a velocity instead of a destination: the grenade leaves the bot's hands at a fixed angle above the level and at the speed that would land it at the aim point under the tuning's gravity, and a throw whose aim is further than that speed can carry falls short — which is what makes the throw range a real limit rather than a teleport. The ballistics are one square root and are in the plan rather than in the code because it is the one place a sign error is invisible: for a launch angle `θ`, a flat distance `d` and gravity `g`, the speed is `√(g·d / sin 2θ)`, and at 45° that is `√(g·d)`.

**The bounce.** Every frame the grenade steps from where it is to where its velocity takes it. `Sight.firstStop` says whether that step meets something solid and how far along; the arena is a grid of axis-aligned modules, so which face it met is which cell boundary the step crossed at that share, and the bounce is the velocity's component along that axis turned round and the whole scaled by a restitution. The ground is the same thing with the floor's height as the surface. **Where the share cannot be turned into an axis** — a corner, two crossings in one step — the grenade stops where it is rather than guessing, which is a quiet lie for one frame and never a grenade inside a wall.

Restitution to ship: 0.35, and below a tenth of a metre a second the grenade is at rest and only burns fuse. The number is tuning and goes with the grenade's other numbers.

**What this does to FR-BOT-500.** Where a grenade is thrown and where it goes off become two places. It reads, today: "If a squadmate the bot sees stands within the blast radius of where it would throw, the system **shall not** have the bot throw there." With a bounce, "where it would throw" is the aim and not the landing, and the words have to say which they mean. Two ways out, and the first is recommended: reword it to refuse the aim, and let a bounce onto one's own squad be of a piece with the friendly fire ADR-0075 already accepted; or simulate the throw at every slot and refuse the landing — which is the whole flight, a hundred and twenty steps of a sixtieth of a second each asking the scene what the step meets, for every throw the bot is scoring, against a deliberation budget of half a millisecond for everything. **Settle this with the maintainer before building the pass**, because it decides whether the squads can grenade themselves.

**What is drawn.** A sphere the size of the grenade, from a pool made once, moved where the grenade is — the tracers' pattern exactly (`ShotEntity`). The blast is a second pool: a sphere grown from nothing to the blast radius and faded out over a short life, which means the match has to keep the fact that a blast happened for that long. It keeps it the way it keeps a round: a value in the model that the view reads, with a life that the frame counts down, because every other thing on screen in this game is a function of the model and a view with a clock of its own would be the first that is not.

**Negation for this pass:** remove the gravity and confirm a test goes red that asserts a grenade thrown across a room is lower at the end of its fuse than at the start; remove the bounce and confirm a test goes red that asserts a grenade thrown at a wall a metre away comes back towards the thrower; remove the blast's life and confirm a test goes red that asserts the blast is on screen the frame after it went off.

**Then the phone, twice.** The grenade first, judged, and the explosion after it — the maintainer's standing instruction is one visual change at a time.

## Close the loop

Each pass ends with it; the last one ends with all of it:

- statuses, `code` and `tests` in the same set of edits as the code, and every file named there saying so back with `file implements:` / `file verifies:`;
- the new requirements into E-090 — The squads (arch/00-elements.md, built) and the two drawing ones into E-050 — The view (arch/00-elements.md, built) — this project writes `requirements` by hand, and `AGENTS.md` makes that part of closing the loop;
- `python3 srs-dd/tools/srs_check.py`, `srs_arch.py`, `srs_grounds.py`, read whole and not by the last line;
- FR-BOT-425's rationale corrected in the pass that makes a reload take time, and the ADR that said otherwise marked superseded;
- FR-BOT-500 reworded in pass D, whichever way the maintainer settles it.

## What stands on a bet

Nothing here is carried by a hypothesis in `grounds/`, and the question was asked. The nearest is H-030 — Watching someone else's fight beats chasing (grounds/10-h-mechanics.md, assumed), which is what the second squad is staked on, and the maintainer declined it for the arms on 2026-10-11 on the ground that they are core and stand on their word. The same answer fits these six: they are the maintainer's own observations of the squads on the screen, and an absence of a bet here is a decision rather than a gap. `srs-bet` is the procedure if that changes.

## Risks, named

**The match will change shape again, and the tests that read it will say so.** Each of the last three passes moved when the squads die, and two of them turned a match-level test red — `IdleTests`' movement floor and the commander-collapse test's reading of the other squad. Expect the same here, expect to read each failure as a measurement rather than a fault, and expect to say in the report which window of the match the test now reads and why.

**A reload that takes time makes the firefight slower and might make it dull.** Two seconds out of the fight for every magazine is a lot at the shipped cadence, and the arms already made the match end at fifty-three seconds. If the squads start spending the fight reloading, the lever is the time, then the magazine size — and the measurement is the probe, not an impression.

**The rush can read as suicide.** A bot that runs at an enemy with a pistol will often die on the way, and courage is the only thing holding it back. This is the pass most likely to come back as "no", which is why it stops at the phone.

**Bouncing is where the frames go.** A grenade is one moving point and a handful exist at once, so the arithmetic is nothing; what is not nothing is asking the scene what a step meets, which is the same call the rounds make and which NFR-PERF-010 — 60 frames per second on the baseline device (specs/30-nfr.md, deferred) is measured against. Measure the frame record on the device with grenades in the air, not only the suite.

**A grenade can bounce back and kill the thrower's own squad.** That follows from FR-BOT-480 — An explosion strikes every body within its blast (specs/10-fr-bot.md, implemented) taking everyone in it, and it will look like a bug from the camera. It is in ADR-0075's reasoning already — any weapon hits your own — but it will be seen for the first time here.

## What this plan deliberately leaves out

- **Destruction.** FR-BOT-070 — Heavy and sapper weapons destroy cover (specs/10-fr-bot.md, deferred) waits on FR-MAP-030 — Destructible modules have three states (specs/10-fr-map.md, deferred), as it did for the arms.
- **Posture**, Q-340: a lying bot throws no grenades, and nothing here needs to know how a bot stands.
- **The standstill at the end of a match** — Q-480, Q-490 and Q-620. Pass A touches the same machinery and will not settle them; the question of what two bots that have lost each other should do is the maintainer's, and FR-SCORE-150 — The match ends when no bot is left (specs/10-fr-score.md, partial) is half of it.
- **Picking a magazine up.** There is no gathering in this game — the rationale of FR-BOT-520 — A thrown knife leaves the bot (specs/10-fr-bot.md, implemented) says so, and a bot out of spares stays out.
- **Drawing the reload.** A bot with its hands busy is the territory of FR-VIEW-340 — A bot holds the weapon it is using (specs/10-fr-view.md, implemented) and nobody asked for it; it is one line of this plan away when somebody does.

## The decisions that belong to the maintainer

1. Whether each proposed requirement is written at all, and in the words above — the authoring dialog of `srs-new` is where that happens, one requirement at a time.
2. **Pass D's first question, before any code:** does a bot refuse the throw it aims at a squadmate, or the one that would land on one? The first is cheap and honest about what a bot can know; the second is a promise the game can keep and a bot cannot.
3. Whether the rush of pass C survives the phone, and if not, which way to narrow it.
4. The numbers: two seconds and three spares, the restitution, how long a blast stays on screen.
