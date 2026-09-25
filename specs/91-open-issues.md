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
Q-210 — whether the game targets iPadOS — was settled on 2026-09-24 by the maintainer: it does, CON-PUB-010 names iPadOS 27, and the target builds for iPhone and iPad alike (`TARGETED_DEVICE_FAMILY = 1,2`); the macOS half was never a divergence, only a sequence, and FR-VIEW-040 still brings it.
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

### Q-250 — The frame rate has been looked at, not measured

- **Found:** NFR-PERF-010; the Metal performance HUD on 2026-09-24.
- **What diverged:** NFR-PERF-010 is verified by `A`, which `specs/50-verification.md` defines as an unattended run along a fixed route with the telemetry pulled from the device afterwards. What exists is a look. On 2026-09-24, after ADR-0020's hole shader went in, the game was launched on the iPhone 16 Pro with the Metal performance HUD: at the match's start it read 59.99 frames per second, a GPU time of 6.86 ms and a frame interval of 16.67 ms, against the 13.3 ms a frame on that phone is held to. In play the maintainer saw a couple of spikes on the HUD's graph, too brief to tie to anything on screen.
- **Decided:** the maintainer judged it good enough for now, on 2026-09-24. A look is not a measurement, so NFR-PERF-010 stays `deferred`.
- **Still needed:** an autopilot that drives the snake along a fixed route, so that a run is the same run twice. The rest of the game's own instrument exists since 2026-09-24: the frame record — every frame's interval, the time of each phase of the game's step and the events in it (FR-TOOL-230), written when a match ends, the app leaves the foreground or it is terminated (FR-TOOL-240) — and the run tool that takes it off the device and names the slowest frames (FR-TOOL-250). Its first run on the iPhone 16 Pro, twenty seconds with nobody playing, recorded 1230 frames with one late — the second, at 70.6 ms, as the match started — and the game's own step under 0.3 ms a frame. Three minutes of the maintainer's own play on the same phone, with the snake eating seven bots, recorded 10 877 frames with two late, both as the match began, and the game's own work at most 3.1 ms in any phase of a frame (ADR-0030). A reading by `A` also needs the route, so NFR-PERF-010 stays `deferred`.

### Q-260 — The see-through of the walls around the snake does not sit right with the maintainer yet

- **Found:** FR-VIEW-150, FR-VIEW-155; the maintainer on the phone on 2026-09-24, after ADR-0021.
- **What diverged:** nothing in the specification; the build does what FR-VIEW-150 and FR-VIEW-155 ask. The maintainer found the see-through of the walls around the snake somewhat off, and put it off for later. Two things cut a wall near the snake open. The line of sight: a wall within the body's radius plus the see-through margin of IF-VIEW-020 — 0.3 + 0.15 = 0.45 m — of a line from the camera to any part of the snake (ADR-0019, ADR-0020); since ADR-0021 a wall the body touches on the camera's side or on either flank is 0.3 m from the head's centre and within that, while one the body touches from behind is not, the line stopping that margin short of the head (ADR-0019, point 2). And the window around the head: any module within the visibility radius, 1.6 m, that is not wholly beyond the head and stands higher than the floor the head is on (FR-VIEW-155).
- **Still needed:** on 2026-09-25 the maintainer narrowed it: what is off is walls and crates beside the head opened though they hide nothing. Two cuts can do that — the line of sight of FR-VIEW-150, a cylinder about each line from the camera to a part of the snake, and the window of FR-VIEW-155, a sphere of the visibility radius around the head, 1.6 m (`config/view.json`) — and a module both reach is cut with one sphere holding the two (ADR-0020). Debug mode tints each cut by its cause and switches either off (FR-TOOL-260, FR-TOOL-270), and with them on the phone the maintainer found that it is the window. A match runs without it since 2026-09-25 (FR-VIEW-155, `partial`); it is kept, switched back on in debug mode, until the maintainer is sure it can go — or chooses a smaller radius, or a window kept to the side of the head that faces the camera. The cylinder over-cuts too, but near the camera rather than beside the head: a cut that shows the snake need only be as wide, where it passes a module, as the snake looks from there, a cone from the camera to the snake rather than a cylinder.

