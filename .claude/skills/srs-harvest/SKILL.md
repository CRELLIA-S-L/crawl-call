---
name: srs-harvest
description: Mine (extract) a specification from an existing codebase — for projects that have code but no requirements yet, or areas of the spec that lag behind the code. Reads the code area by area and proposes draft requirements in approved batches. Invoke when the user wants to build, extract, or backfill a spec from existing code. For authoring a single new requirement use srs-new; for checking existing spec against code use srs-audit.
---

# Mining a specification from existing code

The project is initialized (there is a `specs/srs-config.json`) but the code holds behavior the specification does not describe.
This skill turns that behavior into requirements — always as proposals, never as decisions.

The rules live in `specs/README.md` — *Requirement block*, *Lifecycle* and *How to phrase* are the sections this procedure uses; `python3 tools/srs_view.py --vocabulary` prints the words a block may use.
Read first: `specs/srs-config.json` — the `areas` partition the work, `code_roots` say where to look, and the lexicon defines the modal verbs and the **language the requirements must be written in**.

## Procedure

1. **Survey.**
   Walk the code roots; sketch which parts of the codebase map to which areas.
   Show the user the map and the order you propose to work in.
2. **One batch per area.**
   Read the area's code.
   For each observable behavior, draft a requirement: EARS phrasing in the specification language, one bolded modal verb from the lexicon, `status: draft`, `verification` chosen honestly, `code` listing the real paths (`tests` only when matching tests actually exist — never invent them).
   A batch whose numbers cross a thousand is written into the directory form — `srs-new`, step 3, says how — before the batch is written.
3. **Judge the batch, then show it — BEFORE writing it.**
   Every drafted statement goes through the same judgement `srs-new` gives a new one, against the qualities `specs/README.md` requires of a statement, and what you found is said alongside the batch.
   Mined statements are where this bites hardest — a sentence read off an `if` arrives sounding precise and describing how rather than what, and a batch is where a bad one is least likely to be noticed.
   Batching is the sanctioned exception to the one-at-a-time rule of `srs-new`; the judgement and the approval-before-write step are together what make it safe.

   **Then check the batch against what is already written**, and report what overlaps.
    A behaviour the specification already describes gets a second number here and keeps it: numbers are never reused, so the duplicate is permanent and the two copies drift from the day both are approved.
    Three sweeps, and they are not interchangeable.
    The area and the paths each return everything already described there, and a duplicate is among them rather than picked out for you.
    The words of the statement are the only sweep that reaches outside both, which is where the duplicate hides that carries another area's number or names a file the draft does not:

   ```
   python3 tools/srs_view.py --list --area <AREA> --statements
   python3 tools/srs_view.py --code <path the draft names> --statements
   python3 tools/srs_view.py --grep <word from the drafted statement>
   ```

   Say what each overlap is — the same behaviour under another number, or a neighbour worth a link — and let the maintainer settle it before the batch is written.
   Say what the three sweeps were given, too, not only what they returned: the areas, the paths, the words.
   A batch reporting no overlaps is the one claim here nobody can check without them — and the word a draft was searched under is where this goes wrong, because a mined statement carries the vocabulary of the code rather than of the specification.
   Each one named as `AGENTS.md` asks at its first mention, from `--cite`: a batch is read at speed, and a bare number in it is a lookup the maintainer has to make before they can judge anything.
   What the draft would disturb rather than repeat is the other half of the same sweep: what points at the requirements you found is what a new obligation lands on top of.
4. After writing an approved batch, run `python3 tools/srs_check.py` and show the result.
5. Repeat per area.
   Track what remains uncovered; finish with a summary of areas done, requirements proposed, and gaps.

## What the draft status means here

Each harvested requirement is `draft` with a filled `code` field, so the checker warns "implementation ahead of approval" for every one of them — **that warning list is the approval queue**, by design.
Approving, the maintainer flips the requirement straight to `implemented` (or `partial`) — the behavior already exists; `deferred` is not part of this path.
Warn the user: a CI gate running `--strict` stays red until the batches are approved — approve before pushing, or expect a red pipeline.

## Boundaries

- Describe only behavior that is actually in the code — do not invent, extrapolate, or "improve" while harvesting.
- Behavior you cannot make sense of goes to `specs/91-open-issues.md` (with the user's confirmation), not into a guessed requirement.
  Say what you tried and what the open question is: an entry that only records that something was confusing hands the reading back to somebody with less context than you had.
- Do not flip statuses yourself — approval is the maintainer's act.
- Do not run builds or tests (ART-030 of the constitution); harvesting is reading.
