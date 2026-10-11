# The architecture layer

<!-- SRS-DD-0.24.0 — the framework's; rewritten whole by every upgrade -->
<!-- Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License -->

A specification records what the system must do.
It does not record what the system is made of: which parts exist, what each one is responsible for, which files are that part, and which parts lean on which.
That description usually lives in a diagram nobody regenerates and in a paragraph of prose no rule reads — delete either and every gate stays green.

This layer is where it goes instead.
Each part is a record with an identifier, a statement of what it is responsible for, the requirements it carries and the files it is made of.
From those the checker computes disagreements that are otherwise invisible; the first three are a file the specification claims and no part owns, a requirement that is built and belongs to no part, and a part that answers to nothing, and *Checking* names them all.

The layer is optional.
It is a sibling of `specs/`, never a part of it, and nothing here is ever written into a requirement file.

## When not to have this

Do not install the layer where the parts are obvious and few — a single script, a library with one public module, a service whose whole structure fits in the README's first paragraph.
There the description would be a second copy of the file tree, and a description that adds nothing teaches every reader that this directory is decoration.

The question worth asking is not "could we list our parts" but "is there a boundary somebody could cross without noticing".
Where the answer is no, decline the layer and lose nothing.

## The join, and which way it points

An element names the requirements it carries.
A requirement never names an element.
The other direction is computed, and it is computed rather than stored for the reason the same rule exists in the grounds register: a link written on both ends eventually disagrees with itself, and only one of the two copies is ever updated.
Where the project derives the requirements instead (see *Derived requirements*), the direction does not change: the join still lives on the element's side, in its `carries` rather than in a list, and the requirement still names no element.

It is also what keeps the layer optional.
Nothing in `specs/` mentions this directory, so removing `arch/` removes the layer and leaves the specification exactly as it was.

## Identifier

`E-<NNN>`, three digits or more, numbered in steps of 10 so there is room to insert a neighbour; after `E-990` comes `E-1000`, written without a leading zero, and the tools order elements by the number.

An identifier is immutable and never reused.
A part that is dissolved gets status `withdrawn`, or `superseded` with its successor named; the number stays dead either way, because a reference from an old review has to keep leading to the same place.

## The record

Every record in this layer is written the same way:

````markdown
### E-010 — The document store

```yaml
status: built
carries: [src/store, src/store_index.py]
requirements: [FR-CORE-010, FR-CORE-020]
depends_on: []
interface: a query API and a write path, both over the same index
```

Holds every document, indexes it and answers a query about it.

**Rationale.** Split from the editor because the two are used at different moments and by different people: one is written to, the other is read from under load.
````

A level-three heading with the identifier and a title; a fenced `yaml` block of flat keys whose values are scalars or bracketed lists; a statement of what the part is responsible for; and, optionally, a rationale.

The shape deliberately resembles a requirement and a grounds record, so that whoever has read one standard can read this one.
It is not the same format.
None of the three is obliged to follow another's edge cases, and a later reader who merges them would be inventing a coupling all three were designed to avoid.

**Keys are added, never renamed.**
A key that is neither required nor optional here is not an error — that tolerance is what lets a later version add one without breaking a layer written against an earlier version.

| Key | | |
|---|---|---|
| `status` | required | `proposed`, `built`, `superseded`, `withdrawn` |
| `carries` | required | the files and directories that are this part |
| `requirements` | required, unless derived | the requirements this part realizes — see *Derived requirements* |
| `depends_on` | optional | other elements this part leans on — the declared model |
| `interface` | optional | how the part is reached from outside — a name stated here is what another part may enter by, and one it enters by and this does not state is reported |
| `protects` | optional | the requirements the part was cut to keep, a subset of what it carries |
| `units` | optional | the units this part ships in, by the names the project uses for them |
| `superseded_by` | by status | the successor, where the status is `superseded`; read by a person, not checked |

`carries` is not limited to source files.
A requirement's `code` field names whatever realizes it — a standard, a procedure, a CI template, a template shipped to somebody else — and the part that owns those files is a part like any other.

