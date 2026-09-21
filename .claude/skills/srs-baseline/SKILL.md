---
name: srs-baseline
description: Freeze this project's specification as a baseline — read what changed since the last one, agree the version with the maintainer, then run tools/srs_baseline.py, which writes the row into specs/92-baselines.md. Invoke when the user asks to cut, freeze, record or tag a baseline of the specification, or at a milestone worth being able to compare against later. The commit, and any spec/v* tag, stay with the maintainer's git client.
---

# Freezing a baseline

A baseline is a row in `specs/92-baselines.md` and the commit that adds it.
The rules are in the Baselines section of `specs/README.md`; read it if you have not in this session.
The command writes the row.
What it will not decide is the number that row carries, and it deliberately stops before the commit.

## Procedure

1. **Read what changed since the last baseline.**
   The newest version in `specs/92-baselines.md` is the one to compare against:

   ```
   python3 tools/srs_view.py --diff <that version>
   ```

   A version, not a tag: a baseline need not have one.
   Show the user what comes back — requirements added, removed, reworded, each named as `AGENTS.md` asks at its first mention, which `python3 tools/srs_view.py --cite <ID>…` prints.
   A column of bare numbers is the one thing this list must not be: it is the last look before the freeze.
   This is what the baseline is about to freeze, and it is the last moment to notice something in it that was not meant to be frozen yet.

2. **Offer an audit of what is about to be frozen.**
   The diff from step 1 names it: the requirements added and reworded, and the ones they link to.
   A baseline is the last cheap moment — after it, the frozen state is what every reader compares against, and a statement nobody can test freezes exactly as well as a good one.

   Scoped to what the diff names, never the whole specification: an audit of everything at every baseline is the step people stop taking.
   The procedure is `srs-audit`; offer it and accept a no.

3. **Propose the version, and let the maintainer settle it.**
   The scheme is in the Baselines section of `specs/README.md`.
   Read step 1 against it and say which reading you used, out loud — "MINOR, because two requirements were added and none removed".

   Do not settle it yourself.
   The number is a claim about the specification, and the person who owns the project owns that claim.

4. **Write the row.**

   ```
   python3 tools/srs_baseline.py X.Y.Z --dry-run
   python3 tools/srs_baseline.py X.Y.Z
   ```

   The dry run prints the row and writes nothing.
   Read it: where it says something the diff in step 1 did not, one of the two is wrong, and finding out which is cheaper now than after the commit.

5. **Hand the commit back.**
   The command writes `specs/92-baselines.md`, the checker it ran may have refreshed `specs/90-traceability.md` beside it, and there it stops — nothing is committed, tagged or pushed.
   Say which files are waiting and that **the commit carrying them is the baseline**; the maintainer makes it with whatever git client this project is driven by.

6. **Offer the tag once.**
   `spec/vX.Y.Z` on that commit makes the baseline easy to name in git later.
   Nothing depends on it — where there is none, the baseline is found by the commit that added its row.
   Mention it and move on; do not turn it into a step.

## When it refuses

Exit code 2, before writing anything: a version the log already records, or an error from the checker.
A warning does not stop it; the Baselines section of `specs/README.md` says on what terms, and why.
Fix the cause and run it again — there is nothing to clean up, and nothing in the history was touched.

## What this procedure does not do

Commit.
Tag.
Push.
Choose the version.
Cut a release — that is a separate act with its own number, and in this repository's own case its own framework-only procedure; a baseline freezes what the system must do, a release ships what it does.
