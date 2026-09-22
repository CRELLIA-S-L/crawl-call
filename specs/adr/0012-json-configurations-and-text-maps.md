# ADR-0012 — Configurations are JSON, one file per interface; a map is a text file with a grid per floor

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** IF-SNAKE-010, IF-BOT-010, IF-SCORE-010, IF-MAP-010, IF-MAP-020, IF-CMD-030, IF-VIEW-020, FR-TOOL-010

## Context and problem statement

The interface requirements say what each configuration file carries and not how it is spelled (Q-130).
The files are read by Swift in the game and by Python in the map tools, edited by hand as tuning, and diffed in git.

## Considered options

1. JSON — standard library on both sides, diff-friendly, no comments.
2. YAML or TOML — comments, but a dependency in Swift and in the Python tools (ART-040 forbids one for the tooling).
3. A property list — Apple-native, unreadable in a diff, foreign to the Python side.
4. Swift source constants — a rebuild per tuning change, which concept §11.2 explicitly wants to avoid.

For the map: a plain-text file with per-floor character grids, as concept §11.2 describes, versus embedding the grid in JSON.

## Decision outcome

**JSON**, one file per interface, under `config/`: `snake.json`, `bot.json`, `match.json`, `scoring.json`, `tuning.json`, `speech.json`, `view.json`.
Keys are the noun phrases the interface requirements use, in lower camel case; a file with an unknown key is rejected at load, so that a typo in a tuning name is an error and not a silently ignored number.
The lack of comments is paid for by keeping the meaning of every key in the interface requirement, which is where it already is.

**A map is a UTF-8 text file** with a header naming the kit and the floor transitions, followed by one character grid per floor.
The grid stays a grid rather than JSON because the concept's whole method is a human sketching in ASCII and an agent editing it by coordinates; a grid inside a JSON string loses the alignment that makes it readable.
Which character means which module is the kit's legend, in `legend.json` beside the kit's modules, so that a map and the kit it names cannot disagree.

### Consequences

The map tool (FR-TOOL-010) parses the header, the grids and the kit's legend; the validator (FR-TOOL-040) checks a map against the legend of the kit it names.
Configuration paths are relative to the application bundle in the game and to the repository root in the tools.
A future editor may write these files; nothing here requires that it be a human.
