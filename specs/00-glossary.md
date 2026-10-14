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
| **snake** | The player's avatar: a head the player steers over the map's walkable surfaces and a tail that follows the head's path as a spline. It has no ranged weapon. |
| **segment** | A unit of the snake's tail. Growth adds segments; damage removes them from the end. Abilities are attached to segments. |
| **navigation graph** | The bots' model of the map, derived from the map grid: one node per walkable cell and floor, edges between neighbours and along floor transitions. Cells carry passability and cost; the tail and destruction change them (ADR-0016). RealityKit's navigation mesh is not used. |
| **vertical transition** | A way between floors: a flight of stairs (FR-MAP-150), a drop from a ledge, or a way straight up that a map's `transition` line declares and no map uses now (Q-330). For the bots an edge of the graph; for the snake, ground it climbs or falls down. |
| **eating** | The act by which the snake consumes a bot, alive or dead. It takes time, during which the snake is exposed. Eating — not killing — is what scores. |
| **shedding** | The act by which the snake bites off the segment at the end of its own tail, trading an ability and length for being harder to see. Like eating it takes time and holds the snake still; the input that starts it is the *shed intent*, the time it takes the *shedding duration*, and the piece removed a *severed segment*. Proposed 2026-09-22 and still `draft` (FR-SNAKE-230). |
| **live prey** | A bot eaten while alive. Resists, takes longer, scores more than a body. |
| **body** | A dead bot left on the map. Squads do not remove bodies; only the snake does. |
| **ability** | A power the snake gains by eating a bot of a given archetype. Attached to one segment, single-use, lost with the segment. Abilities never shoot. |
| **squad** | One of the two bot teams. Both share the same six archetypes; they differ by colour and commander. |
| **archetype** | One of six bot roles — assault, heavy, sapper, scout, sniper, medic — binding a silhouette, base personality weights and the ability the snake gains from eating it. |
| **commander** | The LLM-driven layer of a squad: every 5–10 s it receives a compressed world state and returns threat priority, an order, roles and personality weights. One per squad. |
| **personality weights** | Per-bot multipliers from the bot's archetype — aggression, courage, discipline, greed, panic, self-sacrifice — that enter the utility formula. The commander no longer sets them and reaches them only through the order its squad is under. |
| **deliberation** | The utility-AI layer: scores every possible action of one bot and picks the maximum. Runs on the deliberation period of the bot configuration (FR-BOT-150), with a priority queue and interrupts (FR-BOT-160, FR-BOT-170). |
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
| **baseline device** | The iPhone 15 Pro — the oldest iPhone that runs the system language model, and the device every performance number is measured on (ADR-0015). |
| **configuration** | A file read at start that carries tuning numbers: the *snake*, *bot*, *match*, *scoring*, *tuning* (destruction and maps), *speech* and *view* configurations, each an `IF-*` requirement, and each setting's own, such as Greenholm's (IF-GREENHOLM-010). JSON, one file per interface under `config/`, a setting's under `config/setting/` (ADR-0012, ADR-0031). |
| **trap width / trap length** | The corridor width, and the snake length, at which a snake locks itself in (FR-MAP-080); both in the tuning configuration. Since 2026-09-30 the snake crawls over itself and cannot lock itself in, and the notion waits on Q-510. |
| **inspection distance** | How close a bot must come to a body to read its cause of death (FR-SCORE-120); in the scoring configuration. |
| **override distance** | How close the snake's head must be for a bot to treat it as the top threat regardless of orders (FR-BOT-120); in the bot configuration. |
| **module / kit** | A module is one placeable piece of map geometry with a declared type; a kit is the licensed set of modules a map is assembled from (FR-MAP-100). |
| **ground floor** | Floor 0: the one at ground level, on which a setting lays its ground; floors numbered below it are basements, above it upper floors (FR-MAP-170). |
| **spawn point** | A cell a map names, in its header, where the snake may be born; each match takes one at random (FR-MAP-180). |
| **permeability** | What a module stops, as its kit declares it: movement, sight, both or neither — a shrub stops sight, a tree both (FR-MAP-210, FR-MAP-220). |
| **setting** | The world a map stands in — the edge of its ground, drawn along the map's own outline and rounded (FR-MAP-200), what lies beyond it, and the backdrop above — named by the map (FR-MAP-120) and drawn as scenery. Each setting is a family of its own with a proper name, such as Greenholm, and its requirements form an area of that name; a setting's name is never one of the areas that divide the system by subject. |
| **scenery** | What a setting draws: seen, and nothing else — it takes no part in movement, sight, the navigation graph or what is cut open for the snake (FR-MAP-130). The arena is the map's modules; everything around it is scenery. |
| **attribution file** | The repository file listing every third-party asset with its source and licence (CON-PUB-030). |
| **speech event** | An occurrence the speech configuration names as worth a line — witnessing an eating, a squadmate vanishing, a truce proposed or broken, a body found (FR-CMD-140). |
| **cover** | Map geometry that blocks line of sight and fire — for and against everyone, snake included. |
| **round** | What a bot fires: it flies from the shooter's eyes at where the target was as it fired, at the round speed, and strikes the first living bot in its way, enemy or squadmate, or the snake, or stops at a wall or at its range (FR-BOT-060, FR-BOT-400, FR-BOT-405). Drawn in flight as a streak (FR-VIEW-170). |
| **pre-destructed cover** | Destruction as mesh states — intact → damaged → debris — switched by damage threshold, never simulated. Keeps the graph update to a cell and destruction predictable for the AI. |
| **load-bearing geometry** | Walls, stairs and floors that never break, because breaking them would break the navigation graph and with it the verticality. |
| **map specification** | The text file a map is authored in — an ASCII grid per floor — from which the tooling assembles modules, derives the navigation graph and runs the validator. |
| **debug mode** | The in-build viewer: free camera, navigation-graph overlay, disconnected zones and seams, teleport, snake-length slider, bot sight lines. |
| **vertical slice** | The five-stage plan in which each stage answers one question that can kill the project: hunting (1), verticality (2), two squads (3), commanders (4), voices (5). |
| **technical spike** | The 2–3 day check of the RealityKit 5 stack (ADR-0001, `materials/spike/README.md`): a steered snake with a `LowLevelMesh` tail over a ramp, a step and a drop; eight utility-AI entities on a real iPhone; one Foundation Models call beside rendering. It ran on 2026-09-22: all three passed, ruling out RealityKit's navmesh queries along the way (ADR-0016) and settling ADR-0001. |
| **thermal budget** | The limit set by iPhone throttling after 10–15 minutes of rendering plus on-device inference; the reason for 4v4, staggered commander phases and a degradation path. |
| **AFM** | Apple Foundation Models — the on-device system language model called through guided generation (`@Generable`). |
| **RCP** | Reality Composer Pro, the level editor. |
| **SRS-DD** | The specification framework this repository follows; `srs-dd/standard.md` is its standard. |