**Which part a file belongs to.** The element with the most specific claim on it: the one that carries the path itself, failing that the one carrying the nearest directory above it.
A part inside another therefore owns the files it names, and the order the records are written in decides nothing.
Where two elements claim a path equally it belongs to neither, and every rule that needs an owner is silent about that file — the one thing to suspect when a file nothing reports turns out to be claimed twice.
This is the resolution everywhere: the carrier findings, the requirements derived from what a part owns, the imports read from the code and the edges a project supplies all ask it.

**A dependency can be forbidden.** `depends_on` says what a part leans on; what no part may lean on is policy about the cut, and it lives in the layer's configuration:

```json
{"forbidden": [{"from": "*", "to": "E-030", "why": "nothing leans on the installer"},
               {"from": "E-080", "to": "*", "why": "the standard depends on nothing"}]}
```

Each entry names two ends — an element, or `*` for any — and the sentence its failure prints, which is required: a prohibition whose failure cannot say what it protected is one somebody deletes.
It is reported under `dependency-forbidden` where an element declares such an edge and where the code has one, since the two differ: a model contradicting the project's own policy, and the policy broken in silence.
An entry naming an element no record defines, missing a side or its reason, or carrying `*` on both sides is refused rather than reported — it resolves to nothing and would read as enforced.

**Who may reach a part can be said once.** The mirror of a prohibition: there the named pair is refused, here everything but the named few is, which is what a project means by "only the gateway reaches the store" and would otherwise be one prohibition per other part:

```json
{"only": [{"to": "E-020", "from": ["E-010"], "why": "the store is reached through the gateway"}]}
```

`from` is a non-empty list of parts; empty would say that no part may reach this one, which is a prohibition with a wildcard, and neither side takes `*` — on `to` it would be a statement about the whole cut, which the order is for, and on `from` it would permit everything, which is the absence of a policy.
It is reported under `dependency-unpermitted`, in the declared model and in what the code says, with the sentence the project gave.
An entry naming a part no record defines fails the run; one missing a key or holding something that is not an element is refused before anything is read.

**The cut can have an order.** Where the parts stand in levels, saying so as a pair for every two of them grows as the square of the cut and is rewritten whenever a part is added; an order says it once, and the pairs fall out of it:

```json
{"layers": [["E-010"], ["E-020", "E-030"], ["E-040"]]}
```

The list is read top down: the first group may lean on every other, the last on none.
That direction is fixed and will never be reversed, because a reversed reading would turn every finding into its opposite without changing a character of the file.
Within one group nothing is reported — a group is the level, a set of parts that may lean on each other, and a project that wants two of them separated puts each in a group of its own.
A part in no group is outside the order and nothing is said about it, which is how an order is adopted on a cut that already exists: one group at a time.
An edge that runs upward is reported under `dependency-upward`, where an element declares it and where the code has it, the two being different findings for the reason a forbidden pair gives.
No sentence is asked of the project here: the order is its own reason, and the finding says where each of the two parts stands in it.
A part named in two groups has no place in the order and is refused rather than reported, the way a prohibition with `*` on both sides is.

**What a part may build with is policy too.** `depends_on` and the order speak about parts of this system; a module from outside it has no element to name, and the prohibition says the part, the module and the sentence its failure prints:

```json
{"forbidden_imports": [{"in": "E-010", "module": "subprocess", "why": "the model never shells out"}]}
```

`module` is the top-level module name as the code writes it, which is what the checker reads — `import a.b` and `from a.b import c` are both `a` — and nothing else: a pattern, a path or a dotted name inside a package would each need a reading of its own.
It is reported under `import-forbidden` where the language of a file the part carries can be read, and says nothing where it cannot, as the comparison with the code says nothing there.
An entry naming a part no record defines fails the run, and one missing a key or naming something that is not an element is refused before anything is read.

