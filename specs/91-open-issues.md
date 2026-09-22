# Open issues

Discrepancies between the specification and the code, unfinished work, unresolved questions.
Each entry states what diverged, where it was found, and what decision is needed.
Entries are removed once the maintainer decides which side is right and the fix lands.

Entries are numbered `Q-NNN` in tens so that a requirement's rationale can name one; a number is never reused.
Sixteen questions were opened on 2026-09-21 by the decomposition of the concept and fourteen were settled the same day; each settlement is an ADR, so a closed number is found by searching `specs/adr/` for it: Q-010 and Q-090 in ADR-0009, Q-020 and Q-030 and Q-050 and Q-060 in ADR-0010, Q-070 and Q-080 in ADR-0013, Q-100 in ADR-0011, Q-110 in ADR-0014, Q-130 in ADR-0012, Q-150 in ADR-0015; Q-040 became FR-SNAKE-220, Q-140 a sentence in NFR-PERF-010's rationale and Q-160 FR-VIEW-120.
Two more were opened and settled on 2026-09-22 by the maintainer: Q-190 — whether a severed tail segment stays in the arena — became H-080, and Q-200 — the hypothesis the shedding requirements rest on — became H-070, both in `grounds/10-h-mechanics.md`; a question that turns into a measurement is closed here and answered there.
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
