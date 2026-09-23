# Open issues

Discrepancies between the specification and the code, unfinished work, unresolved questions.
Each entry states what diverged, where it was found, and what decision is needed.
Entries are removed once the maintainer decides which side is right and the fix lands.

Entries are numbered `Q-NNN` in tens so that a requirement's rationale can name one; a number is never reused.
Sixteen questions were opened on 2026-09-21 by the decomposition of the concept and fourteen were settled the same day; each settlement is an ADR, so a closed number is found by searching `specs/adr/` for it: Q-010 and Q-090 in ADR-0009, Q-020 and Q-030 and Q-050 and Q-060 in ADR-0010, Q-070 and Q-080 in ADR-0013, Q-100 in ADR-0011, Q-110 in ADR-0014, Q-130 in ADR-0012, Q-150 in ADR-0015; Q-040 became FR-SNAKE-220, Q-140 a sentence in NFR-PERF-010's rationale and Q-160 FR-VIEW-120.
Q-220 — what lies under a wall when a cell holds one module — was opened and settled the same day it was found: the floor is implied under every cell whose module is not walkable (FR-TOOL-020), and a hole is what a map declares on purpose (FR-MAP-110, `draft`).
Two more were opened and settled on 2026-09-22 by the maintainer: Q-190 — whether a severed tail segment stays in the arena — became H-080, and Q-200 — the hypothesis the shedding requirements rest on — became H-070, both in `grounds/10-h-mechanics.md`; a question that turns into a measurement is closed here and answered there.
One more was opened and settled on 2026-09-23, when the kit's wall came down to a fence: Q-240 — whether a bot sees over what the player sees over — became the second paragraph of FR-BOT-050's rationale.
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

### Q-230 — The head's centre is on a walkable cell; its body is wider than one

- **Found:** FR-SNAKE-010, IF-MAP-020; measured on 2026-09-22.
- **What diverged:** movement keeps the head's *centre* inside a walkable cell, which is what the navigation grid can answer. The head is a body with a radius, and the shipped tuning gives it 0.3 m on a 0.5 m grid: half a cell is 0.25 m, so a head at the centre of a cell beside a wall overlaps that wall by 0.05 m, and the body's diameter of 0.6 m is wider than the cell it moves through. FR-SNAKE-010 says the head never passes through walls, and by its centre it does not; by its body it does.
- **Options:** a finer navigation grid, so that half a cell exceeds the radius — it multiplies the graph's nodes by four for each halving; a smaller body radius, which is a look-and-feel number the maintainer owns (concept §12); or collision against the scene's geometry rather than the grid's cells, which is what the spike's character controller did before ADR-0016 replaced it, and which would make the grid the bots' model alone.
- **Still needed:** the maintainer decides which, and FR-SNAKE-010 then says in words what "never passing through walls" is measured against — the centre or the body. Until then the overlap is 5 cm on a grey blockout and invisible; on a map with thin cover it would not be.

### Q-250 — The frame rate has been looked at, not measured

- **Found:** NFR-PERF-010; the Metal performance HUD on 2026-09-24.
- **What diverged:** NFR-PERF-010 is verified by `A`, which `specs/50-verification.md` defines as an unattended run along a fixed route with the telemetry pulled from the device afterwards. What exists is a look. On 2026-09-24, after ADR-0020's hole shader went in, the game was launched on the iPhone 16 Pro with the Metal performance HUD: at the match's start it read 59.99 frames per second, a GPU time of 6.86 ms and a frame interval of 16.67 ms, against the 13.3 ms a frame on that phone is held to. In play the maintainer saw a couple of spikes on the HUD's graph, too brief to tie to anything on screen.
- **Decided:** the maintainer judged it good enough for now, on 2026-09-24. A look is not a measurement, so NFR-PERF-010 stays `deferred`.
- **Still needed:** the game's own instrument — per-frame intervals written with their times, an autopilot that drives the snake along a fixed route, a runner and an analyser — modelled on `materials/spike/instrument/`, which no longer runs. No requirement covers it yet, so it is authored before it is built. The spikes seen by eye are exactly what it would place in time.