`depends_on` is the declared model, and it is written by a person.
It is not derived from the links between requirements: those record one obligation resting on another, which is not the same relation as one part calling another, and deriving it was measured and rejected: on the framework's own nine Python modules it gave twenty-five edges against the seven their imports have.

What the code says is compared with it, one way round: a dependency the code has and the model does not declare is reported under `dependency-undeclared`; a declared dependency nothing in the code walks is not, because no reading of the code is complete enough to refute the author.
The checker reads one language itself — Python, by its imports.
For every other language it reads `arch/edges.json`, where the project lists what its code depends on:

```json
[
  {"from": "Sources/Core/Router.swift", "to": "Sources/Shell/Capsule.swift", "via": "Capsule:12"}
]
```

An edge is between two files, repository-relative; the checker resolves each end to the element that carries it, by the same rule that decides which part a file belongs to, and `via` is whatever the project wants printed beside the finding — a symbol, a line — and is never parsed.
An end no element carries, or one more than one element carries, is left alone.
An end that is an element identifier is refused: a part depending on a part is what `depends_on` is for.
Keys may be added over time; none is renamed or removed once published, because the tool that writes this file is the project's and the framework will never see it.

How the file is produced is the project's business — an extractor in the project's own language, a build step, a list kept by hand — and so is its freshness.
The checker cannot regenerate what it did not compute, so nothing holds the file against the code: a stale list is silent the way an absent one is.
A project that generates it runs the generator before the checker, in the same pipeline; a project that writes it by hand treats it as any other hand-written record.
Without the file, a project written in a language other than Python has a declared model and nothing that ever disagrees with it — `Warnings: 0` is then the absence of a verdict, not a verdict.
The checker says so on such a run: where no carried file is in the language it reads and there are no supplied edges, it notes that the model was compared with nothing.
That note is not one of the rules and cannot be priced away — it does not report anything about the cut, it reports what the run did not do.

## Units, and the facts about them

A part is what the code is divided into; a unit is what is deployed or run as one piece, and the two do not line up — a unit may hold many parts, and one part may ship as two.
A part says which units it ships in, by the names the project uses for them:

```yaml
units: [orders-api, orders-worker]
```

The names are the project's own, because what a unit is called is a fact about its world and not something this layer can know.
What a unit holds is not written anywhere: it is the parts that name it, computed, for the reason the requirements a part carries are written on one side only.
A unit is therefore not a record of this layer and has no identifier of its own.

What the project knows about those units goes in `arch/units.json`, which the project produces however it can — from deployment descriptors that may live in another repository, from its own pipeline, from traces of the running system, or by hand:

```json
{"taken": "2026-10-07",
 "source": "deploy repo at 4f21a0c",
 "life": 14,
 "units": ["orders-api", "orders-worker", "billing"],
 "links": [{"from": "orders-api", "to": "billing"}]}
```

`taken` and `source` are required: a fact whose age and origin are unknown cannot be weighed against a model, and a reader judging a disagreement has to know what the model was compared against.
`life` is how many days the producer says the facts stay true, and only the producer can know it; past that the checker uses none of them and says so, because facts taken together are one reading of the system and half a stale reading is not a fresher one.
A file stating no life cannot go stale and is used as it is; that it says nothing about its own age is told to a reader by the document, with the rest of its provenance.
`links` is optional — a project may know what it runs long before it knows what talks to what.

Three rules compare the two: a unit a part names that the facts do not hold, a unit the facts hold that no part names, and a link the facts hold that no part's `depends_on` accounts for.
All three cost a note by default, because the far end is usually a repository this one does not own and failing a build over somebody else's deployment makes one team answer for another's decisions; a project whose own pipeline produces the facts can price them up.
The links are compared one way only, as the code is: facts about a system show what happened or what is permitted, never that something cannot happen.

How the file is produced and when is the project's business, as it is for the edges file: a project that generates it runs its producer before the checker, in the same pipeline, so that the reading and the comparison are one act; a project that writes it by hand treats it as any other hand-written record and leans on `life` to say how long that hand's work is worth trusting.
Nothing holds the file against the system — the checker cannot read what it did not compute — so a file with no life is as silent as an absent one and says nothing about its own age.

