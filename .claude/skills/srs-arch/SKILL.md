---
name: srs-arch
description: Working with the architecture layer — naming the parts a system is cut into, designing a cut against the specification before the code exists, recording a redraw as a move, and reading the disagreements the checker computes between that description, the specification, the dependencies and the files. Invoke when the user asks what the system is made of, wants to design, add or redraw a part, or when a change moved files between parts. For requirements themselves use srs and srs-new.
---
<!-- Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License -->

# Working with the architecture layer

The format lives in `srs-dd/arch.md` and is not restated here.
Read first: `srs-dd/arch.md`, whole, in one call — it is the one file this procedure needs.
The layer answers what the specification does not — not what the system must do, but what it is made of: an element is a part with a responsibility, the files that are that part, and the requirements it carries.
Every record named to a person is cited at its first mention, as `AGENTS.md` asks — the element from `python3 srs-dd/tools/srs_arch.py --cite <ID>…`, the requirement from `python3 srs-dd/tools/srs_view.py --cite <ID>…` — pasted as printed; a finding line copied as the checker printed it names them by key, which is not yet a citation.

## First things first

`python3 srs-dd/tools/srs_arch.py --no-write`; `python3 srs-dd/tools/srs_arch_doc.py` prints the layer as a document when somebody needs to read it rather than check it. Three findings lie between the description and the specification, and they are not the same finding:

- **a carrier no element claims** — a file the specification says realizes a requirement, and no part owns it: a `carries` out of date, or a part nobody has written down;
- **a realized requirement no element carries** — built, and no part answers for it;
- **an element carrying no requirement** — a part that answers to nothing: a part nobody needed, or a requirement nobody wrote; where the requirements are derived, a third reading — the part owns files no realized requirement names.

Say which reading it is before proposing an edit; two of the three are about a requirement, and the reading depends on what that requirement says, which is why all three are warnings.

Two more are about the dependencies the parts declare, and the specification has no say in either:

- **a dependency the code has and the model does not declare** — `depends_on` is incomplete, or the call is the thing that is wrong: a file in the wrong part, or a part reaching where it was cut not to. Read the file the finding names before deciding; the standard says where the checker gets these edges and which languages it reads on its own.
- **elements that depend on each other in a circle** — the cut is wrong and two parts are one, or one edge is a dependency in name only. A warning, because nothing the checker computes is broken by a circle.

Two more are about the record falling behind: an element still carrying a requirement that was superseded or withdrawn — drop it from the record, or carry the successor — and a path an element carries that is no longer in the repository — the record moves with the file.

Four are about a design rather than a description, and are read in the two sections below: **an approved requirement no part answers for**, **a designed part that is already built**, and the two about a move — **one that is finished** and **a path at neither of its ends**.

## Designing a cut

A part designed and not yet built is `proposed`, and the layer reads that status three ways: its files need not exist, it owns none of them yet, and it does answer for the obligations it names.

1. **Work against the drivers, not the whole specification.** `python3 srs-dd/tools/srs_arch.py --drivers`.
2. **Name the parts** as *Naming a part* below says, with `status: proposed` and the paths the files will have.
3. **Judge each one before writing it down**, by five readings — a part that fails one is renamed, split or merged, not documented: its sentence names one responsibility; everything it carries serves that sentence; what it leans on is declared and the code agrees; the obligations it answers for can be read in one sitting; crossing into it has a shape, which `interface:` is for — a part nobody can say that of has no boundary; and what it exists to protect is named in `protects:`, or protecting nothing in particular is the answer.
4. **Close the holes.** The checker lists every approved requirement no part answers for; while that list is not empty the design is unfinished, and each entry is a conversation, not a line to add. A `draft` requirement is not in it and is not designed against.
5. **Read what the move would cost** before touching anything: `python3 srs-dd/tools/srs_arch.py --plan` prints the files that change hands with both ends, the obligations that change part, the dependencies the design adds, and the parts it empties.
6. **Flip the status when it is built.** The checker says which designed part has all its files and all its obligations in place; changing `proposed` to `built` is a person's act, and the layer never does it.

## Recording a move

An agreed redraw is a record of its own — `M-<NNN>`, in `arch/10-moves.md` by convention — with `from`, `to`, `moves` and the `adr` it stands on; the format is in the standard. A part cut out of a bigger one is not a move but a design: there is no existing file to re-home. It is written when the redraw is agreed and closed when it is done, and the checker says when that is: a move whose every path is at the receiving end and none at the leaving one is finished. A path at neither end is a move that cannot be carried out as written — the file moved, or it belongs to a part the record never named.

**Moving the files is where a redraw breaks a repository.** One file at a time, and the project's own checks between each: move complete units and never a range of lines; write the new file, verify it, and only then delete the old; keep the original until what replaced it passes; a handful per round, no more.

The plan is computed and the move is authored: `--plan` is the difference between the two cuts, the record is what somebody decided to do about it, and why the cut changes is in the ADR.

## Naming a part

An element is a decision, not a description of the directory tree.

1. **Name what it is responsible for in one sentence.** An "and" in it is two parts, or one that needs a better name.
2. **List its files.** A directory in `carries` owns everything under it. Carriers are not only code — a standard, a procedure, a CI template, a payload.
3. **List the requirements it carries**, from what the specification says realizes those files: `python3 srs-dd/tools/srs_view.py --code <path>`. Where the layer's configuration says the requirements are derived, skip this: the checker counts as carried what the part owns, and the list is on the map; write `requirements:` only for an obligation the part answers for without owning its files, and say so in the rationale — the map marks the entry as written.
4. **Declare its dependencies** where they are real. `depends_on` is the model a person writes, not derived from the links between requirements — derived that way on the framework's own code it gave twenty-five edges against seven real ones. The checker reads only Python by itself; for any other language the project lists its edges in `arch/edges.json`, or the model has nothing that ever disagrees with it.

Every choice that could have gone another way goes into an ADR in `specs/adr/`: the layer records the cut, the ADR why this cut and not the neighbouring one.

## Redrawing a part

The same act as writing one, with two additions: the number of a dissolved part stays dead — `withdrawn`, or `superseded` with the successor named — and the checker is run afterwards and its findings read again: a file left behind is a carrier nobody claims, a caller moved away from what it calls is an undeclared dependency, and a file renamed or deleted with its element left behind is a carrier that does not exist — the warning says where git put it, and the record moves with the file in the same set of edits.

## What this procedure does not do

- It does not touch `specs/`: a requirement never names an element.
- It does not write the map: `arch/90-map.md` is generated; run the checker and commit what it wrote.
- It does not invent parts to fill the file: a layer written only to have elements is one every reader learns to ignore.
