# The arms: four weapons on every bot

A plan written on 2026-10-11 at the maintainer's request, alongside `the-commanders.md`.
It is written so that an agent with no memory of the conversation can take it up: everything it needs is here or pointed to from here.

**Nothing here changes the specification.** The eleven requirements below were written the same day, all `deferred`, settling Q-310 — the decisions behind them are in ADR-0075 and that record wins where this plan and it disagree. `specs/` is the record; a decision taken while building goes to `specs/adr/`.

Every number was derived from the tree on 2026-10-11 with the command given beside it. Re-derive rather than trust it.

## Why this is worth building

FR-BOT-080 — Action chosen by maximum utility (specs/10-fr-bot.md, partial) is the most constrained requirement in the specification — 26 incoming links, `python3 srs-dd/tools/srs_arch.py --drivers` — and it names seven inputs to a bot's choice. Six are read. The seventh is what a bot has to fight with, and today a bot has one unnamed weapon described by three numbers on its archetype.

That was Q-310 from 2026-09-25 until the maintainer settled it on 2026-10-11: a bot carries a primary weapon that depends on its class, a sidearm, grenades and a knife. Eleven records came out of it. Building them closes the last gap in the project's most connected requirement, and it is the change a player sees on the screen rather than in a graph.

## What is being built

| Requirement | What it obliges |
|---|---|
| FR-BOT-440 — What a bot carries (specs/10-fr-bot.md, deferred) | a spawned bot gets the arms its archetype names: a primary, a sidearm, its number of grenades, one knife |
| FR-BOT-450 — A shot's numbers are the weapon's (specs/10-fr-bot.md, deferred) | damage, range, time between shots and magazine come from the weapon fired, not the archetype |
| INV-BOT-040 — A primary weapon outreaches and outhits the sidearm beside it (specs/40-invariants.md, deferred) | over the configuration: primary above sidearm in range and damage, and only those two |
| FR-BOT-460 — Each weapon that reaches is an action of its own (specs/10-fr-bot.md, deferred) | every weapon with ammunition whose range covers the target is scored separately |
| FR-BOT-470 — A thrown grenade flies no further than its throw and waits out its fuse (specs/10-fr-bot.md, deferred) | throw range and fuse time |
| FR-BOT-480 — An explosion strikes every body within its blast (specs/10-fr-bot.md, deferred) | every bot and every part of the snake in the radius, thrower and squadmates included |
| FR-BOT-490 — An explosion that covers more of the snake hurts it more (specs/10-fr-bot.md, deferred) | a share per part beyond the first, dealt once |
| FR-BOT-500 — A bot does not throw where it would catch a squadmate (specs/10-fr-bot.md, deferred) | the rule of FR-BOT-410 — A bot does not fire through a squadmate (specs/10-fr-bot.md, implemented), for a blast |
| FR-BOT-510 — A knife strikes what is within its reach (specs/10-fr-bot.md, deferred) | contact damage, no line of fire asked for |
| FR-BOT-520 — A thrown knife leaves the bot (specs/10-fr-bot.md, deferred) | spent by the throw, hit or miss |
| FR-VIEW-340 — A bot holds the weapon it is using (specs/10-fr-view.md, deferred) | in the hands what it uses, the rest stowed where they are carried |

And one requirement returns: IF-BOT-010 — Bot and match configuration (specs/20-interfaces.md, partial) went to `partial` on 2026-10-11 because its statement now names a weapon catalogue and the arms per archetype, and the build reads neither. The first pass below puts it back to `implemented`.

## What is already there to build on

**The round does not care where its damage came from.** `Sources/CrawlCall/Bot/Round.swift` holds `let damage: Double`, set once at creation — "the damage per shot of the shooter's weapon". Only one line reads the archetype for it, `Execution.swift:131`. So the migration of FR-BOT-450 is far smaller than a count of mentions suggests.

Measure it before starting:

```
grep -rn "weaponDamage" Sources Tests    # 6 mentions in 5 files on 2026-10-11
grep -rn "magazine"     Sources Tests    # 25 mentions in 12 files
```

`magazine` is the wider of the two because reloading, the empty-magazine term, the interrupt on running dry and several tests all read it. None of them needs to know *which* weapon is empty until FR-BOT-460 lands, which is why that requirement comes after FR-BOT-450 and not with it.

**The deliberation already scores an action per situation**, and `Action` is a plain enum with associated values (`Sources/CrawlCall/Bot/Action.swift`). Adding a weapon to `.fire` and adding `.throwGrenade` and `.strike` is the shape the file already has.

**Flight is built.** `Sources/CrawlCall/Bot/Flight.swift` follows a round from where it left to what it meets, with `roundSpeed` and `roundRange` in the configuration; FR-BOT-405 — A round stops at what it meets (specs/10-fr-bot.md, implemented) answers what stops it. A thrown grenade is a slower thing on a different path, and what it meets on the way is the same question already answered.

