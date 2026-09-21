---
name: srs-new
description: Guided interactive authoring of a single new requirement in specs/ — choosing type, area, number, phrasing, and metadata step by step in a dialog with the user. Invoke when the user wants to add a requirement. For the general specification workflow (finding affected requirements, closing the loop after code) use the srs skill; for mining a spec from existing code use srs-harvest.
---

# Authoring a new requirement

The rules live in `specs/README.md`, not here: *Requirement block*, *Lifecycle* and *How to phrase* are the sections this dialog uses.
`python3 tools/srs_view.py --vocabulary` prints the words a block may use — types, statuses, methods, fields, and the areas and modal verbs of `specs/srs-config.json`; the lexicon there defines the specification language, whatever language this file is in.

## Dialog

Every step puts what it proposes — the statement, the number, the method, the links — in the message that asks, as it would be written and quoted in a block where it is long; "as shown above" sends the user back through the conversation for a text that may have moved.

1. **What behavior?** One capability per requirement. If the user describes two, say so and split.
2. **Type and area.** The area is one of the `areas` the project declares — `python3 tools/srs_view.py --areas` prints them with how many requirements each holds. Propose both, let the user confirm.
3. **Number.** The next free one in the area, in steps of 10: `python3 tools/srs_view.py --list --area <AREA>` prints every number the area holds, whichever files they are in. Where the next number is the area's first past a thousand — `1000`, `2000` — the area's file becomes a directory before the requirement is written, and this is the one moment it happens:

   ```
   git mv specs/10-fr-<area>.md specs/10-fr-<area>/000-999.md   # the whole file, history with it
   ```

   then open `specs/10-fr-<area>/1000-1999.md` with the area's heading and write the requirement there. Nothing in the moved file changes; `python3 tools/srs_check.py` reports the same requirements as before plus the new one, and `python3 tools/srs_view.py --diff HEAD` names only the new one. An area already a directory takes the new requirement in the file whose name holds its thousand, opening the next file when the thousand is full. A number between tens — `025` beside `020` — is for a requirement written beside an existing one, goes in the file of its thousand, and never continues the sequence.
4. **Statement.** Pick the pattern from the *How to phrase* table, a modal verb from the lexicon, and write in the lexicon's language. Then judge what no checker reaches, and say what you found: the checker proves the form — one bolded verb, a resolvable link, a fitting status — and cannot tell whether the sentence describes **one** capability, whether a reader could **confirm** it holds, whether a word like "quickly", "as needed" or "where possible" has made it unfalsifiable, or whether it describes **how** instead of what. Say it — "this names two capabilities, I would split it"; "nothing here says how anyone would check it" — and where it is sound, say that too, in a clause. Two instruments make it cheaper: **count the obligations, not the verbs** — a verb carrying a list of objects is as compound as two verbs (*How to phrase* says what to do), and more than one means more than one requirement, said before the number is chosen, because identifiers are never reused; and **where conditions combine, draw the decision table** — causes down the side, effects across, one row per combination that can occur — which answers whether the statement is singular and what the tests will have to cover; skip it for an unconditional statement.
5. **Verification method.** Ask how conformance will be checked (`T`/`D`/`I`/`A`); no answer means it is not a requirement yet. Then read the statement back against the answer and say where the method has nothing to confirm — `T` over a sentence no test could assert is the usual one, and this is the one moment the question costs nothing.
6. **What is already written.** Before the links are chosen, resolve which requirements already speak to this behaviour and what points at those, and say what you found — including "nothing". **Say what you searched, not only what came back** — the area, the words, the paths: a text search matches the word you guessed, the project's word may differ, and only the maintainer can tell, in one glance, if the words are in the report.

   ```
   python3 tools/srs_view.py --list --area <AREA> --statements
   python3 tools/srs_view.py --grep <word from the statement>
   python3 tools/srs_view.py --code <path the behaviour touches> --statements
   python3 tools/srs_view.py <ID>          # incoming links: the blast radius
   ```

   The search over words reads the project's prose beside its requirements, so a term the project uses and no requirement states is found here. Whatever turns up is named as `AGENTS.md` asks at its first mention, from `python3 tools/srs_view.py --cite <ID>…`. Two questions, neither substituting for the other: whether this is already said somewhere, and what a new obligation lands on top of. Filling the links from memory answers the first badly and the second not at all.
7. **Links.** Propose candidates from what step 6 turned up, for each link field.
8. **Initial status.** Per the *Lifecycle* section of `specs/README.md`.
9. **Rationale.** Ask why this way, if the answer is not obvious; write it down.

Then write the requirement into the file and run `python3 tools/srs_check.py`; show the result. Do not batch-create requirements silently — each one goes through the dialog.

## What it stands on

Only where the project carries a grounds register — a `grounds/` directory beside `specs/`; where there is none, skip this and say nothing about it.

The requirement now exists and can be named, so ask once what it stands on. Three answers, all three finished: **a hypothesis already in the register carries it** — record a bet through `srs-bet`, which reads the hypothesis back against its own numbers first; **it rests on nothing anybody wrote down** — a `U` declaration says so with a reason, and retires itself when a real bet appears; **neither** — the commonest and a complete one, since nothing obliges a requirement to be named by a bet, and a link invented to fill the shape looks like knowledge. The third answer has a loud version, and it is still the third: where the claim looks worth measuring and no hypothesis carries it, say so and stop — a hypothesis is written by the person who will answer for measuring it, with a bounded population, a threshold, a date and a named owner, and filling in that owner commits somebody who was never asked. Offer the observation, not the record. Say which of the three it was: an unasked question and an answer of "neither" look identical afterwards.

## Where this ends

At the written requirement, and at the architecture decision if the discussion settled one — a choice with consequences goes to `specs/adr/`; a discussion that settled nothing goes nowhere. **Not at the code.** Building it is a separate act, started deliberately; the `srs` skill is that procedure. Authoring that slides into implementing is why a requirement is born `implemented` in the same commit as its code, `deferred` never happens, and a baseline only ever records what already shipped. Say what was written, say that it is not built, and stop.
