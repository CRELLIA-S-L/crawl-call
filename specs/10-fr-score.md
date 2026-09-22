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
status: deferred
verification: T
derives_from: []
depends_on: [FR-SNAKE-090]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When an eating is in progress, the system **shall** record as its witness every living bot that has line of sight to the eating point at any moment from the start of eating until the witness window of the scoring configuration — between 2 and 3 seconds — after it ends.

**Rationale.** Concept §6.1: stealth is about who saw the eating, not whether the victim knew; the window makes dragging prey into shadow count, otherwise strictly instant eating is optimal.

### FR-SCORE-080 — Arriving right after counts as witnessing

```yaml
status: deferred
verification: T
derives_from: [FR-SCORE-070]
depends_on: []
refines: [FR-SCORE-070]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a living bot gains line of sight to the eating point within the late-arrival window of the scoring configuration after the eating ends, the system **shall** record it as a witness.

**Rationale.** Concept §6.1: one who reached the spot a second later has effectively understood everything.

### FR-SCORE-090 — A witness reports after a delay

```yaml
status: deferred
verification: T
derives_from: [FR-SCORE-070]
depends_on: [FR-SCORE-130]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a bot becomes a witness, the system **shall** set its squad's awareness to *confirmed* after the report delay of the scoring configuration.

**Rationale.** Concept §6.1: witnessing is knowledge, not a flag — the witness reports and the commander re-prioritises.
The delay is what creates the task of silencing the only witness before the report.

### FR-SCORE-100 — A consumed witness never reports

```yaml
status: deferred
verification: T
derives_from: [FR-SCORE-090]
depends_on: []
refines: [FR-SCORE-090]
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

If a witness is consumed before its report delay elapses, the system **shall not** raise its squad's awareness on its account.

**Rationale.** Concept §6.1: the one case where the snake profits from eating fast and dirty.

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
status: deferred
verification: T
derives_from: []
depends_on: [FR-SCORE-130, INV-BOT-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a bot reaches the last known position of a dead squadmate and no body is within the inspection distance, the system **shall** set its squad's awareness to at least *alarm*.

**Rationale.** Concept §6.2, §6.3: the squad learns of the snake from bodies disappearing, not from anyone seeing it — a kill leaves a corpse, a disappearance has no explanation, and that frightens more than contact.
Numbered between 120 and 130 because it belongs beside the body rules and the awareness scale was already numbered.

## Awareness

### FR-SCORE-130 — Each squad has an awareness state

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

The system **shall** keep for each squad one awareness state — *calm*, *alarm* or *confirmed* — starting at *calm* and moving only upward within a match.

**Rationale.** Concept §6.3: a state instead of a boolean, fed to the commander (FR-CMD-070) and read by deliberation (FR-BOT-180, FR-BOT-190).
Monotonic because nothing lowers it: bodies do not decay (ADR-0013), so evidence never fades within a match.

## End of a match

### FR-SCORE-140 — The match ends when the snake dies

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SNAKE-210]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the snake dies, the system **shall** end the match with the score accumulated so far as its result.

**Rationale.** ADR-0010: the score is the result, not the goal.
No timer and no score threshold end a match; the only two ends are this one and FR-SCORE-150.

### FR-SCORE-150 — The match ends when no bot is left

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

When the last living bot of either squad dies or is consumed, the system **shall** end the match with the score accumulated so far as its result.

**Rationale.** ADR-0010: prey is finite and there are no reinforcements; a wiped-out squad does not end the match — the other one is still there — and the arena being empty does.