**The figure is data.** `Sources/CrawlCall/View/Figure.swift` describes each bot's parts, where they stand and what they are painted with, and `Tests/CrawlCallTests/FigureTests.swift` reads that description. FR-VIEW-340 is therefore a `T` and not a `D`: a test can assert which weapon is in the hands.

## The passes, in order

Three passes, each one finished — suite green, build on the phone, loop closed — before the next begins. Under ART-030 of `specs/constitution.md`, amended 2026-10-11, the suite runs when a change is finished and the build goes on the phone when one is connected, neither asked for nor waited for.

### Pass 1 — The catalogue and the two firearms

Build FR-BOT-440, FR-BOT-450, INV-BOT-040, FR-BOT-460, and return IF-BOT-010 to `implemented`.

**The configuration first.** `config/bot.json` gains a catalogue of weapons, each with its own numbers, and each archetype names which it takes. Damage and magazine leave the archetype's entry; run speed, health and detection range stay, because they belong to the body and not to what it holds (ADR-0075).

The shipped numbers are tuning and the maintainer's to feel out on the phone, but which weapon goes to whom is settled.
ADR-0022 said what each archetype is drawn carrying — the assault a short automatic across the chest, the heavy a thick tube on the shoulder, the sapper a sledgehammer held upright, the sniper a long rifle held out in front, and the scout and the medic a pistol at the side — and two of those six could not survive a model where the pistol is everyone's sidearm. The maintainer settled them on 2026-10-11: **the scout carries an automatic rifle, the medic a submachine gun.** Both now have a primary that is a firearm, and INV-BOT-040 reads over them without strain.

| Archetype | Primary | Where it came from |
|---|---|---|
| Assault | a short automatic | ADR-0022 |
| Heavy | the shoulder weapon | ADR-0022 |
| Sapper | **open** — see below | — |
| Scout | an automatic rifle | the maintainer, 2026-10-11 |
| Sniper | a long rifle | ADR-0022 |
| Medic | a submachine gun | the maintainer, 2026-10-11 |

**The sapper is the one still open.** Its sledgehammer reaches no further than an arm, which no primary may do under INV-BOT-040 and under the maintainer's own words that the primary has the better range and damage. The reading that costs least: the sledgehammer is not the sapper's primary but its wrecking tool, the thing FR-BOT-070 — Heavy and sapper weapons destroy cover (specs/10-fr-bot.md, deferred) gives it for taking walls apart, and it carries a firearm like everyone else. That is a proposal, not a decision — settle it with the maintainer before the table ships and record the answer in this pass's ADR.

ADR-0022's figure table is rewritten in pass 3 with the new weapons in it; this plan does not edit that record, since what it decided on 2026-09-24 is what it decided.

**The invariant is a test over the file, not over the code.** INV-BOT-040 asserts that for every archetype the primary outranges and outdamages the sidearm. It costs one test and it catches a shipped table nothing else would notice. Range and damage only: a sidearm may fire faster and hold more, which is the trade the maintainer asked for.

**FR-BOT-460 is where the deliberation changes.** Each weapon that has ammunition and reaches becomes its own scored action, so the maximum still decides and the personality weights still reach the choice of weapon. A rule — the primary where it reaches, the sidearm otherwise — is explicitly refused in ADR-0075: it would be a second decision procedure beside the one the whole layer is built on.

**Watch the balance.** Two firearms means two fire terms where there was one, and the highest of them competes with cover and flight exactly as the single one did. ADR-0074 is the precedent: when courage was added as a multiplier, `attack` was raised from 1.0 to 2.0 so that the middle case was unchanged, and the suite proved the rebalance load-bearing by turning `testHealthMovesTheChoice` red without it. Expect the same kind of correction here, and expect the suite to find it.

**Negation for this pass:** remove the sidearm from a bot's arms and confirm a test goes red that asserts a bot with an empty primary and a close target still fires.

### Pass 2 — The grenade

Build FR-BOT-470, FR-BOT-480, FR-BOT-490, FR-BOT-500.

**This is the pass with real new mechanics**: a thrown thing with a fuse, damage over a volume, and a restraint on where it may be thrown.

The decision table FR-BOT-480 and FR-BOT-500 need, written before the code:

| In the blast | What happens |
|---|---|
| an enemy bot | takes the damage |
| a squadmate the thrower can see | takes the damage — and the throw is refused before it happens (FR-BOT-500) |
| a squadmate the thrower cannot see | takes the damage; the throw is not refused, because a bot acts on what it knows (FR-BOT-220 — A bot acts on what it knows (specs/10-fr-bot.md, partial)) |
| the thrower | takes the damage; no rule refuses it, because its own score already does |
| one part of the snake | the grenade's damage, once |
| several parts of the snake | the damage raised by the per-part share for each beyond the first, dealt once |
| a destructible module | **nothing yet — see below** |

