# Non-functional requirements

`NFR-*` — responsiveness, resource limits, privacy, reliability.
Every statement still needs a measurable bound: “within 200 ms”, not “fast”.

Source: concept §15 (thermal budget), §9.2 (time-based scheduling), the technical spike in the preamble, the maintainer's decision of 2026-09-21 on the frame rate.
**Baseline device**: the oldest iPhone that runs iOS 27.
Every number below is measured on it, in a 4v4 match, on the device and never in the simulator (concept §15).

## Frame time

### NFR-PERF-010 — 60 frames per second on the baseline device

```yaml
status: draft
verification: A
derives_from: []
depends_on: [FR-BOT-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a 4v4 match is running on the baseline device, the system **shall** render at least 60 frames per second over any one-second window, cold.

**Rationale.** The concept sets no target; the maintainer chose 60 on 2026-09-21 because the concept's 0.5 ms deliberation budget was sized for it and because the reference games' readability depends on smooth motion.
"Cold" — the first five minutes — separates this from the thermal requirement NFR-PERF-050.

### NFR-PERF-020 — Deliberation costs at most 0.5 ms per frame

```yaml
status: draft
verification: T
derives_from: [NFR-PERF-010]
depends_on: [FR-BOT-150, FR-BOT-160]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

In any frame, the system **shall** hand out deliberation slots only while the frame's deliberation time is under 0.5 ms and the slot count is under the per-frame maximum of the bot configuration, deferring the rest to later frames.

**Rationale.** Concept §9.2: a budget — as many bots as fit in ~0.5 ms or up to N — and graceful degradation under overload rather than a frame drop.

### NFR-PERF-030 — A commander inference does not break the frame budget

```yaml
status: draft
verification: A
derives_from: [NFR-PERF-010]
depends_on: [FR-CMD-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a commander inference is running, the system **shall** keep every frame under the 16.6 ms budget of NFR-PERF-010.

**Rationale.** The third check of the technical spike: does the frame dip during inference.
If it does, the stack decision ADR-0001 falls with it.

### NFR-PERF-040 — Commander answers within its interval

```yaml
status: draft
verification: A
derives_from: []
depends_on: [FR-CMD-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When a commander is called, the system **shall** have its response applied before the next call to the same commander is due.

**Rationale.** A response that arrives after the next call describes a world that is gone.
The bound is the interval itself rather than a number so that stretching the interval under load (NFR-PERF-060) keeps the requirement true.

## Thermal budget

### NFR-PERF-050 — Sustained performance over a long session

```yaml
status: draft
verification: A
derives_from: [NFR-PERF-010]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a 4v4 match on the baseline device runs for 20 minutes, the system **shall** keep the frame rate at or above 60 frames per second over every one-second window of the session.

**Rationale.** Concept §15: the one risk invisible on a prototype — after 10–15 minutes iOS throttles, and both frame rate and model latency sag.
Twenty minutes is past the onset the concept names; the test is always on a real device and never on five minutes.

### NFR-PERF-055 — Commander latency holds over a long session

```yaml
status: draft
verification: A
derives_from: [NFR-PERF-040]
depends_on: [NFR-PERF-050]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

While a 4v4 match on the baseline device runs for 20 minutes, the system **shall** keep every commander response within NFR-PERF-040 throughout the session.

**Rationale.** Concept §15: throttling sags both the frame rate and the model's response time; two quantities, two measurements, two requirements.

### NFR-PERF-060 — Under thermal pressure the commander interval stretches

```yaml
status: draft
verification: T
derives_from: [NFR-PERF-050]
depends_on: [FR-CMD-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the device reports a thermal state at or above the degradation threshold of the match configuration, the system **shall** multiply both commanders' intervals by the degradation factor of the same configuration until the state falls below the threshold.

**Rationale.** Concept §15: under overheating the commanders' interval stretches, for both.

### NFR-PERF-070 — Under thermal pressure speech falls back to pre-written lines

```yaml
status: draft
verification: T
derives_from: [NFR-PERF-050]
depends_on: [FR-CMD-140]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

When the device reports a thermal state at or above the degradation threshold of the match configuration, the system **shall** serve speech events from the pre-written line set instead of generating lines until the state falls below the threshold.

**Rationale.** Concept §15: lines switch to a pre-generated set under overheating.
The same pre-written set is the fallback of the content filter (FR-CMD-160), so one set serves both.

## Memory

### NFR-PERF-080 — The language model costs the app no memory or download size

```yaml
status: draft
verification: I
derives_from: []
depends_on: [FR-CMD-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The system **shall** use a language model that is provided by the operating system, counted neither against the application's memory budget nor in its download size.

**Rationale.** Concept §10: start on the system model — it spends no app memory and adds nothing to the distribution; a custom model only if measurements force it (ADR-0008).
