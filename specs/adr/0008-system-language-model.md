# ADR-0008 — The system language model first; a custom model only if measured necessary

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** FR-CMD-020, FR-CMD-140, NFR-PERF-030, NFR-PERF-080

## Context and problem statement

Commanders and speech need an on-device language model, called from the game process, on a phone whose thermal budget is the one risk a prototype cannot show.

## Considered options

1. The system Foundation Model (AFM 3 Core, 3B) through guided generation.
2. A custom small model shipped with the app through Core AI.

## Decision outcome

Option 1 to start.
It spends none of the app's memory budget and adds nothing to the download; the call is an ordinary `await` in the same Swift function as the game logic, with no bridge between runtimes.
Option 2 only if the system model fails the measurements — commander latency (NFR-PERF-040), frame impact (NFR-PERF-030), sustained performance (NFR-PERF-050).

### Consequences

Guided generation gives the structured commander output IF-CMD-020 asks for without parsing free text.
The model's behaviour is Apple's to change between OS versions; the pre-written line set (IF-CMD-030) is the fallback when generation is off for thermal reasons or filtered.
