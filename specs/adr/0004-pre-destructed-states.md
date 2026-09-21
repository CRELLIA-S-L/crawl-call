# ADR-0004 — Destruction is pre-authored states, not physics

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-MAP-030, FR-MAP-040, FR-MAP-050, FR-MAP-060, INV-MAP-010, INV-MAP-020

## Context and problem statement

Cover is broken by bots and by the snake's body, and the navigation mesh has to follow every change, on a phone.

## Considered options

1. Physical simulation of fracture.
2. Pre-destructed states — intact, damaged, debris — three meshes per module, switched by damage threshold.

## Decision outcome

Option 2.
The navmesh must be rebuilt on every geometry change, and real physics makes that unaffordable on a phone; pre-destruction is deterministic, so the bots can take it into account when planning (FR-BOT-100).

### Consequences

What can break is declared per module type (FR-MAP-060); load-bearing walls, stairs and floor slabs never do (INV-MAP-010), or the navmesh and the verticality go with them.
Thresholds, damage per source, ammunition and the snake's weight live in configuration (IF-MAP-020) and are tuned on the prototype against the risk of a map turned to wasteland by mid-match.
