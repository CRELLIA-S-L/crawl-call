# ADR-0063 — A round flies at where its target was, and a bot fires from beside cover or on the move

- **Status:** accepted
- **Date:** 2026-09-30
- **Related requirements:** FR-BOT-060, FR-BOT-400, FR-BOT-405, FR-BOT-410, FR-BOT-420, FR-BOT-425, FR-BOT-430, FR-VIEW-170, IF-BOT-010, FR-BOT-330, FR-BOT-320

## Context and problem statement

On 2026-09-30 the maintainer found bots standing before one another and firing point-blank, and asked for bots that avoid danger: fire from cover, or at least move. A shot struck in the step it was fired (ADR-0044), so moving saved nobody. The maintainer chose a round that flies over a chance to hit, a miss that flies on and strikes whoever is in its way, the same for the snake, and cover where there is some with movement where there is none; the numbers were agreed with the texts (IF-BOT-010).
Each requirement left a way to be chosen: where a round is sent and what it strikes, where a bot fires from and when it comes back out, and which way it moves.

## Considered options

For where a round is sent:

1. At the point where the target is as it fires.
2. Ahead of the target, where it will be if it keeps going.

For how a bot behind cover gets back to the fight:

1. A bot that stepped behind cover to reload goes back to fire from where it did, at what it was firing at as it knows it, and fires once it sees it.
2. It waits behind the cover until the enemy comes into view.

## Decision outcome

A round is sent at where the target is (option 1): that is FR-BOT-060's wording, and leading the target would make moving worth nothing again.
A bot comes back out (option 1): without it the first reload ends the fight, since behind cover the bot sees nobody and so has nobody to fire at.

### How it works

**Where a round is sent.** At an enemy bot's eyes, as a line of fire has run since ADR-0044; at the snake, at the middle of its body over the part the bot sees, which lies on the ground under it — raised by the body radius — so that a round that misses flies on over the ground rather than into it. Whether there is a line of fire is still judged to the part on the ground, as the bot sees it (FR-BOT-050).

**Flight.** Every frame, before the bots decide, each round flies the frame's time at the round speed and never past the round range. Of what the stretch it flies meets, the nearest is taken: the first module that stops sight (FR-MAP-220), a living bot other than its shooter, or the snake. A bot is a capsule of the body radius round the ground it stands on up to its figure's height; the snake is capsules of the body radius round the line through its head and tail points, raised by the radius, as it is drawn. A body lies flat and is not struck. Where a stretch first comes within a capsule is found by narrowing: the distance from a point moving along a straight line to a segment falls and then rises, so its least is found by thirds and the first touch before it by halving. What it strikes on the snake is added up and given to the snake by the match, which ends the match if the snake has nothing left (FR-SCORE-140); a bot is hurt, and falls, at once.

**The streak.** A round is drawn as a bar half a metre long ending where it is, shorter where it has not flown that far, so that it never reaches behind the shooter's eyes. The pool of bars is sized from the configuration: as many rounds as a bot can have in flight — the range over the speed, in deliberation periods, and one more.

**Not through a squadmate.** A target is dropped where a squadmate the bot sees, by FR-BOT-050's test, would be struck by a round flown along the line of fire: the same capsule the flight strikes.

**Beside cover.** When a bot chooses to fire, the cells it knows within the cover search distance are taken nearest first, by straight distance; the first from which its eyes have a line of fire to where the round would be sent, and which has a neighbour on the graph that the bot knows and that no enemy and no part of the snake it knows of watches — FR-BOT-330's watched — is where it fires from, the neighbour where it hides. A cell a squadmate has taken for either is neither: two bots making for one cell push each other off it (FR-BOT-300) for as long as both want it, and neither ever gets there — found on the simulator the day it was built, two bots reloading for ever beside one crate. The two are kept while the line of fire and the hiding still hold, and looked for again when either fails; a bot that found none does not look again until the strafing interval has passed. It fires as it goes there, wherever it has a line of fire.

**Reloading.** A bot that fires from beside cover and chooses to reload walks into the hidden cell and has a full magazine when it gets there; one with no cover beside it reloads where it stands, at once, as before.

**Coming back out.** A bot with somewhere to fire from beside cover that sees nothing to fire at is offered firing at what it was firing at from there, as it last saw it: the nearest part of the snake it remembers, or where it last saw the enemy bot, scored as firing is — unless it sees the place and the target is not there, when what it knows is no target and nothing is offered. It goes back to where it fired from, and a round goes only at a target it sees now: a bot sent out at a memory does not fire at it.

**On the move.** A bot firing with no cell beside cover moves level across the line from where it is to where it knows its target to be, at the strafing speed, gathering and shedding speed at the acceleration (FR-BOT-290). It turns back once the strafing interval has passed, and where the ground it would move onto does not hold it, by the test a straight walk uses (FR-BOT-270). It faces its target the while, as a firing bot does.

### Consequences

Fire from an enemy that stands still at its post still strikes every time; what the change buys is that a bot hides for its reloads and a bot in the open is hard to hit from afar.
ADR-0044's damage dealt at once is replaced; the rest of it stands.
Two squads that lose sight of each other still stop fighting, as they did before the change; the fight lasts longer, measured the same day (Q-480).
Tests that walked the snake to where a bot stood at the start now follow the bot, because a bot under fire no longer stands still.
