# ADR-0076 — The commander role goes to the first eligible bot, and an empty list excludes nobody

- **Status:** accepted
- **Date:** 2026-10-11
- **Related requirements:** FR-BOT-040, FR-CMD-120, FR-CMD-140, IF-BOT-010, INV-BOT-030

## Context and problem statement

FR-BOT-040 obliges the system to designate exactly one bot in each squad, of any archetype the match configuration allows, as the holder of the commander role, without marking it visually.
ADR-0011 settled the shape of the role on 2026-09-21 — a role on a bot of any archetype, found by listening to who speaks the orders — and left two things for the build.

**What an empty list of eligible archetypes means.** `config/match.json` ships `commanderEligibleArchetypes: []`. Read as an allow-list it admits nobody, and both squads begin a match voiceless, which makes FR-BOT-040 unsatisfiable by the shipped configuration.

**Which of the eligible bots gets it.** The requirement says "exactly one" and says nothing about which.

## Considered options

For the empty list:

1. Empty admits every archetype; the list restricts only when it names something.
2. Empty admits nobody, and the shipped file is wrong and must name the six.

For the choice among the eligible:

1. The lowest-numbered bot of the squad.
2. A bot chosen by something that varies between matches, so that the holder cannot be learnt by archetype.
3. The bot nearest the squad's centre.

## Decision outcome

**The empty list, option 1.** ADR-0011's own words are "the match configuration may exclude archetypes from it as tuning" — an exclusion list in everything but name. Under option 2 the shipped file would have to repeat all six archetypes to say "no restriction", which is the longest way to write nothing, and a file that forgot to would silently remove the voice the whole CMD area is built on.

**The choice, option 1 — the lowest-numbered bot.** Spawning in this project is deterministic on purpose, so that the same map always produces the same match (ADR-0056), and the role is part of a spawn. Options 2 and 3 were refused as inventions: FR-BOT-040 asks for one holder and not for an unpredictable one, and a rule nothing in the specification asks for is a rule nobody can check against anything.

### What this costs, and the lever that answers it

The holder is therefore always the squad's first bot, which under the shipped round-robin of archetypes is always the assault.
A player who learns that has a shortcut to the most valuable target in the game — which is the thing ADR-0011 refused a visual marker to avoid.

The lever for it already exists and is the one ADR-0011 named: `commanderEligibleArchetypes` moves the role to whichever archetypes it lists.
That makes the tell a tuning choice rather than a property of the build, and it is the maintainer's to set.
If the shortcut is judged to matter, the answer is a requirement asking for a holder that cannot be read off the archetype — and that requirement does not exist today.

### Where the flag lives

On the bot, as `isCommander`, and a body keeps it: losing the holder is what collapses a squad (FR-CMD-120), so the question the game asks is whether a *living* bot still carries the flag, not whether the flag exists.

Nothing draws it. The guarantee is structural rather than a rule anybody has to remember: `Figure.parts` is handed an archetype and never a bot, so a marker would have nothing to branch on, and the test that pins the role to no drawing is a test that would stop compiling if a bot were ever handed to it.

## Consequences

**The shipped squad fields four archetypes of the six.** Archetypes are dealt round-robin — `Archetype.allCases[index % 6]` — and `squadSize` is 4, so every squad is an assault, a heavy, a sapper and a scout. No sniper and no medic has ever been in a match.
That is not this decision's doing and it is not a defect of it, but it was found here and it is now Q-550: the medic's heal is the one action of FR-BOT-200 that nothing in play can reach, and FR-VIEW-070 asks a player to tell six silhouettes apart when four are ever shown.

**The role is in place before anything calls a model.** FR-CMD-010 needs a holder per squad to run a commander for; FR-CMD-120 and FR-CMD-125 need one to lose. This is the piece of the commander that needed no model at all, which is why it was built first.
