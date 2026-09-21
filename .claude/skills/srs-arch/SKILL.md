---
name: srs-arch
description: Working with the architecture layer — naming the parts a system is cut into, saying what each carries, and reading the disagreements the checker computes — three between that description and the specification, two about the dependencies the parts declare. Invoke when the user asks what the system is made of, wants to add or redraw a part, or when a change moved files between parts. For requirements themselves use srs and srs-new.
---

# Working with the architecture layer

The format lives in `arch/README.md` and is not restated here.
Read first: `arch/README.md`, whole, in one call — it is the one file this procedure needs.
The layer answers what the specification does not — not what the system must do, but what it is made of: an element is a part with a responsibility, the files that are that part, and the requirements it carries.
Every record named to a person is cited at its first mention, as `AGENTS.md` asks — the element from `python3 tools/srs_arch.py --cite <ID>…`, the requirement from `python3 tools/srs_view.py --cite <ID>…` — pasted as printed; a finding line copied as the checker printed it names them by key, which is not yet a citation.

## First things first

`python3 tools/srs_arch.py --no-write`. Three findings lie between the description and the specification, and they are not the same finding:

- **a carrier no element claims** — a file the specification says realizes a requirement, and no part owns it: a `carries` out of date, or a part nobody has written down;
- **a realized requirement no element carries** — built, and no part answers for it;
- **an element carrying no requirement** — a part that answers to nothing: a part nobody needed, or a requirement nobody wrote; where the requirements are derived, a third reading — the part owns files no realized requirement names.

Say which reading it is before proposing an edit; two of the three are about a requirement, and the reading depends on what that requirement says, which is why all three are warnings.

Two more are about the dependencies the parts declare, and the specification has no say in either:

- **a dependency the code has and the model does not declare** — `depends_on` is incomplete, or the call is the thing that is wrong: a file in the wrong part, or a part reaching where it was cut not to. Read the file the finding names before deciding; the standard says where the checker gets these edges and which languages it reads on its own.
- **elements that depend on each other in a circle** — the cut is wrong and two parts are one, or one edge is a dependency in name only. A warning, because nothing the checker computes is broken by a circle.

## Naming a part

An element is a decision, not a description of the directory tree.

1. **Name what it is responsible for in one sentence.** An "and" in it is two parts, or one with a name nobody has found yet.
2. **List its files.** A directory in `carries` owns everything under it. Carriers are not only code — a standard, a procedure, a CI template, a payload.
3. **List the requirements it carries**, from what the specification says realizes those files: `python3 tools/srs_view.py --code <path>`. Where the layer's configuration says the requirements are derived, skip this: the checker counts as carried what the part owns, and the list is on the map; write `requirements:` only for an obligation the part answers for without owning its files, and say so in the rationale — the map marks the entry as written.
4. **Declare its dependencies** where they are real. `depends_on` is the model a person writes, not derived from the links between requirements (ADR-0023 records the measurement that settled why). The checker reads only Python by itself; for any other language the project lists its edges in `arch/edges.json`, or the model has nothing that ever disagrees with it.

Every choice that could have gone another way goes into an ADR in `specs/adr/`: the layer records the cut, the ADR why this cut and not the neighbouring one.

## Redrawing a part

The same act as writing one, with two additions: the number of a dissolved part stays dead — `withdrawn`, or `superseded` with the successor named — and the checker is run afterwards and its findings read again: a file left behind is a carrier nobody claims, a caller moved away from what it calls is an undeclared dependency, and a file renamed or deleted with its element left behind is a carrier that does not exist — the warning says where git put it, and the record moves with the file in the same set of edits.

## What this procedure does not do

- It does not touch `specs/`: a requirement never names an element.
- It does not write the map: `arch/90-map.md` is generated; run the checker and commit what it wrote.
- It does not invent parts to fill the file: a layer written to have elements teaches every reader that the layer is decoration.