**The framework reads this one format and no technology.** It has no reader for any descriptor, manifest, pipeline or trace, and never looks at a running system: what turns a project's world into these facts is the project's own, and it is where the knowledge of that world belongs.

## Derived requirements

A specification written by capability names the view, the engine and the table in one requirement, so a requirement lands in two or three parts and every part's list grows with every capability.
Past a few hundred requirements those lists cannot be kept by hand, and a list nobody can keep is lowered to `report` and stops meaning anything.

A project at that scale says so in the configuration:

```json
{"requirements": "derived"}
```

Under `derived` the checker counts as carried by an element every `implemented` or `partial` requirement whose `code` field names a file the element owns — by the same rule that decides which carrier a file belongs to — together with any the record still names.
The `requirements` key becomes optional.
A record that keeps it is making a claim the derivation cannot: that this part answers for an obligation whose files it does not own.

**What the record shows changes.**
Under `derived` a record naming no requirement is not a part that answers to nothing; what the part carries is in the map, which marks what the record names apart from what was computed.
Read the map, not the record, to learn what a part carries.

Nothing is written back.
The records stay the author's, the map is where the projection lives, and the gate that compares the map now holds it fresh against the specification's `code` fields as well as against the records.
The default is `written`: every entry is the author's claim, and a layer written before this key existed reads exactly as it did.
This is not the derivation measured and rejected above — `depends_on` is still written by a person — and the projection lives in the map rather than in the record, because a tool writing it back into the record would be editing what a person authored.

## Designing a cut

A part is `proposed` while it is designed and not yet built, and that status is read three ways.

Its carriers need not exist: a designed part names where its files will be, so the warning about a path nobody has stays silent for it (`carrier-missing`).
It owns none of those files: until it is built, whatever part answers for them today still does, so a file a design names and no built part owns is still reported as unclaimed.
It does answer for the obligations it names, because that is what designing is — a cut nobody could assign a requirement to could never be finished.

From those three the completeness of a design is computable, and it is the one reading this layer makes before any code exists: a requirement that is approved and awaiting implementation, which no part answers for, is reported under `requirement-unassigned`.
While that list is not empty the design has a hole in it; empty, the cut covers every obligation the specification has approved.
It is a note rather than a warning unless the project says otherwise: a backlog is not a defect.
A `draft` requirement is not in the list — it is recorded and not approved, and designing structure against it is structure ahead of approval.

The other direction closes the loop.
A designed part whose files are all in the repository and whose every obligation is realized is a built part with the wrong status on it, and is reported under `element-built`.
Both halves are required: a part whose files exist while its obligations are unbuilt is being built rather than built.
The status is changed by a person — nothing here edits a record.

What moving to a designed cut requires is computed on request:

```
python3 srs-dd/tools/srs_arch.py --plan
```

It prints every path the designed parts claim — with the part losing it, or with the fact that the repository does not have it yet — the obligations that change part, the dependencies the designed parts add, and the built parts the design empties, whose declared dependencies go with them.
A record it could not read is said and left out, since the checker is what names it.
It reports no finding and fails nothing: a designed cut differing from the built one is the normal state of a project that designs before it builds, and a warning for it would fire for as long as the design lives.

## The move record

A redraw outlives the commit that starts it: it is agreed once, carried out over several changes, and read by whoever arrives in the middle of it.
That is what a move record is for, and it is the second kind of record this layer holds.

````markdown
### M-010 — The parser leaves the checker

```yaml
status: moving
from: [E-010]
to: [E-110]
moves: [srs-dd/tools/srs_parse.py]
adr: ADR-NNNN
```

Hands the shared reader to a part of its own, so that neither checker owns the other's parser.
````

