# ADR-0070 — A header list marks the whole file; a block inside one is ended where what it marks ends

- **Status:** accepted
- **Date:** 2026-10-10
- **Related requirements:** FR-TOOL-200, FR-TOOL-210, FR-TOOL-220, FR-TOOL-250, FR-VIEW-020

## Context and problem statement

Until SRS-DD 0.21.0 a list of annotations at the top of a file spoke for the file, and this repository wrote one in every source and test file: a header comment explaining what the file is, ending in `implements:` or `verifies:` with everything the file carries.
Since 0.21.0 such a list is a block over what follows it — without an `srs-end:` it reaches the next block, sixty lines or the end of the file — and only `file implements:` or `file verifies:` marks a whole file.
The upgrade to 0.24.0 on 2026-10-10 therefore turned every one of those lists into a claim about its first sixty lines: 159 blocks reported under `annotation-unended`, 146 of them header lists and 13 standing over a declaration inside a file.
Nothing failed — the rule reports — but `srs_view.py <ID> --where --source` showed a reader sixty lines of a file where the requirement is carried by all of it, and the standard says an agent reads that region as the requirement's whole extent.

## Considered options

1. Prefix `file ` on every list that stands in a file's header, above its first line of code, and end every block that stands over a declaration with `srs-end:` where the declaration closes.
2. Split every header list into one annotation per declaration, each ended with `srs-end:`, so that no annotation claims more than the lines that carry it.
3. Leave the notes and price the rule `off` in `specs/srs-config.json`.

## Decision outcome

Option 1.
It restores exactly what those lists meant before 0.21.0, and it matches the granularity the specification itself has: a requirement's `code` field names `Sources/CrawlCall/Game.swift`, not a declaration in it, so a per-declaration annotation would be a finer claim than the field it is compared with, maintained by hand against nothing.
The standard blesses the form for this case — a file that carries a requirement as a whole, or a suite that verifies one, says so this way — and the header comments already read as being about the file.
Option 2 is the right shape for a file whose parts serve different obligations, and the repository has none: the thirteen annotations that stand inside a file each stand over a test suite, which is such a part, and they keep their place and get an end marker.
Option 3 silences the one reading that says whether a region is a file or a fragment, which is the reading an agent acts on.

### How it works

A header list is one that stands before the file's first line of code — its own comment block, however long; seven source files and one script carry a header longer than fifteen lines and were found by that rule rather than by a line number.
Such a list becomes `file implements:` or `file verifies:`, keeping its comment prefix, and needs no end marker: it marks the whole file wherever it stands.
A block over a declaration keeps its place and gains `// srs-end: <first identifier>` on a line of its own after the declaration's closing brace, so the region is the declaration and nothing after it.
In this repository those are ten test suites in `Tests/` and three shell functions in `scripts/`.

The shell scripts were not being read at all: `scripts/` was in neither `code_roots` nor `test_roots` and `.sh` was not in `code_extensions`, while FR-TOOL-180, FR-TOOL-190, FR-TOOL-210, FR-TOOL-220 and FR-TOOL-250 name those files in their `code` fields.
Both were added, which brings the five scripts under the same checking as the Swift and Metal sources; a deliberately broken annotation in one of them was reported, so the reading is real and not an empty pass.

### Consequences

A new file's header list is written `file implements:` from the start, and an annotation that marks part of a file carries an end marker — otherwise the checker says so.
The claim stays at the file's granularity, so a reader who needs the exact declaration reads the file; sharpening that is a change to the `code` fields first, and this decision is what would be revisited then.
A shell script added under `scripts/` now has to be claimed by a requirement or it is reported as unclaimed, which is the same obligation every source file already had.
