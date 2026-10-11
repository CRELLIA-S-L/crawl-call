# ADR-0075 — A bot carries four weapons, and each is an action of its own

- **Status:** accepted
- **Date:** 2026-10-11
- **Related requirements:** FR-BOT-070, FR-BOT-080, FR-BOT-200, FR-BOT-440, FR-BOT-450, FR-BOT-460, FR-BOT-470, FR-BOT-480, FR-BOT-490, FR-BOT-500, FR-BOT-510, FR-BOT-520, INV-BOT-040, FR-VIEW-340, IF-BOT-010

## Context and problem statement

FR-BOT-080 names seven inputs to a bot's choice of action, and the seventh is what it has to fight with.
Since 2026-09-25 that input had nothing behind it: a bot had one unnamed weapon, described by three numbers on its archetype — damage, magazine, detection range — and Q-310 held the question of what else it carries.
On 2026-10-11, with the other six inputs read and courage built (ADR-0074), Q-310 was the only thing left holding the most connected requirement in the specification at `partial`.

The maintainer settled it the same day: a bot carries a primary weapon that depends on its class, a sidearm, grenades and a knife, with four questions answered in the course of it.

## Considered options

Each of the four was put with a recommendation, and two of the four recommendations were overturned.

**Whether an explosion hurts the squad.** (1) It hits everyone in the blast, the thrower included. (2) It spares the thrower's squad.

**Whether a grenade breaks cover.** (1) It does not: destruction stays the heavy's and the sapper's trait. (2) It damages a module like any wrecking weapon.

**What an explosion does to a snake lying across it.** (1) Damage once, whatever it covers. (2) Damage once per part covered. (3) Damage once, raised by a share for each part beyond the first.

**What a bot is drawn holding.** (1) One carried thing per archetype, as ADR-0022 drew it. (2) What it is using, with the rest stowed.

## Decision outcome

**The squad, option 1 — any weapon hits your own.** The maintainer's words. For a round this has held since FR-BOT-400, which strikes whoever is in its way; an explosion that spared the squad would be the one weapon a bot could throw without thinking, and thinking is what the deliberation layer is for.
It costs a second requirement, FR-BOT-500, the shape of FR-BOT-410 for a blast: a bot does not throw where it sees a squadmate standing in the radius.
The thrower needs no rule of its own — a place inside its own blast is a place its own score already refuses.

**Cover, option 2 — the recommendation was overturned.** The maintainer: one throw does not break a wall but weakens it, and enough of them break it; cover should have health.
It already does. FR-MAP-030 accumulates damage on a destructible module and steps it from intact to damaged to debris, never skipping and never going back, so a grenade needs no new mechanism — only a share of that accumulated damage.
FR-BOT-070 widened to say so. Rounds from a primary or a sidearm still leave a module alone, because destruction is an archetype's trait in concept §8 and FR-BOT-105 — which prices cover by whether the enemy carries a wrecking weapon — says nothing at all if every rifle is one.

**The snake, option 3 — the recommendation was overturned, and the third reading is the maintainer's own.** Once per part makes the grenade the answer to a long snake and takes away the bet the concept is built on, that length is the player's trade; once flat makes a blast laid along the whole body worth no more than one at the tail tip.
A share for each part beyond the first — the maintainer named 15 to 20 per cent — sits between them: five parts covered is worth about 1.6 to 1.8 blasts, never five.
It is dealt once, so FR-SNAKE-070 takes the tail off by the raised amount in one act rather than five times over.

**The figure, option 2.** A bot holds what it is using; the primary rides across its back, the sidearm and the knife at the belt, the grenades at the belt or chest.
ADR-0022's table of one carried thing per archetype is rewritten by this, and FR-VIEW-070 is not weakened: the archetype stays readable from what is in the hands or on the back, from the bot's size and from what it wears, and six silhouettes remain six.

### How the arms are described

**The numbers belong to the weapon, not to the bot** (FR-BOT-450). With one weapon per bot it made no difference where damage, range and magazine lived; with two firearms on one bot it is the whole of the difference, since a sidearm weaker and shorter-ranged than the primary cannot be described by numbers that belong to the body carrying both.
The time between shots moves with them, which FR-BOT-060's rationale had already parked against the day a weapon wanted a rate of fire: a sidearm that trades damage for cadence and magazine depth is that day.
What stays on the archetype is what belongs to the body — run speed, health, detection range.

**The configuration holds a catalogue, and an archetype names what it takes from it** (IF-BOT-010). This is what makes "different pistols on different bots" a matter of tuning rather than of requirements: nothing here names a weapon, and the table may give the scout and the medic different sidearms without a word changing in `specs/`.

**One bound over the table** (INV-BOT-040): an archetype's primary stands above its sidearm in range and damage. Range and damage only — a sidearm may fire faster and hold more, which is the trade that makes it worth carrying.

**Each weapon is an action, not a rule** (FR-BOT-460). A rule — the primary where it reaches, the sidearm otherwise — would be a second decision procedure standing beside the one the whole layer is built on, and the personality weights would stop reaching the choice of weapon.
Scoring each weapon that has ammunition and reaches as an action of its own keeps FR-BOT-080 the only chooser, and widens the floor FR-BOT-200 sets from one entry for firing to one per weapon.

## Consequences

**FR-BOT-080 is still `partial`, and for a new reason.** Its seventh input is specified and not built. That is a better state than undecided and a worse one than done, and it will stay until the arms are built.

**IF-BOT-010 went from `implemented` to `partial`.** Its statement now names the catalogue and the arms, and the build reads neither; a bot still carries one unnamed weapon whose damage and magazine are its archetype's. Nothing broke — the requirement grew.

**Eleven records written, none built.** FR-BOT-440 through FR-BOT-520, INV-BOT-040 and FR-VIEW-340, all `deferred`, with FR-BOT-070 widened and IF-BOT-010 amended. Building them is a separate act and a large one: four kinds of weapon, a thrown thing with a fuse, damage over a volume, and a figure whose hands change with its action.

**Nothing in the grounds register carries them, and that was asked.** H-030 — watching someone else's fight beats chasing — was offered as the hypothesis the arms would stand on, its `impact` already naming the second squad as the most expensive layer.
The maintainer declined it on 2026-10-11: the arms are core and stand on their word, not on a bet.
No `U` declaration either, for the same reason — the absence of a ground here is a decision and not a gap.

**What was deliberately left out.** Which weapon each archetype carries, which sidearms exist, how many grenades a sapper has against a sniper — all tuning, all in `config/bot.json`, none of it in the specification, the same way the personality weights were handled (FR-BOT-030).
Posture (Q-340) still waits, and it names grenades: a lying bot throws none.