`adr` holds the number of the decision itself — written out, as `specs/adr/` spells it.
The shape is the element's, down to the promise that keys are added and never renamed.
The kind is told by the identifier's prefix — `M-<NNN>`, numbered and immutable exactly as `E-<NNN>` is — so the records live wherever the project puts them; `arch/10-moves.md` is the obvious place and no rule requires it.

| Key | | |
|---|---|---|
| `status` | required | `planned`, `moving`, `done`, `abandoned` |
| `from` | required | the elements losing the responsibility |
| `to` | required | the elements taking it |
| `moves` | required | the paths that change hands |
| `adr` | required | the decision the redraw stands on |

A move is **in force** while its status is `planned` or `moving`; `done` and `abandoned` have left the model the way a cancelled element has, and nothing is reported about them again.

An identifier used twice, a required key absent and a status outside the four are errors, as they are for an element.
So is a name that leads nowhere: an element no record defines in `from` or `to`, or an `adr` the specification holds no document named after — a move between parts one of which does not exist can be neither planned against nor completed.
Whether the decision says what the move does is a reading a person makes, and nothing here tries.

Two findings are about where a move has got to, read off what the elements at its ends claim rather than off who owns what, because a redraw is carried out by editing the records:

- a move in force whose every path is claimed by an element in `to` and by none in `from` is finished, and is reported under `move-complete` so the record gets closed;
- a path at neither end cannot be moved as written — the file was renamed, or it belongs to a part the move never named — and is reported under `move-orphan`.

**An extraction is not a move.**
A move re-homes a file that exists: the path leaves one part's `carries`, arrives in another's, and the move is finished when every path is at the receiving end.
Where the receiving file does not exist yet — a part cut out of a bigger one — there is nothing to re-home, and a move record written for it is complete the moment it is saved.
That act is the design instead: the new part stands `proposed`, its carriers name the files to be written, and `element-built` says when it is there.

**The plan is computed and the move is authored.**
`--plan` says what the difference between the two cuts is; a move record says what somebody agreed to do about it, and survives the commits that carry it out.
Neither replaces the decision: the layer records that the cut is changing, and `specs/adr/` records why.

## What a part was cut to keep

`requirements` is flat: everything a part answers for, the behaviour it happens to hold and the property that would be lost if its boundary moved, in one list.
The second kind is what a cut is defended with, and `protects` is where it is written — a subset of what the part carries, usually an invariant, a constraint or a quality the specification already states.

```yaml
protects: [CON-CORE-010, INV-CORE-020]
```

Empty is ordinary and silent: most parts hold behaviour and protect nothing in particular, and a key demanded of every record is ceremony.
A requirement here the part does not carry is a claim about somebody else's boundary (`protects-uncarried`); one the specification does not carry at all is an error.

**A quality scenario is a requirement, not a record of this layer.**
What a part must keep true under some stimulus is a falsifiable property, and a specification is where those live, with a verification method and tests; a second place to write them would be a second model of the same system. So the scenario is stated as an `NFR` or an `INV` and this key points at it.

## The map

`arch/90-map.md` is generated from the records and never edited by hand.
It states, for every element, what it carries, which requirements it holds and what state it is in; where the requirements are derived, it marks which of them the record names and which were computed.
Where the layer holds moves in force, it says of each what it moves, between which parts and in what state: a system mid-redraw is not described by its parts alone, since a part may still carry files it is losing.
A committed map that no longer matches what the records produce is a change somebody made without looking at the parts, which is why the map is compared rather than trusted.

## Checking

```
python3 srs-dd/tools/srs_arch.py              read the layer, report, and regenerate the map where there is no error
python3 srs-dd/tools/srs_arch.py --no-write   report only
python3 srs-dd/tools/srs_arch.py --strict     treat warnings as errors
python3 srs-dd/tools/srs_arch.py --cite ID…   name elements to a person: identifier, title, file, status
python3 srs-dd/tools/srs_arch.py --drivers    the ten requirements that drive the cut, most constrained first
python3 srs-dd/tools/srs_arch.py --plan       what moving to the designed parts requires
```

