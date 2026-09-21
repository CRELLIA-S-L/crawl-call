# Constitution

Standing engineering principles of the project.
Every plan and every diff is checked against them.
Unlike requirements (what the system does) and ADRs (single decisions with their context), articles apply to all work at all times and change only through the amendment procedure in ART-090.

- **Version:** 1.1.0
- **Ratified:** 2026-08-05
- **Amended:** 2026-08-05 — v1.1.0: ART-020 tightened to approved requirements; ART-090 taxonomy extended to classify tightening and relaxing (both changes MINOR per ART-090)

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

## ART-090 — Amendments

The constitution changes only by a dedicated commit that bumps the version:
MAJOR — an article is removed, reversed, or relaxed; MINOR — an article is added or tightened; PATCH — wording changes without a change of meaning.
The commit message states the reason.
The project maintainer ratifies the amendment.
