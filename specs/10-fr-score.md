# Functional requirements — scoring

Points, the three multiplying axes, witnessing, bodies, the squad awareness scale.
Source: concept §6 (score, witnesses, bodies), §6.1 (witnessing), §6.2 (bodies), §6.3 (awareness).
That nothing but eating scores is INV-SCORE-010.
Base values and multipliers are read from the scoring configuration (IF-SCORE-010); the relations between them stated below are the concept's.

## Points

### FR-SCORE-010 — Consuming a bot awards points

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SNAKE-090, IF-SCORE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the snake finishes consuming a bot, the system **shall** add to the score the base value of the scoring configuration for that consumption multiplied by the stealth, balance and target-value multipliers of FR-SCORE-030, FR-SCORE-050 and FR-SCORE-060.

**Rationale.** Concept §6: three independent axes that multiply, so that the fine situations arise at their intersection instead of being farmed from a checklist (ADR-0006).

### FR-SCORE-020 — Live prey has the higher base value

```yaml
status: deferred
verification: T
derives_from: [FR-SCORE-010]
depends_on: [FR-SNAKE-100]
refines: [FR-SCORE-010]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the consumed bot was alive at the start of eating, the system **shall** use the live-prey base value, which is greater than the body base value.

**Rationale.** Concept §1, §6: live prey resists, takes longer and therefore pays more; this is what pushes the player into danger instead of scavenging.
The multipliers apply the same way to a body — a body eaten unseen is still a hidden eating.

## The three axes

### FR-SCORE-030 — Stealth multiplier by who saw

```yaml
status: deferred
verification: T
derives_from: [FR-SCORE-010]
depends_on: [FR-SCORE-070]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When scoring a consumption, the system **shall** apply the stealth multiplier for its level — *open* when a bot of the victim's squad witnessed it, *hidden* when none of that squad did, *perfect* when no bot of either squad did — with *perfect* greater than *hidden* greater than *open*.

**Rationale.** Concept §6.1: three levels, from ordinary hunting to "the snake does not seem to exist".

### FR-SCORE-040 — The leading squad is the one with more living bots

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The system **shall** consider the squad with the greater number of living bots the leading squad, and neither squad leading when the numbers are equal.

**Rationale.** Concept §6 speaks of "the leading squad" without defining it; living head-count is the definition the player can read off the screen (FR-VIEW-060), which is what the balance axis needs.
Whether a richer measure is wanted is a tuning question, not an open one.

### FR-SCORE-050 — Balance multiplier for prey from the leading squad

```yaml
status: deferred
verification: T
derives_from: [FR-SCORE-010]
depends_on: [FR-SCORE-040]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the consumed bot belonged to the leading squad, the system **shall** apply the balance multiplier, greater than one; otherwise one.

**Rationale.** Concept §6: rewarding a bite from the stronger side keeps the war going, which is the strategic layer of §1.

### FR-SCORE-060 — Target-value multiplier for commander, heavy and medic

```yaml
status: deferred
verification: T
derives_from: [FR-SCORE-010]
depends_on: [FR-BOT-010, FR-BOT-040]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the consumed bot held the commander role or was a heavy or a medic, the system **shall** apply the target-value multiplier of the scoring configuration for that case; otherwise one.

**Rationale.** Concept §6: tactical choice rather than the nearest.

## Witnessing

