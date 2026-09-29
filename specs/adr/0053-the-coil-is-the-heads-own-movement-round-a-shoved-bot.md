# ADR-0053 — The coil is the head's own movement round the bot, shoved to where a ring fits

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-SNAKE-280, FR-SNAKE-270, FR-SNAKE-020, FR-SNAKE-090, FR-SNAKE-100

## Context and problem statement

On 2026-09-29 the maintainer asked for the snake to coil once round a living bot it has lunged at, and then swallow it; a body is simply eaten. They chose a coil that is the head's real movement rather than a picture, the bot shoved out of a corner over time where the ring does not fit, the coil's time added to the meal's, and the bot shooting back meanwhile.
Each still needed a way chosen: how big the ring is, how the head goes round, where "room for the ring" is, and what the bot does while the snake goes round it.

## Considered options

For how the head goes round:

1. Each frame the head is sent, by the snake's own movement, to where round the bot it should be by the frame's end: a whole turn at an even pace over the coil time, round the bot where it stands that frame.
2. The head set on a circle directly, bypassing the movement rules.

For where the ring fits:

1. The nearest place within the shove reach where the body fits at every one of sixteen points round the ring, on ground it can crawl on, looked for outwards in rings a tenth of a metre apart, sixteen ways round.
2. Away from the nearest wall by as much as the ring needs.

## Decision outcome

Option 1 for both. The head through the movement rules is the coil the maintainer asked for — the body lies round the bot because it follows the head's path (FR-SNAKE-020), and where something still stands in the way the head slides along it as it would crawling rather than passing through. A search over places handles a corner, where two walls stand in the way and moving off one of them is not enough, and a room too small for any ring: there the bot stays where it is and the head goes round as far as the room lets it.

### How it works

The ring's radius is two of the tuning's body radii: the head's body and the bot's side by side, the bots' own spacing (FR-BOT-300). It is looked for once, as the coil begins. Each frame the bot is moved towards that place by no more than the shove speed times the frame's time, and the head is sent to its point on the ring round the bot where the bot now stands, starting from the angle the head arrived at. The bot is held as it is while it is eaten: it walks nowhere and is pushed by nobody, and it shoots (FR-SNAKE-100). Once round, the meal begins, and holds the head where the coil ended (FR-SNAKE-090). A bot gone meanwhile ends the coil with nothing.
The numbers are in `config/snake.json`: a coil of 0.6 s, a shove of up to 1 m at 2 m/s. At the shipped length the snake's body, 3.6 m, is a little short of a ring's 3.8 m, so the ring closes to within a segment; a longer snake has body to spare behind it.

### Consequences

A coiled bot is shoved out of its cover by as much as the ring needs, so a meal in a corner is seen from further off than the corner would have allowed.