**The cover half cannot be built in this pass.** FR-BOT-070 — Heavy and sapper weapons destroy cover (specs/10-fr-bot.md, deferred) was widened on 2026-10-11 so that a grenade's blast deals destruction damage, and it depends on FR-MAP-030 — Destructible modules have three states (specs/10-fr-map.md, deferred), which is not built and is a piece of the MAP area with its own size. So the grenade damages bodies now and walls when destruction exists. **Say this in the report rather than letting FR-BOT-070 look forgotten.**

**FR-BOT-490's share is tuning** and goes in the bot configuration with the grenade's other numbers. The maintainer named 15 to 20 per cent per part beyond the first; at that rate a blast over five parts is worth about 1.6 to 1.8 blasts and never five, which is the whole point — length stays the player's trade and does not become the grenade's prize.

**The snake takes it as one wound.** FR-SNAKE-070 — Damage removes segments from the end (specs/10-fr-snake.md, implemented) is called once with the raised amount, not once per part covered. A test that calls it five times would pass a careless assertion and be wrong.

**Negation for this pass:** remove the per-part share and confirm the test that asserts a long snake under a blast loses more than a short one goes red.

### Pass 3 — The knife and the hands

Build FR-BOT-510, FR-BOT-520, FR-VIEW-340.

The knife is the smallest of the three weapons and the one with the clearest edges: no flight, no magazine, no line of fire, a reach measured in a bot's arm. FR-BOT-520 is one line of state and one decision — a thrown knife is gone for the match, nothing picks it up — and it is what makes the throw a choice rather than free extra range.

FR-VIEW-340 is the visible half of the whole plan: a bot holds what it is using and stows the rest — primary across the back, sidearm and knife at the belt, grenades at the belt or chest. ADR-0022's table of one carried thing per archetype is rewritten here, and FR-VIEW-070 — Archetype is readable from the silhouette (specs/10-fr-view.md, implemented) is not weakened: the archetype stays readable from what is in the hands or across the back, from the bot's size and from what it wears. Six silhouettes stay six.

**That claim is a `D` and belongs on the phone.** A test asserts which weapon the figure holds; whether a player can still tell six archetypes apart at the camera's distance is judged by eye, by the maintainer, on a device — and it is the one thing in this plan that can come back as "no".

## Close the loop

Each pass ends with it; the last one ends with all of it:

- statuses, `code` and `tests` in the same set of edits as the code, and every file named there saying so back with `file implements:` / `file verifies:`;
- the requirements into E-090 — The squads (arch/00-elements.md, built) and FR-VIEW-340 into the part that holds the figure — this project writes `requirements` by hand, and AGENTS.md makes that part of closing the loop;
- `python3 srs-dd/tools/srs_check.py`, `srs_arch.py`, `srs_grounds.py`, read whole and not by the last line;
- FR-BOT-080 to `implemented` when the last pass lands — **this is the point of the plan**, and nothing else is holding it;
- IF-BOT-010 back to `implemented` at the end of pass 1.

## Risks, named

**The balance is the risk, not the mechanics.** Four weapons on a bot is four more actions competing in one utility sum, and the squads' behaviour is something the maintainer judges by eye on the phone. Expect to re-tune `attack` and the threat terms, expect the suite to catch the regressions, and expect at least one round of "they now shoot too much" from the device.

**A grenade that hits its own squad is correct and will look wrong.** FR-BOT-500 keeps a bot from throwing at a squadmate it sees; nothing keeps it from throwing at one it does not. That is deliberate (FR-BOT-220) and it will produce occasional friendly fire that reads as a bug. It is in ADR-0075 and it should be in the report too.

**FR-BOT-070 stays deferred after this plan.** Destruction is a MAP-area piece and is not in scope here.

**The figure may lose its readability, and the settled table makes that likelier.** A bot that holds a different thing depending on what it is doing is a bot whose silhouette changes within a match — and with the assault on a short automatic and the scout now on an automatic rifle, two of the six are holding weapons of the same family. The headgear still separates them (a round helmet against a peaked cap) and so does the body, but the weapon is no longer doing the work it did for those two. FR-VIEW-070 is `implemented` and judged by eye; if the maintainer says the six are no longer distinct, the answer is a change to the figures — a longer barrel, a different stance — not a retreat from FR-VIEW-340.

## What this plan deliberately leaves out

- Anything in `the-commanders.md`. The two are independent.
- Posture — Q-340 in `specs/91-open-issues.md` — which names grenades (a lying bot throws none) and needs accuracy, eye height and a facing direction before any of it is writable.
- The numbers behind the weapons, and which sidearms exist. Which weapon each class carries is settled in pass 1 above, except the sapper's; the damage, range, cadence and magazine behind each are tuning in `config/bot.json`, no requirement names a weapon, and they are the maintainer's to feel out on the phone.
