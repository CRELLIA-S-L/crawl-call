# Hypotheses — product

`H-110`–`H-130` — whether the game is a product (concept §16.3).
Kept apart from the mechanics so that the register does not close on one event at the end.
Thresholds and dates here are placeholders set before any instrument exists; they are revised before the first measurement, never after.

### H-110 — People will buy this game

```yaml
status: untested
class: I
population: visitors of the store page and the demo, first release
refuted_if: proportion < 0.02 at n >= 1000
expires: 2028-12-31
owner: @alex_v
impact: the paid build as a business; the open-source showcase survives a refutation
```

At least two in a hundred demo players buy the paid build within the first release window. Measured by store conversion.

**Rationale.** Concept §16.3 P1. Threshold is a placeholder for the maintainer to set.

### H-120 — "Snake + shooter" is understood without explanation

```yaml
status: untested
class: III
population: people shown the one-line description and the trailer, before installing
refuted_if: proportion < 0.50 at n >= 20
expires: 2028-06-30
owner: @alex_v
impact: the pitch and the store listing; a refutation means the game needs a tutorial before the first bite
```

At least half of people shown the description and trailer can say what the player does in the game. Asked in one open question.

**Rationale.** Concept §16.3 P2.

### H-130 — Openness brings an audience, not only forks

```yaml
status: untested
class: I
population: the public repository in its first year
refuted_if: count < 5 at n >= 1
expires: 2028-06-30
owner: @alex_v
impact: the reason to publish source at all beyond the SRS-DD showcase
```

Within a year of the repository going public, at least five issues or builds come from people other than the maintainer. Counted from GitHub.

**Rationale.** Concept §16.3 P3.
