# Hypotheses — mechanics

`H-010`–`H-050` — the five questions of the vertical slice (concept §13, §16.2), as early checks: class III, a playtest the maintainer watches.
Each stage of the slice answers one of them; a refutation is meant to stop the work before the next stage is built on it.
Release-time re-checks (retention, telemetry by floor, review mentions) are separate hypotheses, written when the instrument that measures them exists.

### H-010 — Hunting armed prey is fun on its own

```yaml
status: untested
class: III
population: first-time players of the stage-1 build, given no instructions
refuted_if: proportion < 0.40 at n >= 5
expires: 2027-06-30
owner: @alex_v
impact: the whole project; nothing downstream survives a refutation
```

Of five people handed the stage-1 build (one grey blockout of two floors joined by a stair, two squads of four utility-AI bots, no LLM) without explanation, at least two keep playing past the second minute and name something concrete they wanted to do next. Measured by watching the session and one question afterwards.

**Rationale.** Concept §13 stage 1, §16.2 H1. Threshold is the concept's "three of five quit before minute two" inverted into the register's grammar: the proportion who stay.
The build carries two squads of four where the concept's stage 1 describes four bots, and the description is brought to what was built rather than the build to the description: the second squad was needed to place the first at a distance from it, no damage passes between bots yet, and both squads are prey exactly as one would be.
What the second squad is *for* — two sides fighting each other while the snake waits — is stage 3 and is not what this measures.

### H-020 — Multi-level maps change the hunt, not decorate it

```yaml
status: assumed
class: III
population: the same playtesters, on a flat and a multi-level build of the same map
refuted_if: count < 1 at n >= 5
expires: 2027-06-30
owner: @alex_v
impact: verticality, the tail spline on the navmesh and the multi-level map requirements
```

At least one of five players, describing the game afterwards without a leading question, mentions height, floors or routes. Counted from free descriptions.

**Rationale.** Concept §13 stage 2, §16.2 H2.

### H-030 — Watching someone else's fight beats chasing

```yaml
status: assumed
class: III
population: playtesters of the stage-3 build (two squads, archetypes, abilities, destruction)
refuted_if: count < 1 at n >= 5
expires: 2027-09-30
owner: @alex_v
impact: the second squad, bodies, witnessing and the awareness scale — the most expensive layer
```

At least one of five players, unprompted, spends part of a session waiting and choosing a moment instead of chasing the nearest bot. Observed from session recordings: waiting time versus pursuit time.

**Rationale.** Concept §13 stage 3, §16.2 H3.

### H-040 — An LLM commander makes a difference the player can see

```yaml
status: assumed
class: II
population: playtesters shown two stage-4 builds blind — commander on, commander off
refuted_if: proportion <= 0.50 at n >= 10
expires: 2027-12-31
owner: @alex_v
impact: all LLM tactics; a refutation leaves utility AI alone and is a saving, not a loss
```

More than half of players correctly identify which build had the commander. Blind A/B with the order randomised; a guess at chance level refutes.

**Rationale.** Concept §13 stage 4, §16.2 H4 — named there as the most likely to fall, and the refutation worth publishing.

### H-050 — Bot lines are worth replaying for

```yaml
status: assumed
class: III
population: playtesters of the stage-5 build
refuted_if: count < 1 at n >= 5
expires: 2028-03-31
owner: @alex_v
impact: the product's main selling argument (I-010)
```

At least one of five players, unprompted, replays a situation for the lines, quotes one aloud or retells one to somebody else. Observed and asked once after the session.

**Rationale.** Concept §13 stage 5, §16.2 H5.

### H-070 — Players trade length for concealment

```yaml
status: assumed
class: III
population: playtesters of the stage-2 build, given no instructions
refuted_if: proportion < 0.40 at n >= 5
expires: 2027-06-30
owner: @alex_v
impact: the tail-shedding requirements (FR-SNAKE-230, FR-SNAKE-240, FR-SNAKE-250) and the shed intent they add to IF-VIEW-010
```

At least two of five players deliberately bite off the tail at least once — deliberately meaning the act is followed by play rather than by a visible attempt to undo it, and the player, asked afterwards, gives a reason of their own. Observed during the session and asked once at the end, without naming the mechanic first.

**Rationale.** The mechanic exists to sell a trade: FR-BOT-050 notices the snake when any segment enters a bot's view, so a long tail is exposure, while FR-SNAKE-080 makes every segment shed a concrete ability given up.
A trade nobody takes is a rule nobody needs, and the cheapest way to find that out is five people and a build with cover in it.
Stage 2 rather than stage 1 because the trade only has a buyer where height and cover exist (H-020).
Threshold, owner and date set by the maintainer on 2026-09-22.

### H-080 — A severed tail piece left in the arena earns its keep

```yaml
status: untested
class: III
population: playtesters of a stage-2 build in which a severed segment stays as an obstacle
refuted_if: proportion < 0.40 at n >= 5
expires: 2027-06-30
owner: @alex_v
impact: whether the shed piece persists — a placeable barrier layer, or FR-SNAKE-250 as written
```

At least two of five players either bite off the tail in order to place a barrier — closing a corridor, splitting a squad, walling off a body — or take cover behind a piece already lying there. Either one counts, and the two need not be the same players: observed during the session, the intent confirmed by asking afterwards.

**Rationale.** The tail blocks bots while attached (FR-SNAKE-040), so a piece that stayed would be a barrier the player places at will — a layer with its own questions about decay, count and how bots treat it, and too large to adopt on an argument.
It is the open question of 2026-09-22 turned into a measurement: FR-SNAKE-250 holds the small version until five people say the large one is worth building.
Testing it needs a throwaway variant build in which the piece persists, which is the price of the answer.
Owner, date and what counts as evidence set by the maintainer on 2026-09-22 — either behaviour counts, and the two groups of players need not overlap.
The threshold is carried over from H-070 rather than chosen for this claim; it holds until the maintainer sets one of their own, and a reading taken against a borrowed threshold says so when it is recorded.
