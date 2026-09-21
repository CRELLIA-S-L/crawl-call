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

Of five people handed the stage-1 build (one grey blockout, four utility-AI bots, no LLM) without explanation, at least two keep playing past the second minute and name something concrete they wanted to do next. Measured by watching the session and one question afterwards.

**Rationale.** Concept §13 stage 1, §16.2 H1. Threshold is the concept's "three of five quit before minute two" inverted into the register's grammar: the proportion who stay.

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
status: untested
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
status: untested
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
status: untested
class: III
population: playtesters of the stage-5 build
refuted_if: count < 1 at n >= 5
expires: 2028-03-31
owner: @alex_v
impact: the product's main selling argument (I-010)
```

At least one of five players, unprompted, replays a situation for the lines, quotes one aloud or retells one to somebody else. Observed and asked once after the session.

**Rationale.** Concept §13 stage 5, §16.2 H5.
