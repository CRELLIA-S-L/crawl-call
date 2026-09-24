# ADR-0025 — Error kinds are cases of one enum, and an error's line is written once for all of them

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** FR-TOOL-200

## Context and problem statement

FR-TOOL-200 asks every error and log line to open with the identifier of its kind, unique across the game, then a colon, a space and the message; ART-070 asks the identifiers to be declared once, in a catalogue under `Sources/CrawlCall/Config/`.
The game has five error types — `ConfigurationError`, `SchemaError`, `Kit.KitError`, `MapLoadError`, `MapParseError` — each an enum whose cases are its kinds, and each wrote its own `description`.
One path reported an error that was not the game's own: `Launch.world` let the system's error from reading the map file through, and the launch screen printed it as it came.

## Considered options

1. One `ErrorIdentifier` enum for the whole game, its raw values the identifiers; a protocol that writes the line from an identifier and the details.
2. An identifier enum per error type, each type writing its own line.
3. String constants in a namespace, one per kind.

## Decision outcome

Option 1.
Raw values of one enum are unique by construction — the compiler rejects a second case with the same string — so "unique across the game" is kept by the language rather than by a test, which options 2 and 3 would both need.
Writing the line in one place is what keeps the format from drifting: under option 2 five `description`s would each spell out the colon and the space.
The system's error from reading a map is wrapped in a kind of the game's own, `MAP_UNREADABLE`, carrying the system's error in its details.

### How it works

`ErrorIdentifier` in `Config/ErrorIdentifier.swift` is the catalogue: one case per kind, grouped by where the kind arises, raw value in upper case joined by underscores.
An error type conforms to `IdentifiedError` by naming, per case, its `identifier` and its `details` — what happened, written for a person where the error is raised.
The protocol's extension supplies `description` as the identifier's raw value, `ErrorLine.separator` and the details; an error type does not write `description` itself.
Invariants: every kind in the catalogue is raised by some error type, and no two kinds share an identifier — `ErrorIdentifierTests` holds both, over one error of every kind.
It stops working where an error type declares its own `description`, which overrides the protocol's; the test's check of every line's opening is what catches that, and it was seen to fail when one did.
An error nested in another — a schema error inside `CONFIG_BAD_SHAPE` — keeps its own identifier inside the outer line's details, so the line names both kinds, outer first.

### Consequences

A new kind of error is a case in the catalogue and a case in its error type; the test fails until the list of every kind it checks has learnt it.
Nothing writes log lines yet; when something does, it opens with an identifier from the same catalogue.
