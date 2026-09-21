# Glossary

Terms used across the specification.
Contains no requirements.

## Binding force of the verbs

The lexicon in `srs-config.json` admits `shall`, `must`, `should` and `may`.
The convention of this project:

| Verb | Force | Use |
|---|---|---|
| **shall** | mandatory | the one form this project writes; a violation is a defect |
| **must** | mandatory | admitted by the lexicon as a synonym of **shall**; not written in new requirements |
| **should** | recommended | a deviation is justified in review |
| **may** | allowed | permitted, never required |

## Terms

| Term | Meaning |
|---|---|
| **snake** | The player's avatar: a head that moves on the navigation mesh and a tail that follows the head's path as a spline. It has no ranged weapon. |
| **segment** | A unit of the snake's tail. Growth adds segments; damage removes them from the end. Abilities are attached to segments. |
| **navigation mesh (navmesh)** | The walkable-surface graph of a map. Both the snake's head and the bots move on it; it is the ground truth for "where one can be". |
| **vertical transition** | A navmesh edge that changes level: stairs, a descent, a drop from a ledge. |
| **eating** | The act by which the snake consumes a bot, alive or dead. It takes time, during which the snake is exposed. Eating — not killing — is what scores. |
| **live prey** | A bot eaten while alive. Resists, takes longer, scores more than a body. |
| **body** | A dead bot left on the map. Squads do not remove bodies; only the snake does. |
| **ability** | A power the snake gains by eating a bot of a given archetype. Attached to one segment, single-use, lost with the segment. Abilities never shoot. |
| **squad** | One of the two bot teams. Both share the same six archetypes; they differ by colour and commander. |
| **archetype** | One of six bot roles — assault, heavy, sapper, scout, sniper, medic — binding a silhouette, base personality weights and the ability the snake gains from eating it. |
| **commander** | The LLM-driven layer of a squad: every 5–10 s it receives a compressed world state and returns threat priority, an order, roles and personality weights. One per squad. |
| **personality weights** | Per-bot multipliers set by the commander — aggression, discipline, panic, self-sacrifice — that enter the utility formula. The commander's only channel into per-frame behaviour. |
| **deliberation** | The utility-AI layer: scores every possible action of one bot and picks the maximum. Runs at ~7 Hz on a time-based budget with a priority queue and interrupts. |
| **execution** | The per-frame layer: aiming, movement, animation, collisions. Runs for every bot on every frame; never throttled. |
| **interrupt** | An event that gives a bot a deliberation slot immediately: took damage, snake in view within threshold, ally died in view, magazine empty, own cover destroyed, saw an eating or a snake-marked body, new order. |
| **witnessing** | Whether a living bot had line of sight to the eating within a window of 2–3 s, including one who reached the spot right after. Determines the stealth level of an eating. |
| **stealth level** | *Open* — own squad saw; *hidden* — own squad did not; *perfect* — no squad saw. |
| **awareness scale** | A squad's state about the snake as the commander receives it: *calm* (everything explained), *alarm* (people vanish without trace), *confirmed* (a witness or a snake-marked body). |
| **balance of power** | The relative strength of the two squads. The scoring axis that rewards eating from the leading squad; the strategic reason to keep the war going. |
| **truce** | A commander's proposal to the enemy squad to hold fire while the snake lives; fragile by construction. In the data model from the start, enabled after stage 4. |
| **squad collapse** | What happens when the bot holding the commander role is eaten: coordination ends, the last known weights stay, panic rises, any truce lapses. |
| **role-holder** | The bot of a squad that currently holds the commander role (FR-BOT-040). Eating or killing it collapses the squad. |
| **deliberation slot** | One turn of the utility-AI layer for one bot. Handed out on a fixed step, by priority, within a per-frame budget; an interrupt grants one at once. |
| **baseline device** | The oldest iPhone that runs iOS 27 — the device every performance number is measured on (see Q-150). |
| **configuration** | A file read at start that carries tuning numbers: the *snake*, *bot*, *match*, *scoring*, *tuning* (destruction and maps), *speech* and *view* configurations, each an `IF-*` requirement. Their spelling is Q-130. |
| **trap width / trap length** | The corridor width, and the snake length, at which a snake locks itself in (FR-MAP-080); both in the tuning configuration. |
| **inspection distance** | How close a bot must come to a body to read its cause of death (FR-SCORE-120); in the scoring configuration. |
| **override distance** | How close the snake's head must be for a bot to treat it as the top threat regardless of orders (FR-BOT-120); in the bot configuration. |
| **module / kit** | A module is one placeable piece of map geometry with a declared type; a kit is the licensed set of modules a map is assembled from (FR-MAP-100). |
| **attribution file** | The repository file listing every third-party asset with its source and licence (CON-PUB-030). |
| **speech event** | An occurrence the speech configuration names as worth a line — witnessing an eating, a squadmate vanishing, a truce proposed or broken, a body found (FR-CMD-140). |
| **cover** | Map geometry that blocks line of sight and fire — for and against everyone, snake included. |
| **pre-destructed cover** | Destruction as mesh states — intact → damaged → debris — switched by damage threshold, never simulated. Keeps the navmesh rebuild cheap and destruction predictable for the AI. |
| **load-bearing geometry** | Walls, stairs and floors that never break, because breaking them would break the navmesh and with it the verticality. |
| **map specification** | The text file a map is authored in — an ASCII grid per floor — from which the tooling assembles modules, builds the navmesh and runs the validator. |
| **debug mode** | The in-build viewer: free camera, navmesh overlay, disconnected zones and seams, teleport, snake-length slider, bot sight lines. |
| **vertical slice** | The five-stage plan in which each stage answers one question that can kill the project: hunting (1), verticality (2), two squads (3), commanders (4), voices (5). |
| **technical spike** | The unrun 2–3 day check of the RealityKit 5 stack: tail spline on a navmesh with a vertical transition; eight utility-AI entities on a real iPhone; one Foundation Models call beside rendering. |
| **thermal budget** | The limit set by iPhone throttling after 10–15 minutes of rendering plus on-device inference; the reason for 4v4, staggered commander phases and a degradation path. |
| **AFM** | Apple Foundation Models — the on-device system language model called through guided generation (`@Generable`). |
| **RCP** | Reality Composer Pro, the level editor. |
| **SRS-DD** | The specification framework this repository follows; `specs/README.md` is its standard. |
