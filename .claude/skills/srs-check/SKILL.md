---
name: srs-check
description: Name and run the checks a finished change calls for — the specification checker, the grounds checker where the project keeps a register, the architecture checker where it keeps the layer, the tests the requirements it touched list in their own fields, and what a person has to look at where the method is not a test. Invoke when the user asks to check, verify or review work before committing, or when a change is finished and nothing has been run yet. Offers; never runs a suite unasked.
---

# Checking a finished change

The specification already knows which checks a change calls for.
Every requirement carries a `verification` method and the paths that verify it, and nobody reads them for this purpose — so the answer is derived, not remembered.

## Procedure

1. **Name what the change touched.**
   The requirements it names, or, from the files it edited:

   ```
   python3 tools/srs_view.py --code <path>
   ```

   Name each of them as `AGENTS.md` asks the first time it appears — what this procedure reports is read by a person, and `--cite` prints the line.
   Say which paths you gave, not only which requirements came back: a path spelled wrong returns an empty list, and an empty list is also what a change governed by nothing looks like.

2. **Read what each of them asks for.**
   `python3 tools/srs_view.py <ID>` prints the method and the `tests` field.
   Sort them into three lists:

   - **the checker** — always, for every change to `specs/`:
     `python3 tools/srs_check.py`;
   - **the architecture checker**, where the project carries the layer — an `arch/` directory beside `specs/`: `python3 tools/srs_arch.py`.
     It regenerates `arch/90-map.md` on the same terms as the dashboard below, and a change that moved a file between parts is exactly what it reports.
   - **the grounds checker**, where the project carries a register — a `grounds/` directory beside `specs/`: `python3 tools/srs_grounds.py`.
     It regenerates `grounds/90-dashboard.md`, and the project's gate fails on a committed copy that no longer matches, so a change that moved a requirement or a record and did not run this hands back work that passes everything else and reddens the pipeline.
     Where there is no register the command is not there, and this line does not apply — say nothing about it;
   - **the suites** those requirements name in `tests`, and nothing else:
     a change to the viewer does not call for the installer's suite;
   - **what a person has to look at**, where the method is `I` or `D`.
     Say it in words, naming the requirement and what to do: "this one is verified by inspection — open the page, follow a link from the dashboard, and see that it lands on the card".

   A requirement whose method is `T` with an empty `tests` field is a gap, not a check: say so rather than inventing something to run.

3. **Offer, and wait.**
   Builds and test runs need the user's word each time — that is ART-030 of `specs/constitution.md`, not politeness.
   List the commands and ask.
   Where the project has checks of its own that the specification does not name, ask rather than guess.

4. **Run what was approved, all of it,** and report per check: passed, failed with the output, or not run and why.

5. **After a repair, offer the whole set again.**
   A fix is a change like any other: rerunning the check that was red says it is no longer red and nothing about what the fix broke beside it.
   The list is the one from step 2, unchanged — a repair does not narrow the change it belongs to — and it is offered, not run (ART-030).
   Where the repair touched the specification, the checker is in that list too.

6. **Say what is left to eyes.**
   The inspection list from step 2 does not disappear because the suites are green.
   A change verified by inspection and never inspected is unverified.

## What this procedure does not do

Commit.
Decide that a red check is acceptable.
Run anything the user did not approve.
Replace the project's own habits — where a project has a gate of its own, this names what the specification asks for on top of it.
