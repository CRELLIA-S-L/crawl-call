# ADR-0064 — A bot passes a point of its route once over it, stops against a bot on its cell, and faces its route beyond its feet

- **Status:** accepted
- **Date:** 2026-09-30
- **Related requirements:** FR-BOT-300, FR-BOT-280, FR-BOT-270, FR-BOT-420

## Context and problem statement

On 2026-09-30 the maintainer saw bots in a fight standing on the spot and twitching fast, seemingly those that could not get to the enemy. On the simulator the same day two bots of a squad, starting from the spawn at (5, 5), went back and forth twenty-eight times a second: both were making for one corner of their routes, each walked onto it, and the push apart of FR-BOT-300 put each back off it, every frame. The build before the change showed the same, twenty and eighteen times a second; bots now more often want one cell — a cell to fire from, one to hide in — so it is seen more.
A bot walking in a group also turned this way and that, because it faced the way the frame moved it, pushes included.

## Considered options

1. A point of a route that is not its end is passed once the bot is within a body radius of it; a bot stops where another bot stands on the cell it is making for and it is up against that bot; a walking bot faces the first point of its route more than a cell away.
2. Leave walking alone and let the push apart spare a bot that is walking.
3. Give every bot its own cells to go to, so that no two ever want one.

## Decision outcome

Option 1. Option 2 lets a walking bot walk through a standing one, which is what FR-BOT-300 forbids. Option 3 covers where a bot fires from and hides (ADR-0063 does that for those), but not the corner of a corridor two bots pass on their way.

### How it works

- Walking its route, a bot drops each point before the last that it is within its body radius of, on its own floor, and walks on to the next; the last it walks onto as before.
- Before walking, a bot whose way ends on a cell with another living bot within a body radius of its centre, and which is within two body radii and five centimetres of that bot, has arrived: it stops, and an action that was going somewhere is spent, as one with no route is.
- A walking bot faces the first point of its route that lies more than a cell from it, or the last point where none does; one pushed with no route faces the way it moved, as before.

### Consequences

A bot can stop a body's width short of the cell it was sent to, where another holds it; what it does next is its next decision's.
Measured on the simulator over the three spawns, ninety seconds each: no second in which a bot went back and forth ten times or more, where the build before had two; turns back and forth of more than 1.7 degrees a frame, 903 against 884 before, about the same, with 23 bot-seconds of three or more such turns against 35.