Errors are the readings that make the rest meaningless: a file that cannot be read, an identifier that is malformed or repeated, a missing required key, a status outside the four, a requirement that does not exist, and a dependency on an element no record defines.
Everything else is a warning, because the honest resolution differs case by case and the checker cannot choose it.
A path an element carries that is not in the repository is one of those warnings, under `carrier-missing`: the record still reads, and it went stale the commonest way — a file renamed or deleted with the element left behind.
Where git can tell, the warning says where the file went — renamed to what, in which commit, or deleted in which — so the record is fixed with one edit; the layer never edits it, because the record is the project's and a file that moved may have moved between parts.

What a rule costs is the project's to set, in `arch/arch-config.json`, beside the `requirements` key described above:

```json
{"rules": {"carrier-unclaimed": "report"}}
```

`warn` is the default and what `--strict` fails on, `report` is said and fails nothing, `off` is not said at all.
One rule costs less by default: `requirement-unassigned` is a note, because an approved obligation nobody has designed for is a backlog, which every project has and no gate should refuse — a fresh layer carries one of those before it carries an element.
A project that wants its cut closed before any code is written prices it up.

| Rule | What it reports |
|---|---|
| `element-cancelled` | An element carrying a requirement that is `superseded` or `withdrawn` |
| `carrier-unclaimed` | A file in the `code` field of an `implemented` or `partial` requirement that no element carries |
| `requirement-uncarried` | An `implemented` or `partial` requirement that no element carries |
| `element-empty` | An element in force that carries no requirement |
| `dependency-undeclared` | A dependency the code has — an import the checker reads, or an edge in `arch/edges.json` — that the element does not declare |
| `element-cycle` | Elements that depend on each other in a circle |
| `carrier-missing` | A path an element carries that does not exist |
| `requirement-unassigned` | A `deferred` requirement no element answers for — a note unless the project prices it up |
| `element-built` | A `proposed` element whose files all exist and whose requirements are all realized |
| `move-complete` | A move in force whose every path is at the receiving end and none at the leaving one |
| `move-orphan` | A path a move names that no element at either end carries |
| `dependency-forbidden` | A dependency the project forbade, declared by an element or had by the code |
| `interface-bypassed` | A part entered by a name its own `interface` does not state |
| `protects-uncarried` | A requirement an element protects and does not carry |
| `element-ungrounded` | An element carrying a requirement that rests on a `refuted` or `expired` hypothesis, where the project keeps a grounds register |
| `dependency-upward` | A dependency that runs against the order of groups declared under `layers`, declared by an element or had by the code |
| `import-forbidden` | A file importing a module the project forbade the part that carries it, where the language can be read |
| `carrier-contested` | A path more than one element in force carries, which therefore belongs to none of them |
| `dependency-unpermitted` | A dependency on a part from one the allow-list under `only` leaves out, declared by an element or had by the code |
| `unit-absent` | A unit a part names that the facts the project supplied do not hold |
| `unit-unclaimed` | A unit the facts hold that no part names |
| `link-undeclared` | A link the facts hold between two units whose parts declare no dependency |
A rule name the checker has published keeps its meaning: names are never renamed and never given to a different rule, because this file is written against them.

## What not to do

- Do not write a requirement identifier into a requirement file to point back at an element.
  The join lives here, in one direction.
- Do not edit `90-map.md`.
  It is generated; the next run overwrites it.
- Do not describe a part that does not exist yet without saying so in its status.
  A part being designed is `proposed` and is read as a design (see *Designing a cut*); `built` is a claim about today, and a plan written as one makes the layer describe a system nobody has.
- Do not use a move record in place of a decision.
  It says what changes hands; why the cut changes belongs in `specs/adr/`, which is what its `adr` points at.
- Do not cut the parts as finely as the file tree.
  If every module is an element, the layer says nothing the directory listing did not.
  A part inside another is not what this forbids — the advice is about granularity, not hierarchy, and a boundary that sits inside a directory is a part like any other, owning the files it names by the rule above.
