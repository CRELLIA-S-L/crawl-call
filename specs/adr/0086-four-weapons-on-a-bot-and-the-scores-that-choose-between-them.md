# ADR-0086 — Four weapons on a bot, and the scores that choose between them

- **Status:** accepted, and superseded in part by ADR-0090: one reload no longer fills everything a bot carries, since each weapon takes its own time to fill.
- **Date:** 2026-10-12
- **Related requirements:** FR-BOT-440, FR-BOT-450, FR-BOT-460, INV-BOT-040, IF-BOT-010, FR-BOT-080, FR-BOT-170, FR-BOT-200

## Context and problem statement

ADR-0075 settled what a bot carries and left eleven requirements written and unbuilt. The first pass of `materials/plans/the-arms.md` builds four of them — the catalogue, the two firearms, the bound over the table and the weapon as an action — and every one of them asked something the requirements do not answer, because they say what the system shall do and not how a score is shaped.

A shot used to be described by two numbers on the archetype, `weaponDamage` and `magazine`, and fired at every deliberation slot. With two firearms on one bot, where the numbers live, how often a weapon may fire, which weapon the scores choose and what reloading means all have to be decided at once.

## Considered options and decisions

**The catalogue and the arms.** `config/bot.json` gained a `weapons` object of three tables — `firearms`, `grenades`, `knives` — and each archetype an `arms` entry naming what it takes out of them. `weaponDamage` and `magazine` left the archetype; run speed, health and detection range stayed, because they belong to the body (ADR-0075). A weapon an archetype names and the catalogue does not hold makes `Bot.init?` nil at the spawn, the same as an archetype with no entry: a typo in the table is a configuration error and never a bot that goes out unarmed.

**The sapper's primary — the question the plan left open.** The plan proposed, and this decision takes, the reading that costs least: the sledgehammer is not the sapper's primary but its wrecking tool, the thing FR-BOT-070 gives it for taking walls apart, and the sapper carries a firearm like everybody else — a carbine. Any other answer breaks INV-BOT-040, which a weapon reaching no further than an arm cannot satisfy against a pistol. The figure keeps the sledgehammer: FR-VIEW-070 reads an archetype off what it carries, and pass 3 draws the tool where the hands are not.

**The numbers of the shipped table.** Each archetype's primary was given about ten damage a second, as the single weapon had — 2 damage every 0.2 s — so that the fight the maintainer has been watching is the fight the arms arrive into. A long rifle deals ten once a second, a shoulder gun four every 0.4 s, a submachine gun one and a half every 0.15 s; the pistol everybody falls back on deals one every 0.2 s and reaches six metres against the primaries' ten to twenty. Which is tuning, and the maintainer's to feel out on the phone.

**How often a weapon may fire.** The guard is the weapon's own time between shots, with the deliberation period left standing beside it for a bot given a slot ahead of the queue (FR-BOT-170, ADR-0057). A weapon quicker than a slot therefore fires once a slot and no faster, and one slower than a slot is aimed through the slots it waits out. The comparison carries a nanosecond of slack (`Firing.cadenceSlack`): a weapon whose cadence *is* the period must fire at every slot, and the difference of two times a match added up a frame at a time is the period give or take the last bits of a double. Without the slack the shipped assault fired at every other slot — found by a test that asked for two shots two slots apart and got one.

**What a weapon contributes to the score of firing with it.** Each firearm with a round left and a target inside its range is scored on its own: the share of its own magazine still in it, and its damage against the hardest-hitting weapon the bot carries — a whole for the primary, a share for the sidearm, which INV-BOT-040 is what guarantees. Everything else about the term is as it was.

The alternative was to measure the nearness of the target within the weapon's range rather than within the bot's detection range. It was rejected: at six metres of sight and twelve of reach it multiplies the attack term by three and a half at the distances bots actually fight at, and the balance of attacking against hiding is the maintainer's to move on the phone, not something to shift sideways inside a mechanical change. The range gates the action instead — a target beyond a weapon's reach is no target for it, rather than one it scores at nothing — which is what FR-BOT-460 asks for in the words "whose range covers its target".

**What reloading means now.** One action for everything the bot carries, because FR-BOT-200 names one and a bot that stops to reload reloads what it has. What it is worth is the emptiest magazine of the two and not the sum of them.

That one was measured. With the sum, a bot with a dry primary and a full pistol is half as keen to reload as a bot with nothing at all, so it keeps firing the sidearm instead of going behind cover — and the shipped match lost its movement: the furthest any bot got from where it stood over the half minute after the squads met fell to 0.91 m, against the two metres `IdleTests` has required since Q-600 was settled. With the emptiest, the term is exactly what the single magazine's was, and the match moves 4 to 10 metres a window again.

**What the sidearm is actually worth, stated plainly.** It is scored wherever it reaches, and with the shipped weights it is chosen almost nowhere: a dry primary makes the reload term 1.2, and no fire term inside six metres of sight reaches that — the pistol at a metre is worth about 0.41. Over a hundred and fifty seconds of the shipped match, `fire sidearm` was chosen zero times. The one state that does choose it is a bot whose reload is off its list because the hidden cell it would reload in cannot be routed to (FR-BOT-167), which `ArmsTests` poses. This is the deliberation deciding and not a mechanism failing, but if the maintainer wants a pistol to be drawn in a firefight the lever is the `empty` weight, or a reload that costs time — and either is tuning, not a requirement.

## Consequences

**FR-BOT-080 is still `partial`, and the end of it is in sight.** Its seventh input is read now for the firearms; the grenade and the knife are passes 2 and 3, and the requirement goes to `implemented` when the last of them lands.

**IF-BOT-010 is `implemented` again**, and its statement grew a key: FR-BOT-480 deals a grenade "its damage" and nothing said where that number lives, so `damage` was written into the grenade's list on 2026-10-12.

**`Bot.ammunition` is gone.** What a bot has left is `arms.rounds` over both firearms, and there is one way to ask rather than two. The interrupt that fires when a magazine runs dry now watches each firearm separately — emptying either is the event FR-BOT-170 names — and the pouch the commander hears about counts both, because a soldier with a dry rifle and a full pistol has something to fire with.

**The match is a little more lethal, and reads better.** Over a hundred and fifty seconds of the shipped arena with nobody steering: the first death at 34.8 s, one squad gone at 85.6 s, one bot left standing of eight, and 2.6 to 10.6 metres of ground covered per ten seconds while the fight was on. Before the arms it was one squad gone between the seventieth second and the ninetieth and two bots left (Q-620). The pacing of the survivor is unchanged and still Q-620's.
