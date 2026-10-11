---
name: srs-arch-harvest
description: Recover an architecture from a project that already has one — for a codebase adopting the layer with an empty arch/, or one whose records describe a cut it has outgrown. Reads the code, and an architecture document where the project keeps one, and proposes element records in approved batches. Invoke when the user wants to recover, reconstruct, import or backfill the architecture of an existing project. For maintaining a cut that is already written down use srs-arch; for mining requirements out of code use srs-harvest.
---
<!-- Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License -->

# Recovering an architecture from a project that has one

The format lives in `srs-dd/arch.md` and is not restated here.
Read first: `srs-dd/arch.md`, whole, in one call.

The layer is installed and `arch/00-elements.md` is empty or describes less than the project is.
This procedure turns what exists into records — always as proposals, never as decisions.
Every record named to a person is cited at its first mention, as `AGENTS.md` asks: `python3 srs-dd/tools/srs_arch.py --cite <ID>…` for an element, `python3 srs-dd/tools/srs_view.py --cite <ID>…` for a requirement.

**A project made of documents is out of scope.** The readings here are written for code — the dependencies the checker computes from imports, the draft it offers over files — and a specification of documents gets no architecture layer at this stage.

## Procedure

1. **Start from what the specification already answers.** `python3 srs-dd/tools/srs_arch.py --draft` prints one candidate record per directory holding files no part carries, each with the files and the requirements that name them. That is a join, not a cut: it knows nothing about responsibility.
2. **Read what the project already says about itself**, where it says anything: an architecture document, a README's layout section, a diagram's source. A claim it makes that the code contradicts is the code's, and the contradiction goes to the user — not into a record.
3. **One batch per candidate**, in the order the draft prints them. For each, read the files themselves — the imports, what calls what, what each module is for — and then write the record as *Naming a part* in `srs-dd/arch.md` says: one sentence of responsibility with no "and" in it, the files, the obligations, the dependencies that are real, the interface it is reached by, and `protects` where the two or three it was cut to keep are clear.
4. **Judge the batch before showing it.** Against the readings `.claude/skills/srs-arch/SKILL.md` carries: a part whose sentence needs an "and" is two, a part nobody can name is a directory rather than a part, and a part that protects nothing in particular is one to merge into its neighbour. Say which reading each record failed and what you did about it.
5. **Show the batch, then write it.** The records go into `arch/00-elements.md` only after the maintainer has seen them — the whole batch, as it would be written, in the message that asks.
6. **Run the checker after every batch**: `python3 srs-dd/tools/srs_arch.py --no-write`. The three readings it prints — a carrier no part claims, a realized requirement no part carries, a part answering to nothing — are the remaining work, and the dependency findings say where the cut you proposed disagrees with the imports.
7. **Repeat** until no carrier is unclaimed and no realized requirement is uncarried. Then write the decision: why this cut and not the neighbouring one, in `specs/adr/`.

## What this procedure does not do

- It does not invent a part to tidy the tree: a part exists because something is responsible for something, and a directory is not a reason.
- It does not touch `specs/`: a requirement never names an element, and a requirement that looks wrong while you read the code is `srs-audit`'s business or `srs-harvest`'s, not this one's.
- It does not write the map: `arch/90-map.md` is generated; run the checker and commit what it wrote.
- It does not run builds or tests (SRS-DD-ART-030 of the method); recovery is reading.
- It does not flip a status for the maintainer: a part that is built says `built` because somebody read the files and agreed.
