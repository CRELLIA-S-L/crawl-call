# ADR-0085 — A commander names what matters and where, and the squad works out how

- **Status:** accepted
- **Date:** 2026-10-12
- **Related requirements:** IF-CMD-020, FR-CMD-040, FR-CMD-050, FR-CMD-060, FR-CMD-125, FR-BOT-116, FR-BOT-130, FR-BOT-360, IF-CMD-010, IF-CMD-040

## Context and problem statement

The maintainer's rule, given on 2026-10-12: a commander is a strategist and should give strategic commands — where the enemy is and how best to press them — while the bots obey those and work out the tactics themselves, who goes round from where, how to cover the enemy best, where to look for cover; and a bot may decide to move or to attack on its own, without waiting to be told.

Half the game already followed it. The utility layer knows nothing about whether a commander exists, and a match with none fights, advances, takes cover and finishes; the threat priority is already a strategic command (FR-CMD-030); discipline already weighs an order against a bot's own reading (FR-BOT-130).

Three things broke it. **FR-CMD-060** replaced each soldier's panic, courage, discipline, aggression and self-sacrifice with numbers from the answer — a commander reaching inside a soldier. **ADR-0079** turned the order into one cell per bot by a rule per word, so who went round from where was decided by `Orders.zone` and not by the bot. **FR-CMD-050** handed out free text that nothing read; nine calls under the game's own schema named fifteen different roles and once answered `flank`, which is an order (Q-630).

And the thing the rule asks for was missing: an order had no object. A commander could say `flank` and not where, although the state it is given says "rival crew: 3 seen, east side and middle" — the vocabulary for places existed on the way in and not on the way out.

## Considered options

1. Keep the answer as it was and add a place to it, so the commander could say where as well as what.
2. Take the per-bot roles and weights out of the answer, give the order a place, and let the place be the whole of what reaches the deliberation.
3. Keep the roles and weights but close their vocabulary, so a role could be tuned and a weight could be clamped to something narrower than 0 to 1.

## Decision outcome

Option 2.

Option 1 leaves the commander holding both ends: it could say where the enemy is *and* rewrite the character of every soldier that heard it, which is the thing the rule is against. It is also the expensive end — the per-bot fields are what the model spends its tokens generating.

Option 3 is the smaller change and the wrong one. A closed set of roles would be tunable, and it would still be a commander deciding which soldier does what, which is the squad's own business; and a narrower clamp on the weights only makes the reach inside a soldier shorter, not absent.

### How it works

**The answer.** Threat, order, place, truce, speaker, line — and nothing per soldier. The order is one of `hold`, `press`, `flank`, `withdraw`; `destroyCover` left with the roles, having named no cell since it was written, and comes back when a bot can wreck a wall (FR-BOT-070). The place is one of the nine parts `SquadView.place` writes into the state, or `nowhere`: the commander answers in the words it was spoken to in, so nothing new had to be measured for safety (ADR-0017).

**What the place does.** `Places.middle` turns the word into a point, and the deliberation is handed the point rather than the word — nothing in `Sources/CrawlCall/Bot` learns what a commander is. FR-BOT-116 makes that point a fourth term in what a position is worth, beside height, the snake's path and keeping together: a whole at the place, nothing at the arena's far corner, and the slope between is what carries a squad across the island.

**What the word does.** Two of the four say the place is where the *enemy* is — `press` and `flank` — and a bot that has seen no enemy of its own believes them, which is the second of the two ways FR-BOT-360 already says a bot comes to believe anything. A bot with a sighting of its own keeps it: its eyes are nearer the truth than a word from seven seconds ago. The other two name where the squad should *be*. Between `press` and `flank` the game reads no difference at all; the pair is kept because the word is also what the squad shouts, and a commander that can only say "press" describes half the fights it sees.

**Which cell a bot takes.** `Deliberation.ordered` answers with the cell within the distance a bot looks for cover whose `worth` is greatest — its own best, by cover, height and squadmates as well as by the order — and nil where nothing within reach beats where it stands, which is the shape FR-BOT-119 gave cover. `Orders.swift` is deleted and `orderReach` is gone from the configuration with it.

**What is left of the old four.** The threat priority and the order, both the squad's. Nothing is written on a soldier by any answer: a bot's weights are its archetype's (FR-BOT-030) until its squad's commander is eaten and its panic rises (FR-CMD-130).

### Consequences

The commander is cheaper by four fifths of its answer, which is the only lever ADR-0078 found on the frame rate. Measured on the Mac on 2026-10-12, over the three states the game builds, with the control blocked in every run: the answer as it was ran 762–823 input and up to 283 output tokens at 4399 ms; the shapes this one sits between ran 516–601 input and 43–59 output at 1771–2059 ms. Q-570's first option is taken, and not as a performance trade: it is what the rule asks for anyway.

**On the phone, the saving went somewhere nobody predicted, and it is worth knowing where.** Two 45-second runs, thermal `nominal` in both, the same arena and nobody steering:

| | before | after |
|---|---|---|
| calls started / answers taken | 4 / 2 | 12 / 10 |
| how long an answer took | 17.6 and 13.8 s | 3.5 to 4.7 s |
| frames a second | 43.7 | 43.8 |
| the app's own work, median / 95th | 1.60 / 3.28 ms | 1.52 / 2.98 ms |
| deliberation in a deliberating frame, 95th / worst | 2.04 / 4.72 ms | 0.95 / 1.36 ms |

The commander answers five times as often and inside its own interval for the first time — 3.5 to 4.7 seconds against the 5 to 10 NFR-PERF-040 allows — and the frame rate did not move. The plan expected it to, and the reason it did not is in the first row: a call is not started while the last one is still out, so the device was generating for about 31 of the 45 seconds before and about 40 of them now. The answer got four times cheaper and the clock spent the saving on more answers.

So the lever on the frame rate is now the interval and not the answer: `commanderInterval` is 7 seconds in `config/match.json`, and a squad that is told something useful every seven seconds may not need to be. That is a tuning number and the maintainer's (ART-070), and it is the only one left — the work asked of the model is as small as this design makes it.

Q-640 is settled by deletion. The fifteen-metre walk per bot per slot that cost a deliberating frame 0.484 ms is gone; a bot scores the cells it was already scoring.

Q-630 is settled by withdrawal: there are no roles, so there is nothing to close a vocabulary for.

**The concept is amended, not reinterpreted.** §9.1 says the personality weights are the most important part, "именно через них LLM влияет на поведение, не участвуя в покадровых решениях". The intent — the model shapes behaviour and takes no per-frame decisions — is what the place serves instead; the sentence about the weights is reversed, and FR-CMD-060's rationale says so in its own words.

What the game loses: a commander can no longer make a frightened heavy brave, and nobody can see what a "job" would have done. What it gains is a commander whose orders a squad can disobey, and a squad whose tactics are its own.
