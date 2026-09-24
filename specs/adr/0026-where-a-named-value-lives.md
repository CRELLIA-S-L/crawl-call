# ADR-0026 — A named value is the language's own name first, then a constant under Config/ by kind; configuration holds what shapes play and picture

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, IF-MAP-010, FR-TOOL-020

## Context and problem statement

ART-070 gives every number and string in the game's code a name, 0, 1 and −1 included, and names two homes: the configuration under `config/` for a value that is tuned, and a named constant under `Sources/CrawlCall/Config/` for a value the design fixes.
On 2026-09-24 the maintainer asked for the code to be brought to it in one pass rather than as changes touch it; the choices below were made within that pass.
The code held about 450 numbers and 110 strings outside the configuration and the drawn models (Q-280), most of them in geometry — halves, the three axes, the ends of a segment, tolerances — and in the names the scene's parts are found by.
Three choices are not made by the article: what counts as a name, how the constants are grouped, and where "tuned" ends.

## Considered options

1. Constants for everything, the identities included — a `zero`, a `one` of the project's own.
2. The standard library's own names where it has one, constants of the project's own for the rest.

For the grouping: one file of constants; a file per subsystem; a file per kind of value.

For the line between the two homes: by whether a requirement names the value; by whether a person adjusts it by playing or watching; by whether it could change without a rebuild.

## Decision outcome

Option 2, a file per kind of value, and by whether a person adjusts it by playing or watching.
Swift already names most of the identities, and its names say more than a constant of ours would: `.zero` for an additive start or a size that must be exceeded, `direction.indices` for the three axes of a vector, `SIMD3<Double>.scalarCount` for "three numbers", `floors.indices.last` for the index just appended, `size.min() > .zero` for "every side has length".
What Swift does not name is named by what it means in this code — `Geometry.half`, `MapGrid.neighbourStep`, `MapFormat.firstLine` — never by its value.
A file per kind of value keeps a name next to the others of its kind, where a reader of a format or of the arithmetic looks for it; a file per subsystem would put the map's text format and its geometry in one place, and one file for everything would be the whole game's numbers in one list.

### How it works

`Sources/CrawlCall/Config/` holds, besides the configurations and their schema:

| File | Holds |
|---|---|
| `ErrorIdentifier.swift` | the kinds of error (ADR-0025) |
| `TextKey.swift` | the keys of the player's text (ADR-0024) |
| `DebugText.swift` | text only the debug build shows |
| `SymbolName.swift` | the SF Symbols the interface draws |
| `Resource.swift` | the bundle's directories, extensions and file names, and the paths built from them |
| `EntityName.swift` | the names the scene's entities are given and found by |
| `MapFormat.swift` | the map file's words, separators and positions (`MapFormat`), and the grid's numbers (`MapGrid`) |
| `Geometry.swift` | halves, the ends of a segment, the sides of a box, and the tolerances of comparison |

Further subsystems add files of their own kind as the pass reaches them; each file claims, with `implements:`, the requirements whose code uses its values.

A value goes to the configuration under `config/` when it shapes how the game plays or what the picture shows and a person sets it by playing or by looking — a speed, a distance, a duration, a threshold, the camera's framing, the light; its key is described in the interface requirement for that file (ADR-0012).
It is a constant under `Config/` when the arithmetic, a format or a unit fixes it, when it guards the arithmetic — a tolerance —, or when it is part of how the interface is drawn rather than of the world it shows.
The text of an error stays where the error is raised; a path it names is built by `Resource`, so that the message and the lookup cannot name different files.
The literals that declare names stay: a constant's value, a key in a schema, a case's raw value.

It stops working where a name says the value rather than the meaning — `two`, `threeNumbers` — which is the magic number with a label on it; reading the diff is the only check.
It also stops where one constant serves two meanings that happen to share a value; they are two constants, even when equal.

### Consequences

Changes to the arithmetic keep results bit for bit: a division by two became a multiplication by `Geometry.half`, which IEEE 754 computes exactly alike, and the suite passed unchanged.
A value moved into configuration adds a key to its file and a phrase to its interface requirement in the same change.
Tests stay outside ART-070 and state their expected numbers themselves, which is what makes them a check on the code rather than a copy of it.