### FR-SCORE-070 — A witness is a bot with line of sight during the window

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-SNAKE-090]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Awareness.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/AwarenessTests.swift]
created: 2026-09-21
```

When an eating is in progress, the system **shall** record as its witness every living bot that has line of sight to the eating point at any moment from the start of eating until the witness window of the scoring configuration — between 2 and 3 seconds — after it ends.

**Rationale.** Concept §6.1: stealth is about who saw the eating, not whether the victim knew; the window makes dragging prey into shadow count, otherwise strictly instant eating is optimal.
Seeing the eating point is seeing it as a bot sees anything, and a meal is seen from the coil on (ADR-0060).

### FR-SCORE-080 — Arriving right after counts as witnessing

```yaml
status: implemented
verification: T
derives_from: [FR-SCORE-070]
depends_on: []
refines: [FR-SCORE-070]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Awareness.swift]
tests: [Tests/CrawlCallTests/AwarenessTests.swift]
created: 2026-09-21
```

When a living bot gains line of sight to the eating point within the late-arrival window of the scoring configuration after the eating ends, the system **shall** record it as a witness.

**Rationale.** Concept §6.1: one who reached the spot a second later has effectively understood everything.
Followed together with FR-SCORE-070 over the longer of the two windows (ADR-0060).

### FR-SCORE-090 — A witness reports after a delay

```yaml
status: implemented
verification: T
derives_from: [FR-SCORE-070]
depends_on: [FR-SCORE-130]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Awareness.swift]
tests: [Tests/CrawlCallTests/AwarenessTests.swift]
created: 2026-09-21
```

When a bot becomes a witness, the system **shall** set its squad's awareness to *confirmed* after the report delay of the scoring configuration.

**Rationale.** Concept §6.1: witnessing is knowledge, not a flag — the witness reports and the commander re-prioritises.
The delay is what creates the task of silencing the only witness before the report.

### FR-SCORE-100 — A consumed witness never reports

```yaml
status: implemented
verification: T
derives_from: [FR-SCORE-090]
depends_on: []
refines: [FR-SCORE-090]
conflicts_with: []
code: [Sources/CrawlCall/Bot/Awareness.swift]
tests: [Tests/CrawlCallTests/AwarenessTests.swift]
created: 2026-09-21
```

If a witness is consumed before its report delay elapses, the system **shall not** raise its squad's awareness on its account.

**Rationale.** Concept §6.1: the one case where the snake profits from eating fast and dirty.
A witness killed before it reports says nothing either: a body does nothing (FR-BOT-320, ADR-0060).

## Bodies

### FR-SCORE-110 — A body carries its cause of death

```yaml
status: deferred
verification: D
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a bot dies, the system **shall** leave a body whose appearance distinguishes a snake kill from a gunshot kill.

**Rationale.** Concept §6.2: wounds are distinguishable; if somebody comes and looks, the cover story falls apart — hence the third option, leaving the body where nobody will find it.

### FR-SCORE-120 — Finding a body is one thing, inspecting it another

```yaml
status: deferred
verification: T
derives_from: [FR-SCORE-110]
depends_on: [FR-SCORE-130]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a bot comes within the inspection distance of the scoring configuration of a squadmate's body killed by the snake, the system **shall** set its squad's awareness to *confirmed*.

**Rationale.** Concept §6.2: a body left behind blames the enemy — a corpse is what a squad expects from a war — until somebody looks closely.
A body seen from beyond the inspection distance changes nothing, and no requirement says so because nothing needs to happen for that to hold.

### FR-SCORE-125 — A vanished body raises the alarm

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-SCORE-130, INV-BOT-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Awareness.swift]
tests: [Tests/CrawlCallTests/AwarenessTests.swift]
created: 2026-09-21
```

When a bot reaches the last known position of a dead squadmate and no body is within the inspection distance, the system **shall** set its squad's awareness to at least *alarm*.

**Rationale.** Concept §6.2, §6.3: the squad learns of the snake from bodies disappearing, not from anyone seeing it — a kill leaves a corpse, a disappearance has no explanation, and that frightens more than contact.
Numbered between 120 and 130 because it belongs beside the body rules and the awareness scale was already numbered.
Where the squad last knew a squadmate to be is where it stood when it fell or vanished (ADR-0060).

## Awareness

