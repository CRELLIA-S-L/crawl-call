# ADR-0017 — The model speaks in the comedy register, and one list says what a line may contain

- **Status:** accepted
- **Date:** 2026-09-22
- **Related requirements:** IF-CMD-040, IF-CMD-050, IF-CMD-060, FR-CMD-140, FR-CMD-160, FR-CMD-165, CON-CMD-020

## Context and problem statement

The instructions sent to the on-device model decide what the bots sound like, and the spike showed they decide more than tone.
Two ten-minute unattended runs on the iPhone 16 Pro, same arena, same route, same schedule (`spike/README.md`):

| | military register | comedy register |
|---|---|---|
| calls attempted / answered / refused | 63 / 62 / 1 (guardrail) | 60 / 54 / 6 (refusal) |
| latency avg / max | 2.31 / 2.75 s | 3.00 / 4.57 s |
| lines naming a soldier | 0 of 63 | 55 of 55 |
| lines with blame or panic | 0 | 19 |
| line length avg / max | 42 / 57 chars | 97 / 235 chars |

The runs were half a minute apart, so the second began on a warm device: it reported `fair` from its third minute while the first stayed `nominal` throughout.
The latency row is therefore not a clean comparison — part of that second is throttling — while the content rows and the refusal counts are not thermal quantities and stand.

The military register produced sixty-three restatements of "Snake at flank — advance": no names, no panic, nothing anyone would replay (H-050).
The comedy register produced what the concept describes — "Davis: 'The snake's eating us! Pike, blame the other crew!'" — at the cost of four times the refusals, longer latency, and lines that ran to six speakers when one shout was asked for.

Two further facts from the same runs: the model refuses a share of calls about this game's own subject whatever the register (`guardrailViolation` under the default guardrails, `refusal` under `permissiveContentTransformations`), and a failed call poisons the session's transcript — after one refusal every one of the next eighty-four calls failed, to the end of that run, because the refused exchange stayed in the session.

## Considered options

1. Leave the instructions to the implementation, as prompt text is not behaviour.
2. Specify what the instructions must establish, and keep the allowed and forbidden content of a line in one list that both the instructions and the filter read.
3. Specify the prompt text itself in the specification.

## Decision outcome

Option 2, at the maintainer's request.
The register is not a matter of taste: it is what F-030 ("the war stays comedy") and ADR-0002 already decided, it is measurably what makes the lines worth hearing, and the vocabulary it forbids is most of what makes the model refuse.
So the specification says what the instructions must establish (IF-CMD-040 for the commander, IF-CMD-050 for speech) and what a line may and may not contain (IF-CMD-060), while the words themselves stay in configuration and code.

One list rather than two: the instructions tell the model what never to produce, and the filter rejects it if it does anyway (FR-CMD-160).
Two lists would drift, and the drift would show as lines that pass the filter but were never meant to exist, or lines the filter kills every time.

Option 3 was rejected because a prompt is tuned against a model version: the text would be stale by the first OS update, and a specification that goes stale teaches everyone to ignore it.

### Consequences

The register decides the vocabulary, so it decides the refusal rate: CON-CMD-020 records that refusals are normal and bounded, and FR-CMD-165 makes a refused generation fall back to a pre-written line — which turns the set of IF-CMD-030 from a thermal fallback into the game's ordinary second voice.
The line shape is part of the contract now (IF-CMD-020): a speaker and one short line, not a scene.
The numbers above are the baseline any future prompt change is measured against, by the same unattended run.
