# Open issues

Discrepancies between the specification and the code, unfinished work, unresolved questions.
Each entry states what diverged, where it was found, and what decision is needed.
Entries are removed once the maintainer decides which side is right and the fix lands.

Entries are numbered `Q-NNN` in tens so that a requirement's rationale can name one; a number is never reused.
Sixteen questions were opened on 2026-09-21 by the decomposition of the concept and fourteen were settled the same day; each settlement is an ADR, so a closed number is found by searching `specs/adr/` for it: Q-010 and Q-090 in ADR-0009, Q-020 and Q-030 and Q-050 and Q-060 in ADR-0010, Q-070 and Q-080 in ADR-0013, Q-100 in ADR-0011, Q-110 in ADR-0014, Q-130 in ADR-0012, Q-150 in ADR-0015; Q-040 became FR-SNAKE-220, Q-140 a sentence in NFR-PERF-010's rationale and Q-160 FR-VIEW-120.
Q-220 — what lies under a wall when a cell holds one module — was opened and settled the same day it was found: the floor is implied under every cell whose module is not walkable (FR-TOOL-020), and a hole is what a map declares on purpose (FR-MAP-110, `draft`).
Two more were opened and settled on 2026-09-22 by the maintainer: Q-190 — whether a severed tail segment stays in the arena — became H-080, and Q-200 — the hypothesis the shedding requirements rest on — became H-070, both in `grounds/10-h-mechanics.md`; a question that turns into a measurement is closed here and answered there.
One more was opened and settled on 2026-09-23, when the kit's wall came down to a fence: Q-240 — whether a bot sees over what the player sees over — became the second paragraph of FR-BOT-050's rationale, which ADR-0022 rewrote on 2026-09-24 when bots got eyes to look from.
Q-230 — the head kept to walkable cells by its centre while its body, wider than a cell, sank into the wall beside it — was opened on 2026-09-22 and settled on 2026-09-24 by ADR-0021: the body is kept out of walls by their geometry. The entry offered a finer grid as one way out and had it backwards; the ADR says why.
What remains is what a decision inside the repository cannot close.

### Q-120 — The name is chosen; the search that clears it is not done

