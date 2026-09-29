# ADR-0057 — An interrupt is found by comparing frames and served in the next one

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-BOT-170, FR-BOT-160, FR-BOT-150, FR-BOT-060

## Context and problem statement

FR-BOT-170 gives a bot the next deliberation slot ahead of the queue when one of its events happens to it.
Deliberation runs on a clock of its own (FR-BOT-150), a step about every fifth of a second, so "the next slot" read as the next step leaves a bot up to a step late — the delay the requirement exists to remove.
Its events also happen in different places: a hit inside a deliberation step, a death inside a meal, a sighting inside perception. And being hit is the commonest event of a firefight, so a slot that also let a bot fire would double the fire of both squads.

## Considered options

1. Each event found where it happens, and the bot deliberated there and then.
2. The events found by comparing the bots as a frame found them with the bots as it left them; the bots found are served in the next frame, a step of their own when the clock gives none.
3. As option 2, the bots served at the next step of the clock.

## Decision outcome

Option 2. One place finds every event, from what the frame changed, so an event added later — cover destroyed, a marked body, an order — is one more comparison rather than a hook in another part of the game. A bot is served one frame after its event, not up to a step after.
Option 1 deliberates inside a meal or a volley, with the rest of the frame not yet done.
Option 3 keeps the delay.

### How it works

- Hit: its health is lower than when the frame began.
- The snake close: it sees a part of the snake now within the interrupt distance and did not at the end of the last frame; staying close is not a new event, or a bot beside the snake would hold a slot every frame.
- An ally died: a squadmate alive when the frame began is dead or eaten when it ends, where the bot sees the spot.
- The magazine empty: its rounds went from some to none.
- A meal seen: it sees the bot the snake is coiled round or eating, once a meal.
- In the next frame the interrupted bots deliberate before the queue, up to the per-frame maximum; with no step of the clock in that frame they have a step of their own, which advances nobody else's wait.
- A bot holding such a slot chooses as any other, but fires only where more than a deliberation period has passed since its last shot: being hit is a reason to decide, not a faster trigger finger.

### Consequences

A match's deliberations per second rise with what happens in it, bounded by the per-frame maximum.
Being found from the frame's changes, an event is a frame late; at sixty frames a second that is 17 ms, against the 200 ms of a step.
