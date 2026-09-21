# Bets

`B-NNN` — which requirement rests on which hypotheses.
The join lives here and only here: a requirement never says what it stands on, so the register says what stands on it, and the other direction is computed.

`all_of` is a chain — refute any one and the ground is gone.
`any_of` is a set of alternatives, and the strongest carries the requirement.
Two independent sets of alternatives are two bets naming the same requirement, and the checker asks whether that was deliberate.

### B-010 — Navmesh-bound movement stands on verticality mattering

```yaml
status: active
requirement: FR-SNAKE-010
all_of: [H-020]
```

The head being bound to the navigation mesh, vertical transitions included, is worth its cost only if multi-level maps change the hunt; a refuted H-020 puts the mesh binding and the tail spline that follows it up for removal.

**Rationale.** Concept §16.2 H2 names exactly this: "a refutation removes verticality, the spline on the navmesh, part of the map requirements".