- **Found:** concept §14, §17.6; CON-PUB-090.
- **What diverged:** the maintainer settled the name as "Crawl Call: Chomp Company" on 2026-09-22, deliberately ahead of the trademark search rather than after it. The reason the search was asked for stands: "Chomp" is taken in apps (a children's app, a Google Play game, a UK studio), and "Crawl Call" — the half that carries the mark — has not been searched at all.
- **Decided:** on 2026-09-21 the order was search first, name after. On 2026-09-22 the maintainer reversed it and named the game, which changes what the search decides — no longer which name to take, but whether this one survives. A professional search in classes 9 and 41, EU first, is still commissioned before any public announcement, the name appears nowhere outside the repository until then (CON-PUB-090), and registration, if it clears, is by the company (ADR-0007).
- **Still needed:** the search itself — an action outside the repository, in classes 9 and 41, EU first, on "Crawl Call" before the full string. The entry closes when the result is recorded here.
  If it does not clear, what changes is not only the name: the code short name `CrawlCall` — the Xcode target, the source folder and the tail of the bundle identifier — goes with it, which is the cost of having named the game first.

### Q-170 — A hypothesis on bounded waiting, for the maintainer to write

- **Found:** ADR-0010 declines an artificial counterweight to stealth and relies on cover erosion (concept §7) to bound how long a player waits.
- **What diverged:** whether waiting stays bounded in play is a claim about players, and the grounds register's standard reserves writing a hypothesis — population, threshold, owner — to the person who will measure it.
- **Proposed text, not written:** *H-060 — Waiting stays bounded without a timer.* Class III; population: playtesters of the stage-3 build; refuted if `proportion > 0.40 at n >= 5` of sessions contain a single stretch of inaction longer than three minutes while prey is reachable; expires with the stage-3 playtest; impact: if refuted, ADR-0010 gains the decaying multiplier it declined.
- **Still needed:** the maintainer writes it into `grounds/10-h-mechanics.md`, or declines it and says so here.

### Q-180 — The thermal degradation factor

- **Found:** IF-BOT-010; NFR-PERF-060, NFR-PERF-070.
- **What diverged:** the threshold has a default the spike measured — `serious`, which a twenty-minute run on the iPhone 16 Pro never reached — but the factor by which the commander intervals stretch once it is crossed has none. The concept asks for the mechanism (§15) and names no number, and the spike never entered the state the factor applies to, so nothing in the repository measures it.
- **Still needed:** a number from the maintainer, or a session long enough to reach `serious` on the baseline device and read what interval keeps the frame rate. Until then `config/match.json` carries whatever value the build ships and the requirement is unverifiable against a default.

### Q-210 — Does the game target iPadOS, and when does the target learn about macOS?

- **Found:** CON-PUB-010; `specs/02-overview.md` line 7; `ChompCompany.xcconfig`.
- **What diverged:** the overview says the code base targets "iOS, iPadOS and macOS", while the normative constraint names only iOS 27 and macOS 27 on devices with Apple Intelligence — the iPhone 15 Pro and later, and Apple silicon Macs. iPadOS appears in no requirement. The game target created on 2026-09-22 builds for iPhone alone (`TARGETED_DEVICE_FAMILY = 1`, `SUPPORTED_PLATFORMS = iphoneos iphonesimulator`), which settles the question by exclusion rather than by decision.
- **Still needed:** the maintainer says whether iPadOS is a target. If it is, CON-PUB-010 gains it and the device family becomes `1,2`; if it is not, the overview's sentence is corrected. Either way the answer is cheap now and expensive once a second input scheme exists. The macOS half is not a divergence but a sequence: the slice defers FR-VIEW-040, so the target stays iOS-only until the stage that adds keyboard and mouse, and `SUPPORTED_PLATFORMS` grows then.

### Q-250 — The frame rate has been looked at, not measured

- **Found:** NFR-PERF-010; the Metal performance HUD on 2026-09-24.
- **What diverged:** NFR-PERF-010 is verified by `A`, which `specs/50-verification.md` defines as an unattended run along a fixed route with the telemetry pulled from the device afterwards. What exists is a look. On 2026-09-24, after ADR-0020's hole shader went in, the game was launched on the iPhone 16 Pro with the Metal performance HUD: at the match's start it read 59.99 frames per second, a GPU time of 6.86 ms and a frame interval of 16.67 ms, against the 13.3 ms a frame on that phone is held to. In play the maintainer saw a couple of spikes on the HUD's graph, too brief to tie to anything on screen.
- **Decided:** the maintainer judged it good enough for now, on 2026-09-24. A look is not a measurement, so NFR-PERF-010 stays `deferred`.
- **Still needed:** the game's own instrument — per-frame intervals written with their times, an autopilot that drives the snake along a fixed route, a runner and an analyser — modelled on `materials/spike/instrument/`, which no longer runs. No requirement covers it yet, so it is authored before it is built. The spikes seen by eye are exactly what it would place in time.

### Q-260 — The see-through of the walls around the snake does not sit right with the maintainer yet

- **Found:** FR-VIEW-150, FR-VIEW-155; the maintainer on the phone on 2026-09-24, after ADR-0021.
- **What diverged:** nothing in the specification; the build does what FR-VIEW-150 and FR-VIEW-155 ask. The maintainer found the see-through of the walls around the snake somewhat off, and put it off for later. Two things cut a wall near the snake open. The line of sight: a wall within the body's radius plus the see-through margin of IF-VIEW-020 — 0.3 + 0.15 = 0.45 m — of a line from the camera to any part of the snake (ADR-0019, ADR-0020); since ADR-0021 a wall the body touches on the camera's side or on either flank is 0.3 m from the head's centre and within that, while one the body touches from behind is not, the line stopping that margin short of the head (ADR-0019, point 2). And the window around the head: any module within the visibility radius, 1.6 m, that is not wholly beyond the head and stands higher than the floor the head is on (FR-VIEW-155).
- **Still needed:** the maintainer says what about it is off — too many walls, too much of each, or the look of the hole — and which of the two it comes from. The numbers are in `config/view.json`; the shape of the hole is ADR-0020's.

### Q-270 — The world around the arena is agreed and not built

- **Found:** the maintainer on 2026-09-24, asking for a sky, the space beyond the map, birds and vegetation.
- **What diverged:** nothing yet; around the arena there is nothing, drawn black on the phone and white in the simulator. The maintainer agreed on 2026-09-24 to a first setting — the arena on an island, with water, trees, a daylight sky and birds — to settings as families a map names, so that a crater, a spaceship, a forest clearing or a building can follow, and to a world that need not be endless, only larger than all the match camera can show, the camera's angle being frozen in the released game. They asked for the work to be written down and not started.
- **Still needed:** the work, taken up from `materials/plans/surroundings.md`, which holds the decisions, the three requirement texts agreed in substance, what the match camera can show — including from the balcony, where it shows more of the ground below — and how it is derived, what RealityKit offers in the iOS 27.0 SDK, the risks and the steps. The entry closes when the requirements are written into the specification and built.

### Q-280 — The parameters of the drawn models wait for a rework before ART-070 reaches them

- **Found:** ART-070; `Sources/CrawlCall/View/Figure.swift`, on 2026-09-24.
- **What diverged:** the figure a bot is drawn as (ADR-0022) is built from a table of parts — each a box, a sphere or a cylinder with its size, centre and paint — written as literals in `Figure.swift`: 167 numbers other than 0, 1, 2 and 0.5, more than half of all such literals under `Sources/` by a count taken that day. Neither home ART-070 offers fits them: a name for every box size says nothing the table does not, and moving the table to `config/` makes a drawn shape a tuning file with an interface requirement to describe it. The maintainer decided on 2026-09-24 that how the drawn models are parameterised is to be reworked as a whole, and the figure simplified rather than moved as it stands, so bringing their numbers to ART-070 now would be work thrown away.
- **Still needed:** a discussion of how a drawn model is parameterised and of a simpler figure — fewer parts, proportions that follow from a few named ones — the first one taken up once the ground rules of ART-070 are settled. Until then the model parameters are left as they are, even where a change touches their file; the rest of the code is brought to ART-070 as a change touches it.

### Q-290 — What the fighters say is not translated

- **Found:** FR-VIEW-200; the maintainer on 2026-09-24, when the interface was set up for translation.
- **What diverged:** nothing yet; the game carries English alone. FR-VIEW-200 covers the text the interface shows and deliberately leaves out speech: the lines the model generates, the pre-written lines of IF-CMD-030, and the instructions of IF-CMD-040 and IF-CMD-050 that make the model speak. Translating those is not a matter of a catalog: the model has to be asked to speak the player's language, every measurement ADR-0017 rests on was taken with English instructions, and FR-TOOL-170 carries none of them across a change to the configuration.
- **Still needed:** a decision on whether the fighters speak the player's language, and if they do, the instructions in each language measured again by the unattended run, the pre-written lines translated, and the content list of IF-CMD-060 written for each language. Taken up when the game carries a second language.
