# Bot movement for Crawl Call: Chomp Company: research notes

**How to read this file.** It is research, not the specification: `specs/` binds, this does not (ART-020). It was prepared on 2026-09-25 by a research agent for a discussion with the maintainer, and is kept as it was delivered, so that the sources behind ADR-0032 can be followed. The maintainer's decisions the same day depart from it in four places, and where they differ ADR-0032 wins:

- **The map is not known in full.** The report assumes every bot knows the static layout. The maintainer decided that a bot starts knowing the map only roughly — the outline of the building, its floors, and roughly where the enemy squad is — and learns the rest by seeing it, remembering what it has seen; cells it has not seen are planned over as passable until seen otherwise.
- **Knowledge is shared within a squad after a delay** — one delay per squad — and stops being shared when the squad collapses; sharing when two bots meet in person may come later.
- **Nothing is forgotten by default**; forgetting the snake and the enemy is kept possible, not switched on. The report's decaying envelopes are one way to do it when it is.
- **The arena will grow.** The report's costs are for 768 cells; the maintainer asked for algorithms chosen for larger maps from the start. ADR-0032 says which of the report's choices hold at scale and which change.

Prepared 2026-09-25. The scope is the arena (about 12 × 8 m, two floors, 0.5 m cells, so at most 24 × 16 × 2 = 768 walkable nodes, fewer in practice), about 8 bots in two squads, a phone, a 0.5 ms per frame deliberation target, and four movement behaviours: hold/shoot, flee, take cover, and move by order.

## How sources were checked

**[V]** marks a claim I checked against the primary text during this research. For the Game AI Pro chapters, the Killzone slides and the F.E.A.R. paper, I downloaded the PDFs, extracted the text, and searched it.
**[S]** marks a claim that rests on a secondary description, such as an abstract, a search-engine summary, or another author citing the work. I did not read the primary text for these.
**[E]** marks my own estimate. It is not measured and not sourced.

The repository was read only for context: `Sources/CrawlCall/Map/NavigationGraph.swift`, `Sources/CrawlCall/Bot/Route.swift` and `Sources/CrawlCall/Bot/Perception.swift`. Here is what those files show. The graph is 4-connected and stored as `[Node: Set<Node>]`. `Route.between` runs a breadth-first search and sorts the neighbours at every expansion. Perception is a latched boolean, `knowsSnake`, with no position and no time attached. That last point matters most for section D.

---

## A. Path finding on a small grid/graph

### Options

**Breadth-first search (BFS) / Dijkstra, single source.**
This is a flood from one node that yields the distance to every node. On a uniform-cost graph BFS is Dijkstra, and it needs no priority queue.
Cost: O(N + E). With 768 nodes and 4-connectivity, E ≤ about 1,500 undirected edges. With flat arrays (node index = floor·W·H + z·W + x, a ring-buffer queue, a preallocated `Int16` distance array) that is a few thousand memory touches, which I estimate at single-digit to low tens of µs on an A-series core **[E]**.
Pitfall: hash-map/`Set`-based graphs and per-node `sorted()` allocate and hash at every step. I estimate that alone makes the flood about 10× slower **[E]**. This is worth measuring with the existing frame record before choosing anything cleverer.

