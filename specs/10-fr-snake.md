# Functional requirements — snake

Movement over the navigation mesh, the tail spline, growth, eating, abilities gained from prey.
Source: concept §4 (snake mechanics), §5 (abilities from eating).

### FR-SNAKE-010 — Head moves on the navigation mesh

```yaml
status: draft
verification: D
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
exempt: [unlinked]
created: 2026-09-21
```

While a match is running, the snake's head **shall** move only along the navigation mesh of the map, including its vertical transitions — stairs, descents and drops from ledges.

**Rationale.** The snake lives on the surface graph of the map, not in free space: it crawls over geometry.
Everything the tail does for free — blocking corridors and stairs, becoming a liability in narrow passages, vertical play in both directions — follows from the head being bound to the mesh.
Free flight was never on the table.
