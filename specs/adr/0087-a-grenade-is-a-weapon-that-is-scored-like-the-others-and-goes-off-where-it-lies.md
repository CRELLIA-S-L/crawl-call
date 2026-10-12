# ADR-0087 — A grenade is a weapon scored like the others, and it goes off where it lies

- **Status:** accepted
- **Date:** 2026-10-12
- **Related requirements:** FR-BOT-470, FR-BOT-480, FR-BOT-490, FR-BOT-500, FR-BOT-460, FR-BOT-220, IF-BOT-010

## Context and problem statement

The second pass of `materials/plans/the-arms.md` builds the grenade. The four requirements say what a throw does — it goes no further than the throw range and waits out its fuse, it takes every body in the blast, it hurts a snake the more of it lies there, and it is never thrown onto a squadmate the thrower can see. None of them says how a bot decides to throw one, and that is the whole of what had to be settled.

## Decisions

**The grenade is a weapon and is scored as one.** FR-BOT-460 already says each weapon with ammunition left whose range covers the target is an action of its own, so the throw goes through the same targeting as a shot, with the throw range as its reach and what is left in the pouch as its magazine. It aims at what the bot sees, like a round, and so it never passes through a wall.

The cost of that is stated here rather than hidden: FR-BOT-440's rationale calls the grenade the weapon that "crosses what a bot cannot shoot through", and this build does not do that. A grenade thrown over a wall at a place the bot remembers an enemy is a different action with a different target set, and nothing in the four requirements asks for it. When the maintainer wants it, it is a requirement of its own.

**It does not fly.** The grenade lies where it was thrown and goes off when its fuse has run out. FR-BOT-470 asks for the range and the fuse and nothing else; the path "is drawing", as its rationale says, and what a thrown thing meets on the way is the question FR-BOT-405 answers for a round and no requirement asks for a grenade. Nothing is drawn for it yet either.

**The thrower's own place is refused, not priced.** ADR-0075 said a bot needs no rule against throwing at its own feet because "its own score already refuses it". It does not: no term in the deliberation prices what a bot does to itself, and the blast takes the thrower (FR-BOT-480). So the same check that keeps a seen squadmate out of the blast (FR-BOT-500) keeps the thrower out of it. Friendly fire through a squadmate the thrower cannot see stays exactly as ADR-0075 decided, and is correct rather than a fault (FR-BOT-220).

**What a throw is worth, and the one new number.** `utilityTermWeights.blast` joins the table — IF-BOT-010 names "the weight of each term in an action's score", so a term weight is within what the interface already carries. The throw is worth that weight, the nearness of the target, the share of the pouch still full, and the bot's aggression and courage — the fire term's shape with `blast` in the place of `attack`. It is then raised by what the blast would catch: a share for every body beyond the first, and the same share the damage itself grows by (FR-BOT-490), so that one number in the configuration moves both. A snake counts as one body however much of it lies in the blast, because a long snake across a blast would otherwise be worth ten of anything else a bot could do.

**The weight was chosen by measurement, over a hundred and fifty seconds of the shipped arena with nobody steering:**

| `blast` | what the match did |
|---|---|
| 1.0 | not one grenade thrown in the whole match; the firefight is exactly the one pass 1 measured, one squad gone at 85.6 s |
| 1.2 | the opening is unchanged, one grenade thrown at about 40 s, four of eight down by 44.8 s |
| 1.5 | grenades out in the first ten seconds, five of eight down by 29.6 s, and the rest of the match a stalemate |

1.2 ships. At 1.0 the mechanism cannot be judged at all, because it never happens; at 1.5 it decides the match before the squads have finished closing. What it buys is a grenade a bot throws when its magazine is between about half and three fifths spent and a target is in reach — and sooner where two or three enemies stand in one blast, which is what the weight is for.

**Grenades make the standstill arrive earlier, and that is not the grenade's fault.** At 1.2 the match reaches two against two by the forty-fifth second and then stops resolving: from the fiftieth second to the hundred and fiftieth nobody fires a round, the four survivors advancing, taking cover and standing. That is Q-480 — squads that lose sight of each other stop fighting — reached by a shorter road, and it is why the arena now shows it at half a minute rather than at a minute and a half.

## Consequences

**FR-BOT-080 is one pass from done.** The knife and the hands are pass 3.

**Nothing is drawn.** A grenade in the air is a value in the match and nothing on the screen; FR-VIEW-170 draws rounds and no requirement draws a thrown grenade.

**A blast and a round are one wound to the snake.** The frame sums what the rounds struck and what the blasts covered and calls FR-SNAKE-070 once, which is what FR-BOT-490's "deal the raised amount once" asks for.