**"Dijkstra map" / distance field / flow field.**
Run BFS once from the goal, or from a set of goals, and read the field from every agent. Patel: "Instead of running A* once per enemy, we can run an algorithm once, and it will calculate the path for all enemies", and the field is already there "as enemies get jostled around" **[V]**. Multiple goals are handled by seeding several sources at once, or by adding an extra node linked to them **[V]** (Patel, *Flow Field Pathfinding for Tower Defense*, 2014, https://www.redblobgames.com/pathfinding/tower-defense/).
Emerson's Supreme Commander 2 version splits the world into sectors, each with a cost field, an integration field and a flow field. The cost field holds 8-bit costs with 255 = wall. The whole scheme exists to move "hundreds to thousands of individual agents across massive maps" **[V]** (Elijah Emerson, *Crowd Pathfinding and Steering Using Flow Field Tiles*, Game AI Pro ch. 23, 2013, http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf).
The sector/portal/tile machinery is there for scale that this game does not have. The underlying idea of one flood read by many agents or queries is exactly right here.

**A\*.**
A\* is a directed search toward one goal with a heuristic (Patel, *Introduction to A\**, https://www.redblobgames.com/pathfinding/a-star/introduction.html). It beats BFS only when the goal is far and the map is large. On 768 nodes a full flood is already cheap. A\* also answers only one start→goal pair, while every behaviour below wants distances to many cells at once.
Patel on grid speed-ups: "I've not needed any of these optimizations in my own projects… Most of the time, the standard graph search algorithms are all you need" **[V]** (Patel, *Grid pathfinding optimizations*, 2014/2020, https://www.redblobgames.com/pathfinding/grids/algorithms.html).

**Jump Point Search (JPS) and JPS+.**
JPS is optimal on uniform-cost grids. It prunes symmetric paths and expands only "jump points" **[S]** (Harabor & Grastien, *Online Graph Pruning for Pathfinding on Grid Maps*, AAAI 2011, https://ojs.aaai.org/index.php/AAAI/article/view/7994).
JPS+ precomputes jump distances. Rabin & Silva report it "up to two orders of magnitude over traditional A*". It requires that "the map is static… preprocessed with eight numbers stored per grid cell… a uniform cost grid", and on maze-like maps the gain falls to about 2.5× over optimised A\* **[V]** (Steve Rabin & Fernando Silva, *JPS+: An Extreme A\* Speed Optimization for Static Uniform Cost Grids*, Game AI Pro 2 ch. 14, 2015, http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter14_JPS_Plus_An_Extreme_A_Star_Speed_Optimization_for_Static_Uniform_Cost_Grids.pdf).
Pitfalls: the classic form is 8-connected, while this graph is 4-connected on purpose (a 4-connected variant exists, arXiv 2501.14816 **[S]**). It does not accept tactical per-cell costs such as danger or exposure, because those break uniform cost. It gives point-to-point answers only.

**Canonical Dijkstra.**
This applies JPS ideas to a full flood on uniform grids **[V]** (Sturtevant & Rabin, *Faster Dijkstra Search on Uniform Cost Grids*, Game AI Pro 3 ch. 23, 2017, http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter23_Faster_Dijkstra_Search_on_Uniform_Cost_Grids.pdf). It is not needed at 768 nodes.

**Hierarchical (HPA\*).**
HPA\* abstracts the grid into clusters linked by entrances, searches the abstract graph, then refines the result. Paths come out near-optimal rather than optimal **[S]** (Botea, Müller & Schaeffer, *Near Optimal Hierarchical Path-Finding*, J. Game Development 1(1), 2004, https://webdocs.cs.ualberta.ca/~jonathan/publications/ai_publications/jogd.pdf).
Patel: "Having fewer nodes in the map representation is better for pathfinding speed. One way… is to have multiple levels of searching" **[V]** (Patel, *Map Representations*, http://theory.stanford.edu/~amitp/GameProgramming/MapRepresentations.html).
It pays off with thousands to millions of cells. At 768 nodes it only adds bookkeeping.

**Tactical costs.**
Killzone added costs to A\* links for "traversing a friendly line-of-fire" and "being under fire from one or more threats", which turns the shortest path into a tactical one **[V]** (Beij & Straatman, *Killzone's AI: Dynamic Procedural Tactics*, GDC Europe 2005 slides, https://www.guerrilla-games.com/media/News/Files/gdce05_killzone_ai.pdf).
The Last of Us did the same with an exposure bitmap: "we often used it as a cost in our navigation function… the path would minimize the NPC's exposure" **[V]** (Travis McIntosh, *Human Enemy AI in The Last of Us*, Game AI Pro 2 ch. 34, 2015, http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter34_Human_Enemy_AI_in_The_Last_of_Us.pdf).
With non-uniform costs, BFS becomes Dijkstra with a small bucket queue, because costs are small integers.

### Recommendation for A
Keep BFS/Dijkstra over flat arrays and do not adopt A\*, JPS or HPA\*. Make the flood the one primitive every behaviour uses: flood from the bot (reachability and steps), flood from the danger (flee, cover), and flood from the commanded zone (orders).
Rewrite the graph storage as an index-addressed array with a fixed neighbour list, up to 4 plus a stair link, and precompute it at map load. Remove the per-expansion `sorted()`; if a deterministic tie-break is needed, fix the neighbour order once at build time.
Where danger has to shape a path, add an integer cost per cell and switch to a bucket-queue Dijkstra.

---

## B. Target/position selection: cover and tactical points

### Options

**Tactical Point System (CryEngine TPS).**
A TPS query has three phases. Generation collects candidate points, from a static hidespot database or from points generated in rings or grids around a centre. Conditions are boolean filters. Weights score what is left. Queries are written as ordered "options": if the first option fails, the fallback is tried.
Example: `Generation = {hidespots_from_target_around_puppet = 15}, Conditions = {min_distance_from_puppet = 5, canReachBefore_the_target = true}, Weights = {softCover = -10, distance_from_puppet = -1.0}`.
Directional hidespots are rejected with "a dot-product test" against the hide-target, and hidespots around trees are "generated on the opposite side from the hide-target".
The evaluation-order rule: "Cheap filters first… Weights, to allow us to sort… Expensive filters, evaluating from highest scoring down, until a point passes". Raycasts are "always expensive" and should be limited per frame and run asynchronously.
A query failing is itself useful information: "failure indicates that there is no suitable location… we have run out of cover or our way is blocked". It can be written to a blackboard or passed to the squad.
Far Cry and Crysis kept hidespot claims so that no two agents picked the same spot. A chosen point is re-validated with a cheap single-point query.
**[V]** for all of the above (Matthew Jack, *Tactical Position Selection: An Architecture and Query Language*, Game AI Pro ch. 26, 2013, http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter26_Tactical_Position_Selection.pdf).
In the same chapter, Jack cites Killzone 3 pregenerating hidespots automatically [Mononen 11] and Brink generating all cover dynamically in concentric rings [Nelson 11] **[S]**.

**Unreal EQS.**
EQS has the same shape: Generators produce Items, Contexts give the frame of reference, and Tests filter or score. "Filter Tests are done before scoring Tests… so that fewer Items are returned and need to be scored" **[V]** (Epic Games, *Environment Query System Overview*, UE 5.8 documentation, https://dev.epicgames.com/documentation/en-us/unreal-engine/environment-query-system-overview-in-unreal-engine).

**The Last of Us "posts".**
The Last of Us precomputes cover posts from the collision mesh. Open posts are points around the player, used for instance "to check the player's last known location".
Candidates are "any cover spot facing away from the threat". For the 20 closest spots per NPC, up to 160 rays per frame are cast, 4 per spot. Pathfinds from each NPC to each viable post are limited to 20 per frame. Evaluation then runs on data gathered in earlier frames, through 17 script-defined "post selectors" whose criteria are normalised to 0–1.
**[V]** (McIntosh 2015, URL above).

**Rating cover against a threat direction without a line-of-sight test at run time: the Killzone lines-of-fire table.**
The slides say tactical decisions "involve hundreds of LoF checks" and "ray casts [are] typically expensive", so Killzone used "a small pre-computed look-up table… Pessimistic about cover… Polar representation". The compression: "For every waypoint, per radial sector, record the largest distance from where an attacker within that sector can fire at the waypoint. Inaccurate, but consistent." The whole table for 4,000 waypoints was 64 KB.
Positions were rated with a position evaluation function, a weighted sum of factors such as cover from other threats, partial cover from the primary threat, proximity and preferred fighting range.
**[V]** (Beij & Straatman, GDC Europe 2005 slides, URL above; the companion paper is Straatman, van der Sterren & Beij, *Killzone's AI: dynamic procedural combat tactics*, 2005, http://cse.unl.edu/~choueiry/Documents/straatman_remco_killzone_ai.pdf; I could not extract the paper's text, so it is **[S]**).
At run time, a cell c is covered from a remembered threat point t when `|t − c| > table[c][sector(t − c)]`. That is one subtraction, one atan2 or octant lookup, and one compare.

**Influence maps.**
An influence map is a grid of values radiated from agents with a falloff curve. Maps are combined by addition or multiplication. For line-of-sight threats "it is often enough to simply not propagate influence to locations that cannot be seen by the agent"; for movement threats, path distance ("a common solution is to precompute cell path-distances… using an undirected Dijkstra search"). Cell size should match "the minimum granularity that you would want characters to position at" **[V]** (Dave Mark, *Modular Tactical Influence Maps*, Game AI Pro 2 ch. 30, 2015, http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter30_Modular_Tactical_Influence_Maps.pdf).
The Last of Us exposure map is a bitmap of what an entity can see. It was computed from an 8-bit height map embedded in the navmesh, with rays cast in 360°, at about 2–3 ms of SPU time **[V]** (McIntosh 2015).

### Pitfalls
- Cover rated against the **true** snake position leaks information. Rate it against the bot's **remembered** snake points (section D). The Killzone table makes that as cheap as rating against the truth.
- The snake is a chain, not a point. The threat is the set of seen segments; "covered" should mean covered from all of them, or from the head plus the nearest seen segment.
- Two bots choosing the same cell leads to stacking and pushing. Keep a claim per cell, which Jack describes and which is legitimate within a squad.
- A cover cell the snake reaches first is a trap. Apply TPS's `canReachBefore` as a filter: steps from bot to cell × bot step time must be less than steps from danger to cell × snake step time, both read off floods.
- The 0.5 m grid and a partition's height: the table must be built with the same `Sight` test the game uses, including floor-to-floor and stair cases, or cover and perception will disagree.

### Recommendation for B
1. At map load, build a lines-of-fire table: for every walkable cell, 8 or 16 sectors, and a `UInt8` distance in 0.25 m units. That is 768 × 16 = about 12 KB. Build it by marching rays with the existing `Sight.isClear` from each cell outward per sector; this runs once and is off the frame budget.
2. The take-cover query is a TPS-style pipeline run on the bot's own data.
   - Generation: cells within k steps of the bot (from the bot's flood) that the bot can see or already knows. In practice the static map is known and the "own visibility" is about the snake, so the restriction can be steps plus visibility from the bot's eye as the designer asks.
   - Cheap filters: not claimed, not closer to danger than the bot, `canReachBefore`, covered from every remembered snake point (the table).
   - Weights: fewer steps, farther from danger, keeps line-of-fire to the snake if the bot wants to shoot from cover (a second table lookup in the other direction).
   - Fallback option: the flee behaviour.
3. On a query failure, write it to the squad blackboard, as Jack suggests.
4. Skip full influence maps for now. The flood from danger is the only map this scale needs. Add a squad proximity map only if bots crowd each other.

---

## C. Fleeing

### Options

**Naive flee (steering away from the threat).**
The bot moves along −(threat − self). It runs into walls and ends in corners. Fray's critique of steering behaviours, that the weighted sum of independent behaviours cancels out and the fix just "mov[es] the problem, at the cost of a new weighting parameter", is the general form of this failure **[V]** (Andrew Fray, *Context Steering: Behavior-Driven Steering at the Macro Scale*, Game AI Pro 2 ch. 18, 2015, http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter18_Context_Steering_Behavior-Driven_Steering_at_the_Macro_Scale.pdf).

**Sampled directions or candidate cells (what the designer described).**
Sample N directions, or the cells on the sight horizon. Reject the blocked ones and keep the one farthest from danger. This is cheap, but "farthest in straight line" is not "safest": the far point may be a dead-end room, or reachable only by running past the snake. The fix is to score by **path** distance and by what lies beyond the point, not by Euclidean distance.

**Dijkstra "flee map" (roguelike).**
"Start with a Dijkstra map calculated around goal points at the player's location… Multiply every value in the map by a negative number somewhere in the neighborhood of −1.2… pass it back through the Dijkstra scanning function." Monsters then "flee for the nearest door" and, "if cornered… try to sprint past the player and escape". Several desire maps are combined by weighted addition **[V]** (*The Incredible Power of Dijkstra Maps*, RogueBasin, http://www.roguebasin.com/index.php/The_Incredible_Power_of_Dijkstra_Maps; the page shows no author or date. It is commonly attributed to Brian Walker, author of Brogue, around 2010: **attribution unverified**).
Why it works: after the multiplication, cells far from danger are deep minima. The rescan (each cell = min(own, neighbour + 1)) makes a cell next to a deep region almost as attractive as the region itself. A corner is a shallow local pit, while a corridor leading to open space drains toward a deeper one, so descending the rescanned field prefers exits over corners. The coefficient below −1 decides how willing the agent is to pass closer to the danger in order to reach a better escape.
Cost: two floods.

**Context steering.**
Each behaviour writes an interest map and a danger map over a small ring of headings (slots). They are merged by per-slot max. Then: "find the lowest danger and mask out all slots that have higher danger… apply it to the interest map… pick the… highest remaining interest". Sub-slot interpolation gives continuous headings from few slots. The behaviours are "small and stateless" and can be run in parallel. In F1 2011 it replaced steering behaviours and "the codebase shrunk by 4000 lines" **[V]** (Fray 2015, URL above).
It is a local decision over the next heading. It does not look past the horizon: in the chapter the global guidance comes from the racing line, and against local traps it gives the entity "an idea of which way is closer to the racing line" **[V]**. I found no treatment of dead ends in the chapter.

**Flooding a predicted threat (Dishonored 2).**
"Heat" is seeded at the last known position and propagated a fixed number of steps per frame. A "barrier" stops it flooding backwards against the target's momentum **[V]** (Laurent Couvidou, *Flooding the Influence Map for Chase in Dishonored 2*, Game AI Pro Online Edition 2021 ch. 6, http://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter06_Flooding_the_Influence_Map_for_Chase_in_Dishonored_2.pdf).
The same flood serves as a "where the snake could be in t seconds" danger area.

### Dead ends and corners: the usual remedies
- Use path distance, not Euclidean distance (Dave Mark, as quoted in B, on threat "the path distance… could be used" **[V]**).
- Use the Walker rescan (above), which values a cell by the best region reachable from it.
- Filter on reach-before (TPS `canReachBefore` **[V]**): never pick a cell or a route the danger reaches first.
- Add an escape or mobility term: prefer candidates whose own onward neighbourhood keeps increasing the distance to danger. A cheap version is the number of cells within k steps of the candidate whose danger distance exceeds the candidate's **[E]**. This is my construction, not a sourced technique; it approximates the rescan in a bounded region.
- If cornered, switch behaviour: fight back, or pass the danger. The roguelike map does the latter by itself. F.E.A.R. gated its run-away action on "searching for a safe path through the NavMesh", and otherwise another action is used **[V]** (Jeff Orkin, *Three States and a Plan: The A.I. of F.E.A.R.*, GDC 2006, https://pages.cs.wisc.edu/~dyer/cs540/handouts/gdc2006_orkin_jeff_fear.pdf).

### Recommendation for C
Per flee decision, a few times a second:
1. Build d_danger: a multi-source BFS seeded from the bot's **remembered** snake cells (all seen segments, or those plus a short Dishonored-style flood for the possible advance).
2. Build d_bot: a BFS from the bot, bounded to the sight radius or R steps. This is the designer's "within the bot's own sight range where movement is possible". Optionally restrict it to cells visible from the bot.
3. Score the candidates on the horizon, meaning cells with d_bot ≤ R. Filters: `d_bot(c)·t_bot < d_danger(c)·t_snake` along the route, i.e. never pass through a cell the snake reaches first. Score: `d_danger(c)` plus an escape term. The escape term can come from Walker's rescanned flee map, restricted to the same bounded region; it costs one more bounded flood.
4. Walk the BFS parent chain to that cell and re-decide next tick.
All three are floods over at most 768 nodes. I estimate tens of µs per decision with array storage **[E]**.
Context steering is optional as the bottom layer for smooth movement between cells and avoiding other bots: 8–16 slots, with danger taken from the snake's segments and interest from the next path cell.

---

## D. Perception memory

### Options and what shipped games did

**Stimulus to track with a decaying envelope (Crytek Target Tracks).**
A stim carries a type, the source entity, a position or direction, and a radius. Vision is tested within view distance and FOV, then with "an asynchronous raycast… deferred raycasts is perfectly acceptable". Each agent keeps one Target Track per target, holding at most one envelope per event type. The track's value is the highest envelope, and the target is the track with the highest value.
The envelopes are ADSR. Attack rises to a peak; decay falls to a sustain fraction; sustain holds while the stim is valid; release lowers the value toward 0 "until it either reaches 0 or the stim becomes valid once more".
**[V]** (Rich Welsh, *Crytek's Target Tracks Perception System*, Game AI Pro ch. 31, 2013, http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter31_Crytek's_Target_Tracks_Perception_System.pdf).

**Last known position plus shared squad knowledge (The Last of Us).**
"The NPCs did not cheat with regard to knowing the player's location in most circumstances. When the player was perceived, the NPC would create an entity object with location and time stamp and then signal all other NPCs with the player's new location."
There is one designed cheat, for pacing: "If the player moved further than 5 m from where the NPCs thought he was… we forced an NPC to approach his position immediately". It cut the combat cycle from about 2 min to about 30 s.
Search uses a grid where "active cells would then bleed into their neighbors over time".
**[V]** (McIntosh 2015).

**Occupancy maps.**
A probability grid of where the target may be. It diffuses over time and is cleared where the agent looks **[S]** (Damián Isla, *Probabilistic Target Tracking and Search Using Occupancy Maps*, AI Game Programming Wisdom 3, 2006; table of contents https://catdir.loc.gov/catdir/toc/ecip067/2006003868.html; not read).

**Awareness as levels, separate from perception (Splinter Cell Blacklist).**
Blacklist separates perception from awareness: "awareness is a set of discreet mental states… reached progressively over time through sensory perception". Vision raycasts to 8 bones. Its Tactical Environment Awareness System (TEAS) splits the map into areas and choke points for search. Group behaviours carry the social awareness **[V]** (Martin Walsh, *Modeling Perception and Awareness in Tom Clancy's Splinter Cell Blacklist*, Game AI Pro 2 ch. 28, 2015, http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter28_Modeling_Perception_and_Awareness_in_Tom_Clancy's_Splinter_Cell_Blacklist.pdf).

**Working memory (F.E.A.R.).**
Knowledge is "centralized in shared working memory". An AI that finds an obstacle, "such as the blocked door… can record this knowledge in working memory, and take it into consideration when re-planning" **[V]** (Orkin 2006).
The per-fact confidence values often attributed to F.E.A.R. appear in Orkin's AIIDE 2005 paper *Agent Architecture Considerations for Real-Time Planning in Games* **[S], not checked**.

**Squad orders as goals (F.E.A.R.).**
"A.I. have goals to respond to orders, and it is up to the A.I. to prioritize following those orders versus satisfying other goals. For example, fleeing from danger may trump following an order to advance." The squad behaviour "does not need to analyze the map… each A.I. already" knows its valid cover **[V]** (Orkin 2006). This maps directly onto an LLM commander at 0.1–0.2 Hz.

**Mark of the Ninja.**
NPC awareness in a 2D stealth platformer is described in Brook Miles, *How to Catch a Ninja: NPC Awareness in a 2D Stealth Platformer*, Game AI Pro ch. 32, 2013, http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter32_How_to_Catch_a_Ninja_NPC_Awareness_in_a_2D_Stealth_Platformer.pdf **[S], not read**.

### Pitfalls
- A latched boolean ("knows the snake") cannot drive flee or cover. Both need a *where* and a *when*.
- Perfect squad sharing makes every bot omniscient once one bot sees the snake. The Last of Us chose this deliberately. If the designer's rule "only what the bot perceives" is strict, sharing should be a stimulus in its own right: a callout with a delay, lower confidence and a coarser position.
- Memory without decay produces bots that flee from a snake that left long ago. Memory that decays too fast produces bots that walk back into it.

### Recommendation for D
Replace the boolean with a small per-bot record.
- Up to K remembered snake points. K is 3–5, for example the head and the nearest seen segments. Each point holds its cell, a time stamp, the snake heading if seen, and a confidence with an ADSR-like release.
- Refresh on sight. Release over a few seconds. Optionally expand it into a bounded flood: after t seconds without a sighting, the danger seed is the set of cells within `speed·t` steps of the last known head, the Dishonored heat flood, capped at a few steps.
- Squad sharing, if the designer allows it: a callout stimulus with a delay and a lower peak.
- The commander, and later the LLM, gets the squad's union of these records, never the ground truth. Flee (C) and cover (B) read only this record.

---

## E. Horizon-limited movement toward a goal versus a global path

### The failure
An agent that picks, inside its visible or sensed region, the cell that looks closest to the goal is doing greedy local search. It stops in local minima: a U-shaped wall, a dead-end room, or a stair it cannot see beyond. The potential-field literature showed the general case. Local minima, where attraction and repulsion balance, are inherent, and Koren and Borenstein judged the method's shortcomings "considerable and probably unsolvable" for autonomous navigation **[S]** (Y. Koren & J. Borenstein, *Potential Field Methods and Their Inherent Limitations for Mobile Robot Navigation*, IEEE ICRA 1991, pp. 1398–1404, https://www.semanticscholar.org/paper/Potential-field-methods-and-their-inherent-for-Koren-Borenstein/07cc4371c8d3ddf7de0189f73227c3f0d896d66d).
Real-time heuristic search, which searches a limited horizon, commits to a move and repeats, has the same problem. It calls the traps "depressions" in the heuristic **[S]** (R. E. Korf, *Real-Time Heuristic Search*, Artificial Intelligence 42, 1990, pp. 189–211; C. Hernández & J. Baier, *Avoiding and Escaping Depressions in Real-Time Heuristic Search*, JAIR 2012, https://arxiv.org/abs/1401.5854).

### Usual remedies
1. **Learning (LRTA\*).** Raise the heuristic of each cell the agent leaves to 1 + the best neighbour's value. The agent eventually climbs out of a depression, but only after visibly pacing in it **[S]** (Korf 1990).
2. **Global guidance plus local choice.** Plan globally on the static map and let the local layer choose the actual step. The Last of Us: "the high-level system allows us to plan our overall route between distant points", with a local 2D grid around each character for "short but very good paths" **[V]** (McIntosh 2015). Fray's racing line plays the same role for context steering **[V]**.
3. **Distance-to-goal field as the heuristic.** If the local chooser scores horizon cells by `steps_from_bot(c) + d_goal(c)`, where d_goal is a BFS from the goal over the static map, the heuristic is exact and has no depressions. Greedy descent on an exact distance field cannot get stuck. Patel's flow-field argument is the sourced basis **[V]**. The claim that it removes local minima follows from d_goal being the true distance **[E, reasoning]**.
4. **Wall following / bug algorithms** (robotics). Guaranteed but ugly. Not recommended for visible game agents.

### The designer's rule does not exclude a global path
The rule constrains knowledge of the **snake**: what it sees and where it is. The arena's layout is static and not secret, and every sourced system above lets agents path over the full static map. So a global BFS from the commanded zone does not violate "use its own visible area". The visible area can still be where the bot chooses its next waypoint, scored with the global d_goal plus its own danger memory.

### Recommendation for E
- For each commander order, run **one BFS per squad from the ordered zone** (multi-source over the zone's cells) and keep it until the next order. At 0.1–0.2 Hz this is negligible.
- Each tick the bot chooses, among the cells in its visible horizon, the one that minimises `steps_from_bot + d_goal + w·danger(c)`, where danger comes from its own memory (C and D). It then walks there and repeats. This is "iterative, using its own visible area" with no dead ends.
- Orders are goals with a priority, as in F.E.A.R. Flee and cover may override them. A failed query or an unreachable zone goes back to the commander as information: the TPS failure-as-signal idea.
- Do not implement horizon-only movement with a Euclidean heuristic. If the designer insists on no global field, use LRTA\*-style learning per bot. That is 768 `Int16` values, and it will visibly pace in dead ends.

---

## Summary of recommended architecture (all floods over ≤ 768 array-indexed nodes)

| Need | Primitive | When computed | Knowledge used |
|---|---|---|---|
| Reachability, steps | BFS from bot, bounded to R | per decision | static map |
| Danger distance | multi-source BFS from remembered snake cells (+ small predicted flood) | per decision, or when memory changes | bot's own memory |
| Cover test | lines-of-fire table lookup | table at map load; lookup O(1) | static map + remembered snake points |
| Flee target | horizon cells scored on danger distance + escape term, reach-before filter; Walker rescan optional | per decision | own memory |
| Order movement | BFS from ordered zone | per order (0.1–0.2 Hz) per squad | static map + order |
| Local smoothing (optional) | context steering, 8–16 slots | per frame | local geometry, own memory |

The costs are estimates **[E]**. Up to three bounded floods per decision, times 8 bots, times 2–5 decisions per second, comes to at most about 120 floods per second. Spread across frames, that is roughly 2 floods per frame, well inside 0.5 ms with array storage. Measure it with the existing frame record before and after moving the graph off `Dictionary`/`Set`.

## Could not verify
- The Killzone 2005 paper text could not be extracted. The slides were used instead.
- Isla (AIGPW3 2006), Korf (1990), Koren & Borenstein (1991), Botea et al. (2004), Harabor & Grastien (2011), Orkin (AIIDE 2005), and Brook Miles (Game AI Pro 2013) rest on abstracts or secondary descriptions only.
- The author and date of the RogueBasin Dijkstra-maps article are not on the page.
- No cost figure here for this game is measured. They are all estimates.
