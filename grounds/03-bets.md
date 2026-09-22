# Bets

`B-NNN` — which requirement rests on which hypotheses.
The join lives here and only here: a requirement never says what it stands on, so the register says what stands on it, and the other direction is computed.

`all_of` is a chain — refute any one and the ground is gone.
`any_of` is a set of alternatives, and the strongest carries the requirement.
Two independent sets of alternatives are two bets naming the same requirement, and the checker asks whether that was deliberate.

### B-010 — Surface-bound movement stands on verticality mattering

```yaml
status: active
requirement: FR-SNAKE-010
all_of: [H-020]
```

The head being bound to the map's surfaces, vertical transitions included, is worth its cost only if multi-level maps change the hunt; a refuted H-020 puts the surface binding and the tail spline that follows it up for removal.

**Rationale.** Concept §16.2 H2 names exactly this: "a refutation removes verticality, the spline on the navmesh, part of the map requirements".

### B-020 — FR-SNAKE-020 stands on verticality mattering

```yaml
status: active
requirement: FR-SNAKE-020
all_of: [H-020]
```

FR-SNAKE-020 — Tail follows the head's path — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-030 — FR-SNAKE-040 stands on verticality mattering

```yaml
status: active
requirement: FR-SNAKE-040
all_of: [H-020]
```

FR-SNAKE-040 — Tail blocks bots — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-040 — FR-SNAKE-050 stands on verticality mattering

```yaml
status: active
requirement: FR-SNAKE-050
all_of: [H-020]
```

FR-SNAKE-050 — Tail blocks the snake's own head — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-050 — FR-BOT-110 stands on verticality mattering

```yaml
status: active
requirement: FR-BOT-110
all_of: [H-020]
```

FR-BOT-110 — Height advantage enters position scoring — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-060 — FR-MAP-010 stands on verticality mattering

```yaml
status: active
requirement: FR-MAP-010
all_of: [H-020]
```

FR-MAP-010 — A map has more than one floor — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-070 — FR-MAP-070 stands on verticality mattering

```yaml
status: active
requirement: FR-MAP-070
all_of: [H-020]
```

FR-MAP-070 — Stairs the snake can block — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-080 — FR-MAP-080 stands on verticality mattering

```yaml
status: active
requirement: FR-MAP-080
all_of: [H-020]
```

FR-MAP-080 — Trap corridors — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-090 — FR-MAP-090 stands on verticality mattering

```yaml
status: active
requirement: FR-MAP-090
all_of: [H-020]
```

FR-MAP-090 — Every reachable surface is continuous for the tail — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-100 — INV-MAP-020 stands on verticality mattering

```yaml
status: active
requirement: INV-MAP-020
all_of: [H-020]
```

INV-MAP-020 — Destruction never disconnects floors — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-110 — FR-BOT-020 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-BOT-020
all_of: [H-030]
```

FR-BOT-020 — Two squads at war — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-120 — FR-BOT-180 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-BOT-180
all_of: [H-030]
```

FR-BOT-180 — Calm squads do not hunt the snake — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-130 — FR-BOT-190 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-BOT-190
all_of: [H-030]
```

FR-BOT-190 — Alarmed squads keep together — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-140 — FR-SCORE-030 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-030
all_of: [H-030]
```

FR-SCORE-030 — Stealth multiplier by who saw — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-150 — FR-SCORE-040 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-040
all_of: [H-030]
```

FR-SCORE-040 — The leading squad is the one with more living bots — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-160 — FR-SCORE-050 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-050
all_of: [H-030]
```

FR-SCORE-050 — Balance multiplier for prey from the leading squad — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-170 — FR-SCORE-070 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-070
all_of: [H-030]
```

FR-SCORE-070 — A witness is a bot with line of sight during the window — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-180 — FR-SCORE-080 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-080
all_of: [H-030]
```

FR-SCORE-080 — Arriving right after counts as witnessing — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-190 — FR-SCORE-090 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-090
all_of: [H-030]
```

FR-SCORE-090 — A witness reports after a delay — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-200 — FR-SCORE-100 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-100
all_of: [H-030]
```

FR-SCORE-100 — A consumed witness never reports — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-210 — FR-SCORE-110 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-110
all_of: [H-030]
```

FR-SCORE-110 — A body carries its cause of death — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-220 — FR-SCORE-120 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-120
all_of: [H-030]
```

