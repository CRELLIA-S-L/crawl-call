---
name: srs-upgrade
description: Upgrade the SRS-DD framework installed in this project — the checker, the viewer, the skills and, on request, the CI config and agent guides. Invoke when the user asks to update or upgrade SRS-DD, to pick up a new framework version, or when the checker reports a version older than the one they expect. Runs tools/srs_upgrade.py, which fetches the framework this project was installed from.
---

# Upgrading the framework in this project

Everything needed is already here: `tools/srs_upgrade.py` fetches the framework this project was installed from, runs its installer against this repository, and removes what it fetched.
There is no clone to keep around and no address to look up.

## Procedure

1. **Show the change first.**
   Run it without arguments:

   ```
   python3 tools/srs_upgrade.py
   ```

   It prints the version transition, the upgrade notes for the versions being crossed, and the exact created / refreshed / skipped list — then asks.
   Nothing has been written at that point.

2. **Read the upgrade notes to the user, not just the file list.**
   They are the only place that says what a new version expects of this project.
   Where a note calls for an action here, say so plainly.

3. **Apply on their word.**
   In a terminal, answer the prompt.
   Without one — an agent session, a script — pass `--yes`, and only after the user has seen step 1:

   ```
   python3 tools/srs_upgrade.py --yes
   ```

4. **Commit the result** together with the regenerated `specs/90-traceability.md`: the refreshed checker may write a matrix that differs from the committed one, and the CI gate compares it.

## What it does and does not touch

Refreshed without asking: the checker, the viewer, the upgrader itself, the commands that freeze a baseline and date requirements from the history, the checker of any optional layer the project keeps, and the skills.
Left alone: the CI configuration, `AGENTS.md`/`CLAUDE.md`, `.gitattributes`, the pre-commit hook, and the standards — `specs/README.md`, plus the standard of any optional layer the project keeps.
All of them are files that may already be the project's own, which is why none is replaced without being asked for.
To refresh those too, add `--force`; it only replaces files that carry the `SRS-DD` marker, so anything hand-written stays.

The specification is never touched.
Requirements are the project's own.

## Options worth knowing

- `--ref v1.2.0` — fetch a specific release instead of the default branch, for a project that pins its framework version.
- `--from ../srs-dd` — use a clone already on disk; nothing goes over the network.

## When it refuses

Exit code 2 means nothing was written: no `specs/` beside `tools/`, no `git`, an unreachable address, or no terminal to confirm at and no `--yes`.
Exit 3 means the installer rolled back and the project is untouched.
Both are safe to retry once the cause is fixed.
