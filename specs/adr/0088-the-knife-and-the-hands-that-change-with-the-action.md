# ADR-0088 — The knife, and hands that change with the action

- **Status:** accepted
- **Date:** 2026-10-12
- **Related requirements:** FR-BOT-510, FR-BOT-520, FR-VIEW-340, FR-BOT-080, FR-CMD-030, IF-BOT-010, FR-VIEW-070

## Context and problem statement

The third pass of `materials/plans/the-arms.md` builds the knife and what a bot is drawn holding, and with them the seventh input of FR-BOT-080 — what a bot has to fight with — is read for all four weapons rather than for two. Three things had to be settled: how often a knife may be swung, how a throw carries the cost of having no knife afterwards, and how a figure built once can hold a different thing from one slot to the next.

## Decisions

**A knife has a time between strikes, and IF-BOT-010 names it.** Without one it is swung at every deliberation slot: five strikes a second at the maintainer's twenty damage is a hundred damage a second, ten times a rifle, and the first build of it stopped the snake from ever finishing a meal — three match-level tests went red because nothing was ever eaten. That is the fault FR-BOT-450's rationale named for firearms, in a weapon the rationale did not cover: "no requirement gives a weapon a rate of fire; when one does, the cadence moves out of the deliberation period". So `timeBetweenStrikes` joined the knife's numbers, the statement of IF-BOT-010 grew the key, and the shipped knife strikes once a second for twenty — twice a rifle's damage a second at the reach of an arm, which is what "works only very close, and hurts well for it" was asked to mean.

**A strike asks for a clear line, though FR-BOT-510 does not.** It goes through the same targeting as a shot, so it inherits the line of sight and the rule against striking through a squadmate. The requirement's rationale says no line of fire is needed "because at the reach of an arm there is nothing to stand in the way"; in a half-metre grid something can be, and the check costs nothing. Noted here because it is stricter than what was written, not looser.

**Throwing the knife has a weight of its own.** FR-BOT-520's rationale asks the score to carry the cost — a bot that threw has nothing for the next thing that closes with it — and the only honest way to say how much a bot minds that is a number. `utilityTermWeights.thrown` ships at 1.0 against `attack`'s 2.0, so a throw is worth half a shot at the same distance.

**What the hands hold follows the last decision.** The figure is built once with all four weapons on it, each named by which weapon it is, and the view moves them: the one being used into the hands out in front, the primary across the back when it is not, the sidearm and the knife at the belt, the grenades at the belt in front. A weapon a bot no longer carries — a thrown knife, an empty pouch — is taken off the figure altogether. The alternative was to rebuild the figure when the action changed, which would make a mesh every time a bot drew its pistol.

FR-VIEW-070 is not weakened: each archetype's primary keeps a shape of its own, the headgear is untouched, and the sapper keeps its sledgehammer — which is kit rather than a weapon now (ADR-0086), and so is never in the hands. Whether six silhouettes are still six at the camera's distance is its demonstration and the maintainer's eye.

**The commander's priority ranks the kinds of target over all the weapons at once.** Found while building: a bot told to worry about the snake threw its knife at an enemy, because the snake stood a metre beyond the knife's reach and each weapon chose its own target. FR-CMD-030 ranks what the squad worries about, not what one weapon can reach, so the ranking moved out of the per-weapon targeting and over the whole list of attacking actions.

## Consequences

**FR-BOT-080 is `implemented`.** Its seven inputs are read; it had been `partial` since 2026-09-25, when Q-310 was opened.

**Two of the six attacking actions are built and never chosen in play.** Over a hundred and fifty seconds of the shipped arena with nobody steering, the squads fired primaries, struck with knives and threw one grenade; `fire sidearm` and `throw knife` were chosen zero times.

Both lose to the same thing. A bot whose primary is dry scores reloading at 1.2, and no fire term within six metres of sight reaches that — the pistol at a metre is worth about 0.41, the knife thrown at three metres about 0.25. They are chosen where reloading is not on the list at all, which is what `ArmsTests` and `KnifeTests` pose through FR-BOT-167. Whether a bot should draw its pistol rather than reload is tuning — the `empty` weight, or a reload that costs time — and the maintainer's to decide on the phone.

**The match is quicker and the standstill comes sooner.** The shipped arena, nobody steering: the first death at 12.2 s, one squad gone at 53.3 s, three of eight left standing. Before the arms it was 34.8 s, 85.6 s and one. The three survivors then explore and flee without resolving anything, which is Q-620 and Q-480 as before.
