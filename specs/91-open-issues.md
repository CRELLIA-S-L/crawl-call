# Open issues

Discrepancies between the specification and the code, unfinished work, unresolved questions.
Each entry states what diverged, where it was found, and what decision is needed.
Entries are removed once the maintainer decides which side is right and the fix lands.

Entries are numbered `Q-NNN` in tens so that a requirement's rationale can name one; a number is never reused.
Where the concept (`materials/concept/concept-v0.11.md`) gives a working default, the specification uses it and the entry says so — the question is still open, the work is not blocked.
Concept §14 lists twelve questions; all are here — the end of a match and a squad wiped out share Q-050 — together with what the decomposition of 2026-09-21 found the concept silent on.

### Q-010 — What kills the snake, and what is its "health"?

- **Found:** decomposing concept §5 into FR-SNAKE-070 (damage removes segments), FR-SNAKE-170 (medic heals "health"), FR-SNAKE-180 (armour reduces "damage").
- **What diverged:** the concept takes damage in segments off the tail and never says what happens when no segments remain, whether the head has its own health, or what the medic's ability restores.
- **Decision needed:** one model — (a) head health points, tail segments as a buffer shot off first, snake dies at zero head health; (b) no separate health, the snake dies when a hit lands with no segments left; (c) the snake cannot die and the match ends by score or timer (see Q-050). The choice rewrites the three requirements above and adds one for death.

### Q-020 — Squad size

- **Found:** concept §14; FR-BOT-020 uses four per squad, the concept's "start with 4v4", from the match configuration.
- **What diverged:** 4v4, 5v5 or 6v6 affects the performance budget (NFR-PERF-010, NFR-PERF-050), heat and the readability of the fight.
- **Decision needed:** the final size, after the spike and the first thermal measurements. Not blocking: it is one number in configuration.

### Q-030 — Reinforcements

- **Found:** concept §14.
- **What diverged:** without reinforcements the war is finite and the match ends when prey runs out; with them a source and a limiter are needed, and FR-BOT-020 gains a sibling.
- **Decision needed:** whether reinforcements exist, and if so from where and capped how. Tied to Q-050.

### Q-040 — The tail on a long drop

- **Found:** concept §14; FR-MAP-090 admits gaps up to a tolerance and says nothing about height.
- **What diverged:** whether the tail stretches, breaks or takes damage when the head drops from a height, and whether a drop is a vertical transition FR-SNAKE-010 allows at any height.
- **Decision needed:** the rule; the spike's first check (a drop from a balcony) is where it will be seen first.

### Q-050 — How a match ends

- **Found:** concept §14; no requirement states an end condition.
- **What diverged:** extermination of both squads, a timer, a score threshold — and what happens when one squad is wiped out entirely: does the match continue against the survivors or end. With two squads "prey ran out" happens by itself and may happen too early.
- **Decision needed:** the end condition and the one-squad-left rule. Blocks a requirement in the SCORE area; nothing else waits on it.

### Q-060 — A counterweight to pure stealth

- **Found:** concept §14; ADR-0006.
- **What diverged:** nothing stops the optimal strategy from being twenty minutes in a corner. The concept offers a decaying multiplier for inaction or timer pressure.
- **Decision needed:** whether a counterweight exists and which. This is the one §14 question the concept itself marks as a hypothesis about player behaviour rather than a design choice; if it is written down, it is the maintainer's to write in the grounds register.

### Q-070 — Do bodies decay?

- **Found:** concept §14; FR-SCORE-130 makes awareness monotonic on that assumption.
- **What diverged:** a body that decays removes the evidence and makes "leave it and go" a full third strategy; it would also allow awareness to fall, which FR-SCORE-130 forbids.
- **Decision needed:** decay or not; if yes, the timing and whether awareness can drop.

### Q-080 — Awareness from destruction nobody did

- **Found:** concept §14.
- **What diverged:** a squad might suspect the snake from cover destroyed by neither side — a potential fourth source of awareness beside witnesses, inspected bodies and vanished bodies (FR-SCORE-090, FR-SCORE-120, FR-SCORE-125).
- **Decision needed:** whether to add it. Not blocking.

### Q-090 — A ceiling on abilities carried

- **Found:** concept §14; FR-SNAKE-110 attaches one ability per consumed bot, FR-SNAKE-120 consumes them on use.
- **What diverged:** at great length a snake may hold too many abilities; the concept asks whether a cap beyond one-per-segment is needed.
- **Decision needed:** cap or no cap; the number if yes.

### Q-100 — Is the commander an archetype or a role?

- **Found:** concept §14; FR-BOT-040 designates one bot per squad, FR-VIEW-070 makes archetypes readable by silhouette.
- **What diverged:** a seventh silhouette makes the commander easy to spot and eat; a role on any bot makes finding him part of the hunt. INV-BOT-030's "six" and FR-BOT-010 change under the first option.
- **Decision needed:** which; and if a role, whether it is visible at all.

### Q-110 — Age rating and speech moderation

- **Found:** concept §14; CON-PUB-080, FR-CMD-160.
- **What diverged:** the App Store treats generated speech as user-generated content (guideline 1.2); the filter is specified, the rating is not, and the filter's strictness follows from the rating.
- **Decision needed:** the target age rating, which sets what the filter rejects.

### Q-120 — The final name

- **Found:** concept §14, §17.6; CON-PUB-090.
- **What diverged:** "Chomp Company" is a working title; "Chomp" is taken in apps (a children's app, a Google Play game, a UK studio). A professional trademark search in classes 9 and 41, EU first, decides.
- **Decision needed:** commission the search; then the name. Not blocking anything in the repository.

### Q-130 — The grammar of the configuration and map files

- **Found:** IF-SNAKE-010, IF-BOT-010, IF-SCORE-010, IF-MAP-010, IF-MAP-020, IF-CMD-030 name what each file carries and not how it is spelled.
- **What diverged:** the concept says "an ASCII grid per floor" and "a separate config" and no more; the file formats, the kit legend, and whether the configurations are one file or several are undecided.
- **Decision needed:** a format — the specification's requirements would then gain a `refines` each. A plausible default is one JSON file per interface and a plain-text grid for maps; not blocking until code starts.

### Q-140 — Target frame rate is a decision of 2026-09-21, not the concept's

- **Found:** NFR-PERF-010, NFR-PERF-050.
- **What diverged:** the concept names no frame rate; the maintainer chose 60 fps on the baseline device when the decomposition began. Recorded here so that the number is known to be a decision and not a derivation, and revisited after the spike's second check.
- **Decision needed:** none now; confirm or lower after the first measurement on the device.

### Q-150 — The baseline device

- **Found:** `30-nfr.md` defines it as "the oldest iPhone that runs iOS 27".
- **What diverged:** the concept says "a real iPhone" and never which; every performance number depends on the answer.
- **Decision needed:** name the device model the numbers are measured on.

### Q-160 — The interface style guide

- **Found:** concept §2 asks for an interface in the diorama aesthetic — rounded light plates, a bold rounded typeface, large icons — and rejects a military HUD; no requirement covers it because "in the same aesthetic" is not verifiable without a style guide to inspect against.
- **What diverged:** the requirement is absent, not wrong.
- **Decision needed:** whether a style guide is written (then a `FR-VIEW` requirement with verification `I` against it) or the HUD stays a design matter outside the specification.
