# ADR-0100 — Greed is the sixth weight, and a commander is what holds it

- **Status:** accepted
- **Date:** 2026-10-14
- **Related requirements:** FR-BOT-710, FR-BOT-720, FR-BOT-690, FR-BOT-700, FR-BOT-090, FR-BOT-030, FR-BOT-620, FR-BOT-630, FR-BOT-640, FR-CMD-125, FR-CMD-130, IF-BOT-010

## Context and problem statement

ADR-0099 took the prize off a squad's list while any of its bots could see a threat, and the rule worked too well. Measured on the shipped arena over five minutes of match time, nobody steering: the treasure was picked up **once**, carried for **0.1 s**, first touched at 49.1 s, and the match never ended. With six a side and a snake, somebody is nearly always looking at something, so the box never moved — which put the game back where concept §6.4 had it, the prize going to whoever had already won the war.

The maintainer answered with a mechanic rather than a number: give the bots greed, let it cross fear, courage and obedience, let a bot now and then leave the fighting to drag the box aside, have the commander put a stop to it — and accept the side effect that a squad which loses its commander may turn to looting.

## Decisions

**Greed is a sixth personality weight**, beside aggression, courage, discipline, panic and self-sacrifice (FR-BOT-030, FR-BOT-090), in the same 0…1 range with an allowed range per archetype like theirs. The concept's §8 table predates it, as it predates courage, so the base numbers are tuning read off what each archetype does: the scout that goes out alone 0.8, the sapper 0.6, the assault 0.5, the sniper 0.4, the heavy and the medic 0.3.

**The ban becomes a scaling.** FR-BOT-690 no longer removes the two treasure motives in a fight; it leaves them worth the bot's greed of what they were worth. At greed nothing the rule is the ban it replaced, which is what the negation test reads. This is also where greed meets fear: what is left of the prize is scored against taking cover and running, which panic pays for (FR-BOT-090), so a frightened bot is tempted and hides anyway.

**A standing order is the only thing that holds it down** (FR-BOT-710): under one, greed is scaled by one minus the bot's discipline. The commander has no other way in — it has set no weights since FR-CMD-060 was withdrawn (ADR-0085) — and discipline is already the weight that says how much of an order survives a bot's own reading (FR-BOT-130), so both sides of discipline now move as one number. The looting the maintainer asked for then needs no rule of its own: FR-CMD-125 clears the order when the role-holder falls, and every reading of greed goes back to the whole of the weight in the next frame.

**Who may hold the prize in a fight is greed against discipline**, not greed against panic (FR-BOT-700, FR-BOT-720). Panic was the first shape and reverses the effect: the commander's death raises the whole squad's panic by the collapse increment (FR-CMD-130), so the squad that lost its commander would have been the one squad that never looted. Against discipline, the shipped weights make two archetypes of six able to keep the box under fire once nothing scales their greed down — the scout and the sapper — and none of them while an order stands.

**Picking up and putting down are still the match's rules** (FR-BOT-630, FR-BOT-700), and they ask the same question, so a bot never picks up what the next frame makes it drop.

## Consequences

Measured on the shipped arena, five minutes, nobody steering, one deterministic run each:

| | picked up | put down | carried | first touched | carriers | box moved | alive at the end |
|---|---|---|---|---|---|---|---|
| before greed, prize banned in a fight | 1 | 1 | 0.1 s | 49.1 s | 1 | — | 3 |
| greed, nobody commanding | 2 | 2 | 35.9 s | 12.8 s | 2 | 7.4 m | 4 |
| greed, both squads told to hold the middle | 1 | 1 | 1.2 s | 99.4 s | 1 | 1.5 m | 3 |

So the mechanic reads as asked: uncommanded, the box is dragged about for a third of a minute by two different bots and moved seven metres off its cell; commanded, it is touched once in a hundred seconds and goes a metre and a half. Neither match ends within five minutes, because leaving with the prize still needs the other crew gone (FR-SCORE-160) and a carrier walks at a third speed with no hand for a weapon.

The end-to-end second act went green with this change and had been failing without it: `SecondActTests` plays two a side on the room map, and the carrier it needs could not exist while a visible threat banned carrying outright. `CommanderOrdersTests` went green with it too — the squad told to press east spends its match further east again, because the box now pulls on the bots in a fight and the routes it was measured on are back.

What is deliberately not built: nothing makes a squad cover its looter, and nothing on screen says why a bot is walking away from a firefight with a box. The orders bar (FR-VIEW-380) says what the squad was told, not what one bot is doing instead.