### FR-SCORE-130 — Each squad has an awareness state

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Awareness.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/AwarenessTests.swift]
created: 2026-09-21
```

The system **shall** keep for each squad one awareness state — *calm*, *alarm* or *confirmed* — starting at *calm* and moving only upward within a match.

**Rationale.** Concept §6.3: a state instead of a boolean, fed to the commander (FR-CMD-070) and read by deliberation (FR-BOT-180, FR-BOT-190).
Monotonic because nothing lowers it: bodies do not decay (ADR-0013), so evidence never fades within a match.

## End of a match

### FR-SCORE-140 — The match ends when the snake dies

```yaml
status: partial
verification: T
derives_from: []
depends_on: [FR-SNAKE-210]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/MatchEndTests.swift]
created: 2026-09-21
```

When the snake dies, the system **shall** end the match with the score accumulated so far as its result.

**Rationale.** ADR-0010: the score is the result, not the goal.
No timer and no score threshold end a match; the ends are this one, FR-SCORE-150 and, since the treasure, FR-SCORE-160.

**Partial, and how.** What is built is the end: a snake killed under FR-SNAKE-210 stops the match where it stands, nothing in the arena moves again, and the screen says which end it was (FR-VIEW-190).
What is not built is the result, because there is no score to carry into it — FR-SCORE-010 and the three multipliers it derives are the next layer, and a zero reported as a result would be a number nobody computed.

### FR-SCORE-150 — The match ends when no bot is left

```yaml
status: partial
verification: T
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/MatchEndTests.swift]
created: 2026-09-21
```

When the last living bot of either squad dies or is consumed, the system **shall** end the match with the score accumulated so far as its result.

**Rationale.** ADR-0010: prey is finite and there are no reinforcements; a wiped-out squad does not end the match — the other one is still there — and the arena being empty does.
Living is what is counted, not present: the day a body stays where it fell (INV-SCORE-020), a match with nothing left that can shoot back is still over.
A squad wiped out still does not end a match, and since FR-SCORE-160 it hands the other squad a treasure to carry off, which does — however the losing squad died, the snake's last meal among the ways.

**Partial, and how.** The same half as FR-SCORE-140: the end is built and the result is not, for want of a score (FR-SCORE-010).
Today the only way a bot leaves the arena is being eaten, so the two readings of the trigger — the last living one, the last one of any kind — cannot be told apart in play; the code counts the living ones, which is what the statement says.

### FR-SCORE-160 — The match ends when the treasure is carried off

```yaml
status: partial
verification: T
derives_from: []
depends_on: [FR-BOT-640, FR-MAP-290]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Game.swift, Sources/CrawlCall/Bot/Treasure.swift, Sources/CrawlCall/View/MatchEnd.swift]
tests: [Tests/CrawlCallTests/TreasureTests.swift]
created: 2026-10-14
```

While the bot carrying the treasure stands at the evacuation point the map names and no bot of the other squad is alive, the system **shall** end the match with the score accumulated so far as its result.

**Rationale.** Concept §6.4: the third of three ends, beside the snake dying (FR-SCORE-140) and nothing being left alive (FR-SCORE-150). Without it a match that one squad has won hangs on survivors with nowhere to go — measured on 2026-10-13 on the shipped arena, four of them spent a hundred and ten seconds between three points a metre apart — and that is a game with no goal rather than a defect in the behaviour.
The snake is not obliged to defend the treasure and never loses points for it; what it loses is a multiplier over the whole match (FR-SCORE-170).
Amended on 2026-10-14 on the maintainer's rule: carrying the prize to the point is not enough, and a squad leaves with it only once the other crew is gone. It is the end of the second act rather than the whole of it — the prize can be taken and carried in the middle of a firefight (FR-BOT-620), with hands full (FR-BOT-670) and at a walk (FR-BOT-680), but getting out with it is what a squad has to win the war for.
Measured against the arena, not against what anybody believes (FR-BOT-220): the end of a match is the game's own fact, where a bot's motives are its own reading. A carrier standing at the point with an enemy still up simply waits there, and the match ends in the frame the last of them falls.
The carrier that waits is also the carrier that can be killed on the spot, and the treasure then lies at the evacuation point for whoever reaches it next (FR-BOT-650).
Nothing on screen yet says why a carrier is standing on the point and the match has not ended; that is a question for the interface and is not built.

**Partial, and how.** The same half as FR-SCORE-140 and FR-SCORE-150: the end is built — a carrier that reaches the cell stops the match where it stands and the plate says which end it was (FR-VIEW-190) — and the result is not, for want of a score (FR-SCORE-010).

### FR-SCORE-170 — A treasure carried off costs the match its multiplier

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SCORE-010, FR-SCORE-160, IF-SCORE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-10-14
```

When a match ended with the treasure carried to the evacuation point, the system **shall** multiply its score by the treasure-lost multiplier of the scoring configuration, which is less than one.

**Rationale.** Concept §6.4: the score is not rewritten but built on. Points still come from eating, with the same three axes (FR-SCORE-010); a treasure carried off adds nothing and takes nothing away, it removes a multiplier from the whole match. The player never has to defend it — it simply costs them the result.
Deferred with the score it multiplies: FR-SCORE-010 and its three axes are the layer under this one, and a multiplier over a number nobody computes is not worth building first.
