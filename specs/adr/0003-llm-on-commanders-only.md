# ADR-0003 — The language model sets intent through commanders; utility AI executes

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-CMD-010, FR-CMD-060, FR-BOT-080, FR-BOT-090, INV-BOT-010, NFR-PERF-020

## Context and problem statement

Bots have to see the snake, react, retreat, coordinate and shoot, on a phone, beside rendering; and the game's selling point is their voices and characters.
Where does the language model belong in that?

## Considered options

1. An LLM per bot deciding actions.
2. Behaviour trees or utility AI everywhere, no LLM.
3. Three tiers: an LLM commander per squad at 0.1–0.2 Hz setting threat priority, orders, roles and personality weights; utility AI at ~7 Hz choosing each bot's action; plain code every frame executing it; an LLM for speech on events.

## Decision outcome

Option 3.
Option 1 was rejected on three counts.
Grounding: to let a model decide "shoot or take cover" the world is serialised to text, but whoever wrote that line already ran the raycasts, found the cover and judged the threat — the model then picks from a menu, worse than an `if`.
Debugging: a behaviour tree is deterministic and reproducible; "the bot is stuck in a corner" takes ten minutes in a tree and never in a 0.5B model.
Cost: eight executors at 5 Hz is forty inferences a second beside rendering — a permanently busy ANE and visible heat for a choice among four options.
Option 2 loses what the LLM is actually good at: tactical intent, character, and the judgement "should we deal with the enemy against the common threat" (FR-CMD-090).

### Consequences

The LLM influences behaviour only through the weights and orders it sets (FR-CMD-060); it never touches per-frame execution, which runs for every bot every frame (INV-BOT-010).
Whether the commander makes a difference the player can see is H-040 — the hypothesis the concept expects most likely to fall, and whose refutation is a saving.