### Q-270 — The world around the arena is built and not yet judged on the phone

- **Found:** the maintainer on 2026-09-24, asking for a sky, the space beyond the map, birds and vegetation.
- **What diverged:** nothing in the specification. Around the arena there was nothing, drawn black on the phone and white in the simulator; the maintainer agreed on 2026-09-24 to a first setting on an island, to settings as families a map names, and to a world only larger than all the match camera can show (`materials/plans/surroundings.md`). The same day the requirements were written — FR-MAP-120, FR-MAP-130 and FR-MAP-140 for every setting, the area GREENHOLM for the first island, each setting being an area with a name of its own since there will be more than one island, and IF-MAP-010's header line — and built, with the decisions in ADR-0031.
- **Still needed:** the maintainer's judgement on the phone of how the island, the sky and the birds look — the `D` of FR-GREENHOLM-010, FR-GREENHOLM-020 and FR-GREENHOLM-030 — and, with it, whether the entry is closed. The sky is seen only through the free camera of debug mode.

### Q-280 — The parameters of the drawn models wait for a rework before ART-070 reaches them

- **Found:** ART-070; `Sources/CrawlCall/View/Figure.swift`, on 2026-09-24.
- **What diverged:** the figure a bot is drawn as (ADR-0022) is built from a table of parts — each a box, a sphere or a cylinder with its size, centre and paint — written as literals in `Figure.swift`: 167 numbers other than 0, 1, 2 and 0.5, more than half of all such literals under `Sources/` by a count taken that day. Neither home ART-070 offers fits them: a name for every box size says nothing the table does not, and moving the table to `config/` makes a drawn shape a tuning file with an interface requirement to describe it. The maintainer decided on 2026-09-24 that how the drawn models are parameterised is to be reworked as a whole, and the figure simplified rather than moved as it stands, so bringing their numbers to ART-070 now would be work thrown away. After the pass of 2026-09-24 these parameters are all that is left outside ART-070 in `Sources/CrawlCall/`: the figure in `Figure.swift`; the colours, materials and sizes in `SnakeEntity.swift`, `BotEntity.swift` — the smallest an eaten body shrinks to among them — and `ShotEntity.swift`; the modules' materials in `SeeThrough.swift`; and the hole shader, `SeeThroughHole.metal`, whole — its two tuned constants and the arithmetic around them, since where a shader keeps a named value is part of the same question.
- **Still needed:** a discussion of how a drawn model is parameterised and of a simpler figure — fewer parts, proportions that follow from a few named ones — the first one taken up once the ground rules of ART-070 are settled. Until then the model parameters are left as they are, even where a change touches their file; the rest of the code is brought to ART-070 as a change touches it.

### Q-290 — What the fighters say is not translated

- **Found:** FR-VIEW-200; the maintainer on 2026-09-24, when the interface was set up for translation.
- **What diverged:** nothing yet; the game carries English alone. FR-VIEW-200 covers the text the interface shows and deliberately leaves out speech: the lines the model generates, the pre-written lines of IF-CMD-030, and the instructions of IF-CMD-040 and IF-CMD-050 that make the model speak. Translating those is not a matter of a catalog: the model has to be asked to speak the player's language, every measurement ADR-0017 rests on was taken with English instructions, and FR-TOOL-170 carries none of them across a change to the configuration.
- **Still needed:** a decision on whether the fighters speak the player's language, and if they do, the instructions in each language measured again by the unattended run, the pre-written lines translated, and the content list of IF-CMD-060 written for each language. Taken up when the game carries a second language.

### Q-300 — Xcode's AppIntents tool warns about a framework the game does not use

