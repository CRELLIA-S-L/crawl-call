# ADR-0074 — Courage multiplies firing, and holding ground by how near the danger has come

- **Status:** accepted
- **Date:** 2026-10-11
- **Related requirements:** FR-BOT-030, FR-BOT-080, FR-BOT-090, FR-BOT-220, IF-BOT-010

## Context and problem statement

FR-BOT-090 names five personality weights and says what each scales.
Four were built; courage was not, and had been in the specification since the maintainer added it on 2026-09-25 as a weight of its own rather than the other side of panic.
It appeared nowhere in the sources, the tests or the configuration, which held panic, discipline, aggression and self-sacrifice alone.

That absence was one of the three reasons FR-BOT-080 stood at `partial`.
Measuring the other two on 2026-10-11 found that one was no longer true: the requirement's rationale said the build "scores the snake alone as an enemy and a danger", and it was written the day before the squads went to war (ADR-0044), after which the enemy became both a target and something to hide from.
So of the seven inputs FR-BOT-080 names, six are read once courage is in, and the seventh — what a bot has to fight with beyond a magazine — is an undecided question, Q-310.

The concept is no help on where courage enters: §9.2 names panic and discipline, §8's archetype table predates courage, and neither mentions it.
What the specification gives is the statement's own parenthesis — courage scales "the terms for facing danger — firing at it, holding ground under it" — and its rationale, that panic pulls on the fear that sends a bot away and courage on the terms that keep it facing the danger.

## Considered options

For which terms courage multiplies:

1. Firing, and the order's term as the one term in the build that means holding a position.
2. Firing alone, and leave holding ground until there is a hold action of its own.
3. Firing, and lower the flight term instead of raising a hold term.

For how it enters the order's term:

1. By how near the known danger has come: the whole with nothing near, courage with the danger at hand.
2. Flat, beside discipline, whether anything threatens or not.

For the balance the new multiplier changes:

1. Raise the attack term's weight so a bot of middling courage fires exactly as before.
2. Leave the weight and let the squads fire less eagerly.
3. Set every archetype's base courage to one, so nothing changes and the weight is invisible.

## Decision outcome

**The terms, option 1.** `.moveToOrderedZone` is the only action in the build that means holding a position, and it is already the term discipline scales — which is the precedent that settles it: discipline is counted as built although that same term never arises in play, there being no commander yet to give an order (FR-CMD-030).
Courage on it is as built as discipline on it.
Option 3 was refused because the statement says every weight scales its terms **up**: a weight that lowers another term reads as a negative panic, which is the thing the maintainer declined on 2026-09-25.

**The form, option 1 — by the danger's nearness.** Flat beside discipline, courage would be a second discipline: a test varying either would move the same number by the same shape, and nothing in the build would distinguish the weight that holds an order from the weight that holds it *under fire*. The condition is what makes it courage.

**The balance, option 1 — the attack term's weight from 1.0 to 2.0.** A new multiplier in the middle of the range halves the fire term, which would make every squad markedly more cowardly than the build the maintainer has been looking at; that is a change to the feel nobody asked for, and FR-BOT-090 is about making a weight visible, not about reducing fire.
Option 3 would satisfy the arithmetic and leave the weight unreadable in the configuration, which is what FR-BOT-210's rationale warns against: a weight that multiplies nothing is present in the file and absent on screen.

### How it works

Courage is a fifth field of the weights, in the same 0…1 range as the other four, with an allowed range per archetype like theirs.

**Firing** is multiplied by it unconditionally, in both branches that score a shot — at what the bot sees now, and at what it knows of the target it stepped behind cover from (FR-BOT-420).
No condition is needed: everything a bot fires at is something that can kill it, so every shot is facing a danger.

**Holding ground** is multiplied by a factor that runs from the whole, with no danger known, to the bot's courage, with the danger upon it:

```
holding = 1 − nearness(danger) × (1 − courage)
```

where `danger` is the distance to the nearest thing the bot knows of — a part of the snake or an enemy bot it has seen (FR-BOT-330) — and `nearness` is the same ramp over the archetype's detection range that the cover and flight terms use.
A bot of courage 1 holds whatever arrives; one of courage 0 abandons the position the moment something reaches it; with nothing in range the order is worth the obedience weight times discipline and no more.

The reading stays within FR-BOT-220: the distance is taken from the bot's knowledge of the enemy and of the snake, never from where either truly is.

**The base numbers** come from the concept's behaviour column, §8, since its weights column predates courage: heavy 0.8 (slow, guarded, holds), assault 0.7 (presses), sapper 0.5 and sniper 0.5 (average; the sniper's courage is never tested at the range it keeps), medic 0.4 (behind the others), scout 0.3 (runs).
They average 0.53, so the attack weight of 2.0 leaves the six squads together firing about as eagerly as they did.

### Consequences

**A bot of courage 0.5 fires exactly as the build before this did**, which is what makes the change safe to make without the maintainer at the device: the attack weight of 2.0 cancels the new multiplier at the middle of the range.
This was measured rather than assumed. Removing the two courage factors with the weight left at 2.0 turned `testHealthMovesTheChoice` red — a wounded scout kept firing where it used to run — so the rebalance is load-bearing and the suite says so.

**The negation holds.** With both factors removed, the three new tests fail and the fourth, which asserts that courage does not touch an order with nothing near, passes — as it must, since that is the case the factor is written to leave alone.

**FR-BOT-080 is still `partial`, on one ground instead of three.** Q-310 is now the only thing holding it: a decision on what a bot carries beyond its rounds, which is the maintainer's.

**Courage reaches play only through firing today.** The order's term needs a commander to arise, so the second half of the weight is built, tested and unexercised in a match — the same state discipline has been in since it was written.
When FR-CMD-030 lands, both come alive together and FR-BOT-130 will weight the order against the local situation on top of this.