FR-SCORE-120 — Finding a body is one thing, inspecting it another — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-230 — FR-SCORE-125 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-125
all_of: [H-030]
```

FR-SCORE-125 — A vanished body raises the alarm — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-240 — FR-SCORE-130 stands on watching a fight beating the chase

```yaml
status: active
requirement: FR-SCORE-130
all_of: [H-030]
```

FR-SCORE-130 — Each squad has an awareness state — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-250 — INV-BOT-020 stands on watching a fight beating the chase

```yaml
status: active
requirement: INV-BOT-020
all_of: [H-030]
```

INV-BOT-020 — Squads never remove bodies — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-260 — INV-BOT-030 stands on watching a fight beating the chase

```yaml
status: active
requirement: INV-BOT-030
all_of: [H-030]
```

INV-BOT-030 — Both squads share one archetype set — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-270 — IF-SCORE-010 stands on watching a fight beating the chase

```yaml
status: active
requirement: IF-SCORE-010
all_of: [H-030]
```

IF-SCORE-010 — Scoring configuration — is worth building only if H-030 holds.

**Rationale.** Concept §16.2 H3: a refutation removes the second squad, bodies, witnesses and the awareness scale — the most expensive layer.

### B-280 — FR-CMD-010 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-010
all_of: [H-040]
```

FR-CMD-010 — One commander per squad — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-290 — FR-CMD-020 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-020
all_of: [H-040]
```

FR-CMD-020 — The commander is called on an interval — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-300 — FR-CMD-030 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-030
all_of: [H-040]
```

FR-CMD-030 — The commander sets the threat priority — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-310 — FR-CMD-040 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-040
all_of: [H-040]
```

FR-CMD-040 — The commander issues an order — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-320 — FR-CMD-050 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-050
all_of: [H-040]
```

FR-CMD-050 — The commander assigns roles — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-330 — FR-CMD-060 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-060
all_of: [H-040]
```

FR-CMD-060 — The commander sets personality weights — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-340 — FR-CMD-070 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-070
all_of: [H-040]
```

FR-CMD-070 — Awareness gates what the commander is told — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-350 — FR-CMD-080 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-080
all_of: [H-040]
```

FR-CMD-080 — The two commanders run out of phase — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-360 — FR-CMD-090 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-090
all_of: [H-040]
```

FR-CMD-090 — A commander may propose a truce — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-370 — FR-CMD-100 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-100
all_of: [H-040]
```

FR-CMD-100 — A truce takes effect on acceptance — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-380 — FR-CMD-110 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-110
all_of: [H-040]
```

FR-CMD-110 — A truce is fragile — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-390 — FR-CMD-120 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-120
all_of: [H-040]
```

FR-CMD-120 — Losing the role-holder ends coordination — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-400 — FR-CMD-130 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-130
all_of: [H-040]
```

FR-CMD-130 — Collapsed bots keep their last weights, with more panic — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-410 — IF-CMD-010 stands on the commander making a visible difference

```yaml
status: active
requirement: IF-CMD-010
all_of: [H-040]
```

IF-CMD-010 — Commander input — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-420 — IF-CMD-020 stands on the commander making a visible difference

```yaml
status: active
requirement: IF-CMD-020
all_of: [H-040]
```

IF-CMD-020 — Commander output — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-430 — NFR-PERF-030 stands on the commander making a visible difference

```yaml
status: active
requirement: NFR-PERF-030
all_of: [H-040]
```

NFR-PERF-030 — A commander inference does not break the frame budget — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-440 — NFR-PERF-040 stands on the commander making a visible difference

```yaml
status: active
requirement: NFR-PERF-040
all_of: [H-040]
```

NFR-PERF-040 — Commander answers within its interval — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-450 — NFR-PERF-060 stands on the commander making a visible difference

```yaml
status: active
requirement: NFR-PERF-060
all_of: [H-040]
```

NFR-PERF-060 — Under thermal pressure the commander interval stretches — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-460 — FR-CMD-140 stands on bot lines being worth replaying for

```yaml
status: active
requirement: FR-CMD-140
all_of: [H-050]
```

FR-CMD-140 — Bots speak on events — is worth building only if H-050 holds.

**Rationale.** Concept §16.2 H5: a refutation removes the product's main selling argument.

### B-470 — FR-CMD-150 stands on bot lines being worth replaying for

```yaml
status: active
requirement: FR-CMD-150
all_of: [H-050]
```