- **Found:** ART-080; the build log on 2026-09-24.
- **What diverged:** every build prints `appintentsmetadataprocessor … warning: Metadata extraction skipped, no AppIntents.framework dependency found`, once per target. ART-080 asks for a build with no warning. The notice is Xcode's own build phase saying there is nothing for it to do, since the game does not link AppIntents; no build setting of the project was found that turns it off — `xcodebuild -showBuildSettings` lists none for the phase — and linking a framework the game does not use to quiet a notice would be a dependency added for nothing, which ART-040 asks an ADR to justify and none could.
- **Still needed:** nothing from inside the repository. The entry stands, as ART-080 allows, until a version of Xcode stops printing it or offers a setting for it; FR-TOOL-220 does not list it among the build's warnings because it names no file or setting of the project.

### Q-310 — What a bot has to fight with beyond a magazine is not decided

- **Found:** the maintainer on 2026-09-25, listing what a bot weighs in choosing an action (FR-BOT-080), among it the arms it has — rounds, grenades and the like.
- **What diverged:** nothing yet. The concept and the specification give a bot a weapon with a magazine and nothing else; grenades appear in neither. FR-BOT-080 names what a bot has to fight with as an input, and today that is its rounds alone.
- **Still needed:** a decision on the equipment a bot carries — grenades, and what else — what each does in the arena, to the snake, to cover (FR-MAP-030) and to the other squad, and how much of it a bot has; then its requirements, its numbers in the bot configuration (IF-BOT-010) and its actions beside those of FR-BOT-200.

### Q-320 — A bot with nothing happening around it stands still

- **Found:** the maintainer on 2026-09-25, while settling what a bot weighs in choosing an action (ADR-0032).
- **What diverged:** nothing in the specification: with no enemy, no snake, no order and no danger in what it knows, no action that moves a bot scores anything — reloading and healing a squadmate still can — and a bot stays where it is. The maintainer wants motives that keep an idle bot alive to the player — idle curiosity, for one — so that bots do not simply stand in place when nothing is going on.
- **Still needed:** what those motives are and what a bot does under them — wandering, looking round, drifting towards something it has not seen — with how they rank against the rest of FR-BOT-080's inputs, since a motive for the quiet must never outweigh a threat; then a requirement for each. The knowledge a bot keeps (ADR-0032) gives curiosity something to read: the cells it has not yet seen.

### Q-330 — A way straight up for towers and lookouts waits for destruction

- **Found:** the maintainer on 2026-09-25, replacing the stair that went straight up in one cell with a flight of steps (ADR-0033).
- **What diverged:** nothing: no map has a way straight up any more. The map format keeps its `transition` line for one (IF-MAP-010), and the graph and the snake still follow such a line.
- **Still needed:** whether vertical ladders come back to reach sniper points — towers, lookouts — and how they look and are climbed; taken up after the snake's destruction of buildings is settled (FR-MAP-030), since a tower is first of all something the snake can bring down.

### Q-340 — A bot's posture: standing, kneeling, lying

- **Found:** the maintainer on 2026-09-25, to be laid down for the future.
- **What diverged:** nothing yet; a bot is always standing. The maintainer wants a bot to choose its posture: standing — fast, the widest view, the least accurate fire; kneeling — middling speed, a middling view, fire better than average; lying — very slow, a low or narrow view, very accurate fire, and no grenades.
- **Still needed:** the numbers of each posture in the bot configuration (IF-BOT-010), and three things the specification does not have yet. Fire has no accuracy: a shot with a line of fire hits (FR-BOT-060), so accuracy needs a model of a miss first. A bot's eyes are one height (FR-BOT-050), and a posture lowers them — and lowers what the others see of the bot, so that a lying bot is hidden by cover a standing one is not. And a view that is narrow needs a direction to be narrow around, which a bot does not have. Grenades are Q-310. Then how posture enters the choice of action (FR-BOT-080), and the figure drawn for each (FR-VIEW-070).
