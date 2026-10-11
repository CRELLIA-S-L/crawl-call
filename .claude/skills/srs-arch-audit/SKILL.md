---
name: srs-arch-audit
description: Audit the architecture of a project that has one — the cut against the specification, against the code, against what it stands on, and against what it costs — and end every finding in an act. Invoke when the user asks whether the architecture is any good, whether a part should be split or merged, or for a review of the cut. For writing or redrawing a part use srs-arch; for recovering a cut that was never written down use srs-arch-harvest.
---
<!-- Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License -->

# Auditing an architecture

The format lives in `srs-dd/arch.md` and is not restated here.
This audit reports; it changes no record. What to do about a finding is the maintainer's, and a record edited "while we were in there" is a decision nobody took.

Every element and requirement named to a person is cited at its first mention, as `AGENTS.md` asks: `python3 srs-dd/tools/srs_arch.py --cite <ID>…`, `python3 srs-dd/tools/srs_view.py --cite <ID>…`.

## What to read, in this order

1. **The mechanical state.** `python3 srs-dd/tools/srs_arch.py --no-write`. Do not re-report what it reports: a carrier no part claims, a realized requirement no part carries, a part answering to nothing, an undeclared or forbidden dependency, a circle, a part entered by a name its interface does not state, a part standing on refuted ground. These are the checker's findings and they are already said.
2. **The document.** `python3 srs-dd/tools/srs_arch_doc.py` — its two readings nothing else gives you: where the code disagrees with the model, and what the layer leaves unsaid.
3. **What the cut costs.** `python3 srs-dd/tools/srs_arch.py --price parts`, then `--price areas` and `--price proposed`. Links inside a group against links crossing it: a part with few inside and many crossing is a line drawn through the middle of something, and a part whose numbers are far worse than what the areas or the proposal would give is the one to argue about.
4. **What it drives.** `python3 srs-dd/tools/srs_arch.py --drivers` — the requirements that constrain structure. A driver spread across four parts is a finding; so is a part that answers to no driver at all.
5. **What it stands on**, where the project keeps a register: the document's section on the ground under each part. A part whose protected obligations rest on something `assumed` is a part to redraw gently; one on `refuted` ground is the checker's finding already.

## The five readings

Each part, against the readings `.claude/skills/srs-arch/SKILL.md` carries: the responsibility that needs no "and", the obligations it answers for, the boundary its interface states, what it protects, and what it depends on. A part failing one of them is renamed, split or merged — never documented into looking better.

## How a finding is written

Three parts, and then the act: **what the records say**, **what the code or the numbers say**, **where they diverge** — and then one of `rename`, `split`, `merge`, `redraw`, or `leave` with the reason. A finding with no act is an observation, and an observation is worked out or dropped rather than handed over.

**No score.** Not a number out of ten, not a grade, not a health percentage: two runs would disagree about a cut nobody touched, and a reader would argue with the number instead of the cut. What may stand beside a finding is a count from `--price`, which anybody can re-derive.

**Leaving a part alone is an act.** On a system that works it is the commonest one, and an audit that reports only complaints reads as a list of them.

## Where it ends

At the report, read once before it is sent and stripped of what the maintainer cannot act on. A redraw the maintainer accepts goes through `.claude/skills/srs-arch/SKILL.md` — the move record, the ADR, the records themselves — and not from here.
