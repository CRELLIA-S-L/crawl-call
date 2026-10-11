# The method

<!-- SRS-DD-0.24.0 — the framework release this file came from -->
<!-- Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License -->

The articles every project the framework is installed in is bound to: what the specification, the procedures and the gate stand on. They are the framework's — the same in every project, numbered in a space of their own and rewritten with this directory on every upgrade — and are referenced from plans, reviews and decisions the way requirements are: “per SRS-DD-ART-030”. A project's own principles live in `specs/constitution.md` under `ART-NNN`, numbered by the project alone.

Until 0.22.0 these articles stood in the shipped constitution as ART-010, ART-020, ART-030, ART-050, ART-060 and ART-100; a reference to one of those numbers in a record written before then means the article of the same number here.

## SRS-DD-ART-010 — Hierarchy of truth

The specification stands above the code; the code stands above all other documentation.
On conflict, neither side is silently fixed: the discrepancy is recorded in `91-open-issues.md` and the maintainer decides which side is wrong.

## SRS-DD-ART-020 — Requirement before code

No behavior changes without an **approved** requirement that describes the change — a `draft` is recorded, not approved (see the Lifecycle section of `srs-dd/standard.md`).
The mechanics — statuses, numbering, closing the loop — live in `srs-dd/standard.md`; this article only makes the principle non-negotiable.

## SRS-DD-ART-030 — Boundaries of agent autonomy

Within an established requirement, an agent edits code and specification freely.
Builds, test runs, external network calls, data migrations, and deletion of files it did not create require the user's explicit confirmation — each time, not once per session.

## SRS-DD-ART-050 — Testing discipline

A requirement with `verification: T` is flipped to `implemented` in the same set of edits that adds its test, and the test path goes into the `tests` field.
Verification by `D`, `I`, or `A` is carried out as described in `50-verification.md`, not by assertion.

## SRS-DD-ART-060 — Quality gates

A change merges only when `python3 srs-dd/tools/srs_check.py` passes and, if the change alters behavior, the commit or PR description names the requirement identifiers it implements.

## SRS-DD-ART-100 — Nothing sensitive in the repository

What the repository holds is read by everyone who can clone it, for as long as its history lives, and a commit that deletes a file does not remove it from that history.
No credentials, keys, tokens or connection strings; no personal data beyond what its authors chose to publish; no document shared in confidence or not released by its owner; no raw output of one machine or one session that carries its paths, names or environment — traces, logs, local configuration.
A file that must stay on one machine is named in `.gitignore` before it is written, and what is untracked is looked at before anything is staged, so that no sweep takes a file nobody read.
Where something sensitive was committed, it is revoked or withdrawn first and the history rewritten second: deleting it in a new commit is not removal.

## SRS-DD-ART-110 — Comments are minimal

A comment explaining how the code works earns a line or two.
One that needs a paragraph says the logic is not obvious, and the logic is what gets improved first; whatever reasoning survives that goes to the project's decision records, with the comment pointing at it in a clause.
A docstring documenting arguments, a returned shape or a format it reads may be as long as the shape it describes.

## SRS-DD-ART-120 — Simplicity

The boring solution wins by default; a clever one must earn its place in a decision record.
A new dependency requires one too.

## SRS-DD-ART-130 — A project's own principles

A project's own principles live in `specs/constitution.md` under `ART-NNN`, numbered by the project alone; the framework writes no article there and ships no such file.
That file changes only by a dedicated commit that bumps its version — MAJOR where an article is removed, reversed or relaxed; MINOR where one is added or tightened; PATCH for wording that does not change meaning — states the reason in the commit message, and is ratified by the project maintainer.
