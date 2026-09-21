---
name: srs-audit
description: Semantic drift audit between the specification and the code, including test adequacy — whether the listed tests actually prove the statements — and the links between requirements, which nothing else looks for. Invoke when the user asks to audit the spec, verify that code matches requirements, find undocumented behavior, check whether requirements are adequately tested, or derive test cases from statements. Read-only analysis with a report; fixes nothing by itself, except that on explicit request it can author the missing tests. For the everyday workflow use the srs skill.
---

# Auditing the specification

The checker (`tools/srs_check.py`) catches everything mechanical — broken links, missing paths, stale annotations by ID. This audit covers what it cannot judge: whether the code does what the statements say, whether the listed tests would prove them, and whether the links between requirements are all there. Do not re-report what the checker reports.

## Drift

1. `python3 tools/srs_check.py --no-write` for a known mechanical state; note the warnings. `python3 tools/srs_view.py --coverage` names where to look first: realized requirements with no tests, drafts with code, realized ones resting on a draft, code files no requirement references.
2. For every `implemented` and `partial` requirement — `python3 tools/srs_view.py --list --area <AREA> --statements` gives an area's statements in one call — read the files in its `code` and `tests` fields and judge whether the behavior matches the whole statement: condition and constraint, not only the action.
3. For each file under *Code files outside the specification* in `specs/90-traceability.md`, decide whether it carries behavior that deserves a requirement.
4. Ask the question nothing reports: **does the statement reach further than the `code` field names?** "Every tool", "the skills", "each command" claims a set; list what is in the set and compare. An incomplete field is green forever — the checker proves the paths exist, never that they are all of them — and it shows up as a rule that `--code <the other half>` never mentions.
5. Compare `tests` entries against what the tests assert; a test that exists and checks something else is drift too.
6. Report findings grouped by requirement, each in three parts — what the spec says, what the code does, where they diverge (`file:line`) — and classified as "code is wrong", "spec is outdated" or "cannot tell"; do not guess which. Name each requirement as `AGENTS.md` asks the first time it appears. Before anything is written down, finish the sentence *therefore*: where nothing follows, drop it rather than pass it on — an unresolved observation is paid for by a reader with less context than you, and a report that mixes them with findings gets skimmed. "Cannot tell" is a decision the maintainer owns, reported with the options.

## Test adequacy

Only `verification: T` requirements get derived cases; for `D`, `I` and `A`, check that the evidence `specs/50-verification.md` expects is recorded, and report (ART-050).

1. Decompose the statement along its parts — trigger ("When…"), state ("While…"), condition, obligation, constraint; each is a test dimension. **Where conditions combine, build a decision table** — causes down the side, effects across, one row per combination that can occur — and take the rows as the cases: a rule firing on `--force` **and** a marker has four rows, and a suite with one fixture reads as covered from every other angle. The table is an instrument, not a finding: only the gaps go in the report, and only where conditions genuinely combine — most statements are unconditional.
2. A quantified constraint implies boundary cases: "within 2 seconds" at and beyond the boundary; "all unsaved changes" — none, one, many.
3. Map the cases against what the `tests` files assert: covered, partial, uncovered — or asserted yet not derivable from the statement, which means the statement is under-specified: report it, do not edit it. **Covered means the test could fail**: for each covered case, name the change to the code that would turn the test red; if you cannot, the case is uncovered however much the test mentions its subject. The two shapes that look most convincing and are not — a statement with two obligations and a suite exercising one, a rule firing on several fields with a fixture for one. Name the edit; do not make it (ART-030).
4. On the user's explicit request — and only then — author the missing tests; the path goes into `tests` in the same set of edits (ART-050). Running them needs its own confirmation (ART-030).

## Links between requirements

The checker proves that every link written resolves and cannot prove that any was left out; its one rule fires only on total isolation, so a single link satisfies it. Every question of the form *what does this change reach* rests on the links. **One area at a time**: `python3 tools/srs_view.py --areas`, then `python3 tools/srs_view.py --list --area <AREA> --statements`.

1. Read the area's statements together — the unit small enough to hold in one reading; a link is only proposed between requirements that were read together.
2. For each requirement, open what looks related and judge which links are missing, in both directions: `depends_on` where one is meaningless without the other, `derives_from` where one exists because the other does, `refines` where one is the same obligation narrowed for a branch, `conflicts_with` where the divergence is deliberate. A link under the wrong field misdescribes the radius as surely as a missing one.
3. Look outside the area as well: a link crossing two areas is the one nobody was looking at when either end was written.
4. **Propose one link at a time and let the maintainer settle each** — both ends named as `AGENTS.md` asks, the field and why in a clause, then wait. Twenty approved in one breath are twenty nobody read.
5. Stop at the proposal; what is approved is written through the everyday procedure, matrix regenerated in the same set of edits (*Boundaries*).

Say what the pass covered — the area, how many requirements, how many links proposed and approved — because the next pass starts there and nothing else records it. A missing link is invisible by construction, so the pass ends with "read once, by somebody", never with "none remain". Linking a realized requirement to a `draft` makes the checker report it: the rule doing its job.

## Boundaries

- Do not flip statuses, edit requirements or change code during the audit — which side is wrong is the maintainer's call (ART-010).
- Write findings into `specs/91-open-issues.md` only with the user's explicit confirmation.
- Do not run builds or tests (ART-030); authoring missing tests on explicit request is the one exception.
