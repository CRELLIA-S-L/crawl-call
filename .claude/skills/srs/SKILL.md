---
name: srs
description: Working with the project specification (SRS in specs/). Invoke ALWAYS before any code change that alters behavior; when planning any task — including planning a feature, breaking a task into steps, or sequencing work across several requirements; when asked what the system should do; when investigating why something is built the way it is; when changing or cancelling a requirement. For a guided dialog that authors a brand-new requirement, prefer the srs-new skill. Not needed only for changes that do not touch behavior — typos, formatting, comments.
---

# Working with the specification

The rules of the format are in `specs/README.md`, by section, and are not restated here.
`python3 tools/srs_view.py --vocabulary` prints the words a block may use — statuses, fields, areas, modal verbs; open the standard for a rule, not for a word.
Statements, titles and rationales are written in the lexicon of `specs/srs-config.json`, whatever language this file is in.

## A question about the system

1. Read what the project says of itself: `specs/00-glossary.md`, `specs/01-introduction.md`, `specs/02-overview.md` — short, and in its own words. A lookup by number needs a number nobody has handed you; a search finds the word you guessed.
2. Narrow: `python3 tools/srs_view.py --areas`, then `python3 tools/srs_view.py --list --area <AREA>`, then `python3 tools/srs_view.py <ID>`, then `--code <path>`.
3. Where the specification does not say, name the rungs you walked — the area, the words, the paths. Where the question is undecided, `specs/91-open-issues.md` holds it; read an entry whole.

## Before changing code

1. `python3 tools/srs_view.py --code <path> --statements` — the requirements behind the file, from the `code` and `tests` fields and the file's own annotations, each with what it obliges; a directory works. Without the tool: `grep -rn "<path>" specs/*.md` and the table in `specs/90-traceability.md`, whose *Incoming links* section is every link in one place.
2. Read what the answer names: `python3 tools/srs_view.py <ID> --where` prints the lines of the `code` and `tests` files that carry the requirement, and `python3 tools/srs_view.py <ID> --where --source` prints the function or region under each — read those, in one call, before any file whole. A file the fields name that no line speaks for is printed as such, and is the one to open. A search over the repository is the fallback, taken out loud (`AGENTS.md`).
3. Found some: choose by the statements the ones the change will touch, and read those in full — `python3 tools/srs_view.py <ID>` resolves the links both ways — with what each `derives_from` and `depends_on`. Incoming links are the blast radius; the rest of the list is known by its statements and is not opened.
4. Found nothing: the behaviour is undescribed. Author a requirement first (`srs-new`); never code silently.
5. With a `grounds/` directory beside `specs/`: `python3 tools/srs_grounds.py --blast <path>` — what the requirements stand on. `refuted` or `expired` is not a stop; it is said, because the change inherits that ground. Procedure: `srs-bet`.
6. With an `arch/` directory: `grep -n <path> arch/90-map.md`, or the directory above it, since a directory in `carries` owns what is under it — the row names the element the file belongs to, what else it carries and the requirements it holds. A change that moves a responsibility between parts is said, not left for the checker. Procedure: `srs-arch`.
7. Report the lookup, not only its outcome — the paths given, the words searched. What you say about a file is read off the file in that report and re-read before sending. Connected prose; a list only for what the reader counts. Every record named to a person is cited at its first mention in the message, from `python3 tools/srs_view.py --cite <ID>…`.

## Two acts

Authoring ends at the written requirement; building it is a separate act, started deliberately, often by somebody else. This procedure is the second act; `srs-new` is the first. Sliding from one into the other leaves a specification that records only what shipped.

## Building a requirement

In from a file (above), or from an approved requirement nobody built: `python3 tools/srs_view.py --coverage`, `grep -n "status: deferred" specs/*.md`; read it with its links both ways.

1. The requirement still says what you are about to build. If not, you are authoring — stop, `srs-new`.
2. The plan names requirements, not work — "fix the storage layer" is not a step — each cited at first mention from `--cite`; constitution articles `ART-*` by number. The plan may not conflict with `specs/constitution.md`.
3. Code.
4. Name what you chose: where the requirement could have been met another way, the way taken goes to `specs/adr/` (*Workflow*, `specs/README.md`), or the report says none.
5. Close the loop, in the same set of edits: re-read every named statement against what was built; what it does not describe is written in or taken out. A reworded statement passes the judgement `srs-new` gives a new one, against the qualities `specs/README.md` requires of a statement, and the same lookup — what else speaks to it, what points at it, the `FR-DOC-*` sections that restate it — and the finding is said before the edit. Then status per Lifecycle, `code` and `tests` with real paths, and every file named there says so back with `implements:` / `verifies:` (Annotations, `specs/README.md`): the field is the specification's claim, the annotation is the file's.
6. `python3 tools/srs_check.py`, then the `srs-check` procedure: suites offered, inspections named.

A fix that adds what the statement is silent about means the statement is wrong. A change naming no requirement means either no behaviour moved or a requirement is missing.

## Withdrawing a requirement

`withdrawn` cancels with no successor; with one, it is `superseded` and the successor is named. Before the status changes:

1. `python3 tools/srs_view.py <ID>` — the incoming links, grouped by field: `depends_on` loses its meaning, `derives_from` its reason, `refines` the rule it sharpened, `conflicts_with` nothing.
2. Show the direct dependants in full, count what lies beyond; settle one level per decision (ADR-0013).
3. Settle each dependant with the maintainer — none is a default: do not withdraw; narrow; supersede; cascade, each dependant back through this section; re-parent; promote and reword; orphan deliberately, and say so; stage it — intent, dependants, withdrawal last.
4. Set the status and say why in the rationale, its only home. The number stays dead.

The checker reports what still stands on it — a guard, not a substitute.

## Planning multi-requirement work

1. Resolve the requirements in scope and their closure: `depends_on`, `derives_from`, `refines`, and the incoming links.
2. Behaviour with no covering requirement: the first steps author it (`srs-new`).
3. Order the steps by `depends_on`; each step cites its requirements (`--cite`), the articles that bind it ("per ART-040") and the verification method.
4. A `draft` in scope is a blocker, marked so (ART-020). A `superseded` one sends the plan to its successor; a `withdrawn` one is an error to surface.
5. The last two steps, always: close the loop; the checker and the `srs-check` procedure. A step that builds or tests is marked "requires the user's explicit confirmation each time" (ART-030).

The plan lives in the conversation, never in `specs/`; a plan is not approval — statuses are (ART-020).

## Also

- Prohibitions: *What not to do* in `specs/README.md`; and no builds or tests without the user's explicit confirmation (ART-030).
- What is put to the maintainer for a decision — a statement, a rewording, a step of a plan — is in the message that asks, as it would be written, never "as above".
- A mismatch between code and requirement: fix neither side; record it in `specs/91-open-issues.md` and tell the user. A finding ends in *therefore* — must be fixed; is deliberate, and why; needs the maintainer's decision, with the options. Without one it is an observation, and is worked out or dropped, not handed over.
