# Constitution

Standing engineering principles of the project.
Every plan and every diff is checked against them.
Unlike requirements (what the system does) and ADRs (single decisions with their context), articles apply to all work at all times and change only through the amendment procedure in ART-090.

- **Version:** 1.3.0
- **Ratified:** 2026-08-05
- **Amended:** 2026-08-05 — v1.1.0: ART-020 tightened to approved requirements; ART-090 taxonomy extended to classify tightening and relaxing (both changes MINOR per ART-090)
- **Amended:** 2026-09-24 — v1.2.0: ART-070 added, named values in place of literals in code (MINOR per ART-090)
- **Amended:** 2026-09-24 — v1.3.0: ART-070 sends text a player reads to the string catalog, so that it can be translated (MINOR per ART-090)

Articles are numbered in steps of 10 and referenced from plans, reviews, and ADRs the same way requirements are: “rejected per ART-040”.
The set below is a starting point — adapt the articles to your project, but keep the amendment procedure.

## ART-010 — Hierarchy of truth

The specification stands above the code; the code stands above all other documentation.
On conflict, neither side is silently fixed: the discrepancy is recorded in `91-open-issues.md` and the maintainer decides which side is wrong.

## ART-020 — Requirement before code

No behavior changes without an **approved** requirement that describes the change — a `draft` is recorded, not approved (see the Lifecycle section of `specs/README.md`).
The mechanics — statuses, numbering, closing the loop — live in `specs/README.md`; this article only makes the principle non-negotiable.

## ART-030 — Boundaries of agent autonomy

Within an established requirement, an agent edits code and specification freely.
Builds, test runs, external network calls, data migrations, and deletion of files it did not create require the user's explicit confirmation — each time, not once per session.

## ART-040 — Simplicity

The boring solution wins by default; a clever one must earn its place in an ADR.
A new dependency requires an ADR.
Project tooling stays standard-library only.
Nothing is built for a requirement that does not exist yet.

## ART-050 — Testing discipline

A requirement with `verification: T` is flipped to `implemented` in the same set of edits that adds its test, and the test path goes into the `tests` field.
Verification by `D`, `I`, or `A` is carried out as described in `50-verification.md`, not by assertion.

## ART-060 — Quality gates

A change merges only when `python3 tools/srs_check.py` passes and, if the change alters behavior, the commit or PR description names the requirement identifiers it implements.

## ART-070 — Named values

A number or a string in the game's code, under `Sources/CrawlCall/`, carries a name — a constant or an enumeration case — and is declared where the project keeps values of its kind, never written inline where it is used; 0, 1 and −1 included, since an identity, a counter's start and an offset each have a meaning a name can state.
The tests, which set up and assert against values of their own, the bench under `Sources/PromptBench/`, whose prompts are the variants it measures, the scripts, the specification's tools — which the framework ships and an upgrade replaces — and `materials/` are outside it.
A value that is tuned — a speed, a distance, a duration, a threshold, a count — lives in the configuration under `config/` (ADR-0012), and its key is described by the interface requirement for that file.
A value the design fixes — a unit conversion, a proportion that follows from another, a file name, a key of a protocol — is a named constant under `Sources/CrawlCall/Config/`, grouped by the part of the system it belongs to.
Text a player reads lives in the string catalog; text a player hears and text sent to the model live in configuration; none of it in code.
An error or a log line opens with the identifier of its kind — an upper-case name with underscores, declared once in a catalogue under `Sources/CrawlCall/Config/` — then a colon and the message: `MAP_REPEATED_KIT: line 4 names the kit a second time`.
The identifier is the named value; the details after it describe and configure nothing, and stay where the line is written.
Exempt: the literal that declares a name — a constant's value, a configuration key in the schema, an identifier in the catalogue.
Code written before this article is brought to it when a change touches it.

## ART-090 — Amendments

The constitution changes only by a dedicated commit that bumps the version:
MAJOR — an article is removed, reversed, or relaxed; MINOR — an article is added or tightened; PATCH — wording changes without a change of meaning.
The commit message states the reason.
The project maintainer ratifies the amendment.
