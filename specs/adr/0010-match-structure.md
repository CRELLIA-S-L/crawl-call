# ADR-0010 — A match is finite prey, no clock, and the war goes on until the arena is empty

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-BOT-020, FR-SCORE-140, FR-SCORE-150, FR-MAP-040, FR-SNAKE-210

## Context and problem statement

Concept §14 leaves four questions that decide what a match is: the squad size (Q-020), reinforcements (Q-030), how a match ends and what happens when one squad is wiped out (Q-050), and whether pure stealth needs a counterweight (Q-060).
They are one decision, because each answer changes the others.

## Considered options

Squad size: 4v4, 5v5 or 6v6.
Reinforcements: none; a limited pool; endless waves.
End: extermination of both squads; a timer; a score threshold; the snake's death.
One squad wiped out: the match ends; the match continues against the survivors.
Counterweight to stealth: none; a decaying multiplier for inaction; timer pressure.

## Decision outcome

**4v4** for the vertical slice, as concept §14 already proposes: eight bots is the load the thermal budget (§15) and the readability of the fight were sized for, and the size stays a configuration value in case the measurements allow more.

**No reinforcements.** A new bot arriving would not know what its squad knows, which breaks the awareness scale; and living head-count is the balance-of-power signal the score reads (FR-SCORE-040), which reinforcements would keep resetting.
The worry behind the question — a finite war that ends when prey runs out — is answered by the end condition instead.

**A match ends when the snake dies or when no bot is left alive**; there is no timer and no score threshold.
The score is the result, not the goal: a player who clears the arena has won the match, and how well is the score.
A timer would punish exactly the waiting that H-030 is meant to observe.

**When one squad is wiped out the match continues.** Concept §1 says what happens: the survivors turn on the snake as a group with nothing left to distract them.
That is the punishment for greed and the reason to keep the war going; ending the match there would delete the strategic layer.

**No artificial counterweight to stealth.** Concept §7 already names the regulator: while the snake waits, the squads take the map apart fighting each other, and a map ground to rubble is worse for the snake too — "the snake that stalls for the balance of power pays for it in opening space".
A decaying multiplier or a timer would add a rule to a game that prefers to punish through the situation.
Whether waiting actually stays bounded in play is a claim about players and belongs in the grounds register as a hypothesis, which is the maintainer's to write; the design does not depend on it.

### Consequences

Two end-of-match requirements (FR-SCORE-140, FR-SCORE-150) and nothing else: no timer to display, no wave counter.
A match against a lone surviving squad is expected to be short and hard; if playtests show it is instead a dull chase, the lever is the squads' collapse behaviour (FR-CMD-130), not a reinforcement.
Erosion of cover as the pacing mechanism makes the destruction tuning (IF-MAP-020) the knob that sets match length.
