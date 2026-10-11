# ADR-0072 — The references between the parts are produced from the code, and the repository's guards become a part

- **Status:** accepted
- **Date:** 2026-10-11
- **Related requirements:** FR-TOOL-330, FR-TOOL-340

## Context and problem statement

ADR-0071 supplied `arch/edges.json` by hand so that the declared dependency model would have something that could disagree with it.
That closed the first half of the problem and opened the second: nothing holds the file against the code.
The standard says so plainly — the checker cannot regenerate what it did not compute, so a stale list is silent the way an absent one is (`srs-dd/arch.md`) — which means the model would have gone on being compared against a list kept by whoever last remembered to keep it, and the next real dependency would have arrived in silence.
It was written up as the weakest joint of the architecture plan and proposed as a requirement rather than built.
On 2026-10-11 the maintainer refused the framing: the file is held by hand only because an agent chose to hold it, and the tools for not holding it are already here.

The second problem is where such a command belongs.
The runners (E-080) carry `scripts` as a directory, so a new script under it would be theirs by default, and the pre-commit hook and the CI workflow — which the command has to be wired into — were carried by no part at all.

## Considered options

For producing the file:

1. Keep it by hand, as ADR-0071 left it, and re-derive it in the same set of edits as any change that moves a reference.
2. A command in the repository that writes it from the sources, run by the pre-commit hook and the pipeline, with a commit that leaves it stale refused.
3. A command, but without the guard: produce it on request and trust the procedure to run it.

For what the file holds:

1. One witness per pair of parts, with the weight of the pair beside it, as ADR-0071 chose.
2. Every file pair the code joins — 268 of them — and let the checker collapse them.

For where the command belongs:

1. The runners, which already carry `scripts`.
2. A part of its own for the repository's guards, carrying the command, its self-test, the hook and the workflow.

## Decision outcome

**Producing it, option 2.** Option 1 is what failed: the only thing the hand-kept file was never caught at was going out of date, and a rule that depends on an agent remembering it is not a rule. Option 3 keeps the generator and loses the only mechanism that would ever notice — the file was correct on the day it was written, and would have been wrong by the next commit that moved a type, with nothing to say so.

**Holding it, option 1.** ADR-0071's reason for one witness per pair was that a file of 35 entries is one a person can keep, and that reason does disappear once nobody keeps it. Two others replace it: the checker prints `via` beside every finding, and with 268 entries the witness printed would be an arbitrary one of eight rather than the pair's weight; and the model is about what the parts lean on, so a second reference inside a pair that is already declared is not news. The entry now says which symbol and line witnessed the pair, how many references it has and from how many files, which is what makes a finding say the weight of an edge and not only its existence.

**Where it belongs, option 2 — E-140, the repository's guards.** A runner drives the project's software from outside and reports what it did; a guard reads the repository and refuses a change to it. The two face opposite ways, and the knowledge in each is different: a runner knows that a phase ends when its log says so, a guard knows what the model of the parts is derived from. The part is also the home the layer has been missing — `ATTRIBUTION.md` sits with the map layer "for want of a better home rather than by right", and the twelve publication constraints name no file while the files that keep them are carried by nobody. Those join E-140 as their obligations are built, not before.

## Consequences

**Writing the rule down as a command found two places where the hand pass had departed from it.** ADR-0071 states that a mention is not a reference where it is "a type that file declares itself"; the hand pass had read that as a type the file declares *at the top level*, and `Sources/CrawlCall/Setting/Birds.swift`, which has a nested `Flight`, was therefore read as referring to the squads' `Flight`. The same for a name written after a dot: `Birds.Flight` in `Sources/CrawlCall/Setting/SceneryBuilder.swift` names the container before the dot, which is why the rule excludes nested types at all — another file cannot name one without naming its container first. Each had produced an edge between parts that does not exist; both are now in the command and in its self-test, each proved by removing the rule and watching its own check go red.

**The two corrections cancel out in the model and move the count.** The command reproduces exactly the 35 pairs of parts the hand-kept file held — no pair gained, none lost — so `depends_on` needed no change and the layer still reports the same thirteen circles. What moved is the weight: 1 317 references between parts where ADR-0071 counted 1 307, the difference being the two rules applied in both directions.

**A commit now carries the file.** The hook runs `python3 scripts/arch-edges.py --check` before the gate, and the pipeline runs it before the specification gate; either refuses and names the command to run. A change that moves a type between parts therefore cannot be committed without the model noticing, which is the whole point.

**The self-test covers the rule from both sides.** Thirteen cases over temporary trees: a reference between parts, one inside a part, a name in a string literal, a name in a line comment and in a block comment, a file's own nested name, a qualified name, a name two files declare, a part still `proposed` claiming nothing, `--check` on a fresh file and on a stale one, that `--check` writes nothing, and a tree with no sources at all.

**What is not covered by a test.** FR-TOOL-340 is verified by inspection: both ends are one line of wiring, and a test that drove the hook in a throwaway repository would see the commit refused by the gate for other reasons and pass for the wrong one.