FR-CMD-150 — Speech is rate-limited and queued — is worth building only if H-050 holds.

**Rationale.** Concept §16.2 H5: a refutation removes the product's main selling argument.

### B-480 — FR-CMD-160 stands on bot lines being worth replaying for

```yaml
status: active
requirement: FR-CMD-160
all_of: [H-050]
```

FR-CMD-160 — Every line passes a content filter — is worth building only if H-050 holds.

**Rationale.** Concept §16.2 H5: a refutation removes the product's main selling argument.

### B-490 — IF-CMD-030 stands on bot lines being worth replaying for

```yaml
status: active
requirement: IF-CMD-030
all_of: [H-050]
```

IF-CMD-030 — Speech configuration — is worth building only if H-050 holds.

**Rationale.** Concept §16.2 H5: a refutation removes the product's main selling argument.

### B-500 — NFR-PERF-070 stands on bot lines being worth replaying for

```yaml
status: active
requirement: NFR-PERF-070
all_of: [H-050]
```

NFR-PERF-070 — Under thermal pressure speech falls back to pre-written lines — is worth building only if H-050 holds.

**Rationale.** Concept §16.2 H5: a refutation removes the product's main selling argument.

### B-510 — FR-BOT-115 stands on verticality mattering

```yaml
status: active
requirement: FR-BOT-115
all_of: [H-020]
```

FR-BOT-115 — Distance along the snake's path enters position scoring — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-520 — FR-CMD-105 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-105
all_of: [H-040]
```

FR-CMD-105 — A truce turns both squads on the snake — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-530 — FR-CMD-125 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-125
all_of: [H-040]
```

FR-CMD-125 — Losing the role-holder voids orders and roles — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-540 — NFR-PERF-055 stands on the commander making a visible difference

```yaml
status: active
requirement: NFR-PERF-055
all_of: [H-040]
```

NFR-PERF-055 — Commander latency holds over a long session — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-550 — FR-SNAKE-220 stands on verticality mattering

```yaml
status: active
requirement: FR-SNAKE-220
all_of: [H-020]
```

FR-SNAKE-220 — A drop is a path, not a fall — is worth building only if H-020 holds.

**Rationale.** Concept §16.2 H2: a refutation removes verticality, the spline on the navmesh and part of the map requirements.

### B-560 — FR-CMD-025 stands on the commander making a visible difference

```yaml
status: active
requirement: FR-CMD-025
all_of: [H-040]
```

FR-CMD-025 — The commander's session stays small and cached — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-570 — CON-CMD-010 stands on the commander making a visible difference

```yaml
status: active
requirement: CON-CMD-010
all_of: [H-040]
```

CON-CMD-010 — The system language model's context and cache — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-580 — IF-CMD-040 stands on the commander making a visible difference

```yaml
status: active
requirement: IF-CMD-040
all_of: [H-040]
```

IF-CMD-040 — Instructions for a commander's decision — is worth building only if H-040 holds.

**Rationale.** Concept §16.2 H4: a refutation removes all LLM tactics, leaving utility AI — a saving, not a loss.

### B-590 — IF-CMD-050 stands on bot lines being worth replaying for

```yaml
status: active
requirement: IF-CMD-050
all_of: [H-050]
```

IF-CMD-050 — Instructions for a bot's line — is worth building only if H-050 holds.

**Rationale.** Concept §16.2 H5: a refutation removes the product's main selling argument.

### B-600 — IF-CMD-060 stands on bot lines being worth replaying for

```yaml
status: active
requirement: IF-CMD-060
all_of: [H-050]
```

IF-CMD-060 — What a generated line may and may not contain — is worth building only if H-050 holds.

**Rationale.** Concept §16.2 H5: a refutation removes the product's main selling argument.

### B-610 — FR-CMD-165 stands on bot lines being worth replaying for

```yaml
status: active
requirement: FR-CMD-165
all_of: [H-050]
```

FR-CMD-165 — A refused generation falls back to a pre-written line — is worth building only if H-050 holds.

**Rationale.** Concept §16.2 H5: a refutation removes the product's main selling argument.

### B-620 — CON-CMD-020 stands on bot lines being worth replaying for

```yaml
status: active
requirement: CON-CMD-020
all_of: [H-050]
```

CON-CMD-020 — The model refuses a share of calls — is worth building only if H-050 holds.

**Rationale.** Concept §16.2 H5: a refutation removes the product's main selling argument.
