# The grounds register

<!-- SRS-DD-0.20.1 — installed by the framework; --force overwrites local edits -->

A specification records what the system must do.
It does not record why anyone thought those were the right things to build.
That reasoning lives in rationale prose, which is asked for only where a requirement is not obvious and which no rule checks: delete a requirement's rationale and a strict run reports nothing at all.

This register is where that reasoning goes.
Most of it is claims about the world — who needs the thing, what they will pay for, what they do today instead.
Such a claim can be false, and that is the point of writing it in this shape: its falsification becomes visible where the code is, instead of being noticed years later by whoever wonders what a feature was for.

The rest is the ground no measurement touches: what the product is for, and what it will not do whatever anyone measures.
Three kinds of ground, one register, and the sections below say which is which.

The register is optional.
It is a sibling of `specs/`, never a part of it, and nothing here is ever written into a requirement file.

## When not to have this

Do not install the register where the basis of the work is fixed outside the project and does not move: avionics, a protocol implementation, a compliance obligation, a component whose contract is somebody else's specification.
There the requirement tree already carries everything, the hypotheses would be invented to fill the file, and a register of invented entries teaches every reader that the register is decoration.

The question worth asking before installing is not "could we write hypotheses down" but "will anybody measure them".
Where the answer is no, decline the layer and lose nothing.

## The core and the fog

The register describes a project as two things, and every reading on the dashboard is about the boundary between them.

**The core** is what the project holds and is willing to build on: its ideologies, and the hypotheses that have been confirmed *and* admitted.
Both words are load-bearing.
A measurement answers whether a hypothesis is true;
admission answers whether being true makes it this project's business, and only the first of those has a number.
A hypothesis that was confirmed and deliberately turned down is `declined`, and it stays in the register saying so — that record is what stops the same argument from being had again every six months.

Nothing sits in the core permanently.
A confirmation has a term, and when the term runs out the hypothesis leaves the core until somebody measures again.
This is why the confirmation classes are written down at all: a core assembled from hypotheses nobody can afford to re-measure has an expiry date it does not admit to.

**The fog** is everything else — every hypothesis `untested`, `assumed`, `expired` or `refuted`.
Most of a young project is fog, and should be.
The register does not exist to clear the fog.
It exists so that nobody mistakes it for the core, and so that when a hypothesis is refuted, the requirements standing on it can be found.

Ideologies live in the core and are never measured; they are what the hypotheses are measured *for*, and what settles which arguments count as weighty enough to reopen anything.
Frames are not in the core.
They are the boundary it may not cross whatever the core comes to hold, which is why no evidence can retire one.

## Map

```
grounds/
  README.md              this standard
  grounds-config.json    what each rule costs in this project
  00-ideology.md         I-NNN — what the system is for
  01-frames.md           F-NNN — the boundaries it will not cross
  02-unclaimed.md        U-NNN — requirements declared to rest on nothing
  03-bets.md             B-NNN — which requirement rests on which hypotheses
  10-h-<topic>.md        H-NNN — the hypotheses themselves, grouped by topic
  90-dashboard.md        generated; never edited by hand
```

## Identifier

`<KIND>-<NNN>`, three digits or more, numbered in tens so there is room to insert:
`H-010`, `B-020`, `I-010`; after `B-990` comes `B-1000`, written without a leading zero, and the tools order records by the number, so nothing already written is renamed and a kind never runs out.
The kinds are `I`, `F`, `H`, `B` and `U`, and the sections below say what each holds.

An identifier is permanent.
A cancelled entry keeps its number and says in its status that it was cancelled; the number is never given to anything else.
References outlive what they refer to — a refuted hypothesis is cited by the decision that removed the feature standing on it, and a hypothesis that was confirmed and turned down exists precisely so that the same argument returning in six months is answered from the record rather than from memory.

## The record

Every record in this register, of every kind, is written the same way:

````markdown
### H-010 — Studios lose time to manual roll-up

```yaml
status: assumed
class: III
population: studios of 5 to 50 people already tracking time
refuted_if: proportion < 0.30 at n >= 40
expires: 2027-03-01
owner: @kira
impact: about half the 2027 paid-subscription plan; nothing else drives it
```

At least three studios in ten spend more than an hour a week assembling
time reports by hand.

**Rationale.** Six of the eight discovery calls raised it unprompted, which
is why this is written down at all — and also why it is `class: III`: eight
calls are not a measurement.

| date | value | n | verdict | by |
|---|---|---|---|---|
| 2026-02-14 | 0.38 | 42 | supported | @kira |
````

A level-three heading with the identifier and a title; a fenced `yaml` block of flat keys whose values are scalars or bracketed lists; a statement; and, optionally, a rationale and a table.

The shape deliberately resembles a requirement block, so that whoever has read `specs/README.md` already knows how to read this.
It is not the same format.
Neither is obliged to follow the other's edge cases, and a later reader who merges them would be inventing a coupling this register was designed to avoid.

**A table is identified by its heading row, never by its position.** A record may carry more than one — a hypothesis its evidence, a frame its refusals and its amendments — and each is found by the column that only it has: `verdict` for evidence, `what was refused` for a frame's journal, `what changed` for an amendment.
Put them in any order; add a paragraph between them; nothing reads position.

Within a row, position is all there is: the evidence table's fourth cell is the verdict and its fifth is who gave it.
So **a row carries exactly the columns its heading declares** — one too few shifts everything after it, and the reading computed over the rest comes out wrong without looking wrong.

And a table this format names carries the heading this format declares for it, in that order and no other:

| Table | Heading |
|---|---|
| evidence | `date`, `value`, `n`, `verdict`, `by` |
| a frame's refusals | `date`, `what was refused`, `who asked` |
| an amendment | `date`, `what changed`, `why`, `territory it opens` |

A table carrying none of those distinctive columns is a table this format has not named, and it is nobody's business but the record's.

**Keys are added, never renamed.** Each kind below declares which of its keys are required and which are optional.
A key that is neither is not an error — that tolerance is what lets a later version of this format add a key without breaking a register written against an earlier one.
A rename or a removal has no such escape, so it does not happen.

## The kinds

### `I` — ideology

What the system is for, in one sentence somebody could disagree with.
A project has one or a few; a project with a dozen has a list of features.

| Key | | |
|---|---|---|
| `status` | required | `active`, `dissolved` |
| `admissible_arguments` | required | what counts as a reason to revise it |
| `adopted` | optional | date |

An ideology is not measured.
It is part of the core without ever having been confirmed, because it is what the hypotheses are confirmed *for*, and it changes only when enough of the ground under it has moved — which is a decision, taken deliberately, and recorded as one.

**`admissible_arguments` is what makes that decision governable.** An ideology that any argument can move is a preference; one that no argument can move is a slogan.
The set is declared by the ideology itself rather than fixed here, because what counts as weighty is the thing that describes an organisation most exactly — and revenue installed as the universal currency of persuasion is the mechanism that makes every organisation the same one.

An amendment is recorded as a row, and the last column is the one that matters:

```markdown
| date | what changed | why | territory it opens |
|---|---|---|---|
| 2027-01-12 | studios of 5–30 becomes 5–80 | three refusals in a quarter | teams with a delivery manager |
```

A revision is legitimate when it opens ground that was out of bounds before and names that ground in advance.
A quarter later somebody looks at whether anyone went there.
Nobody did, and it was not a revision — it was a capture, written up as learning.

**Widening the set costs something and narrowing it does not**, which is the asymmetry a self-amending rule needs to survive: capture runs through widening, one admissible argument admitting the next.
The record keeps enough history to notice a set that grew, and a growth arriving without an amendment naming what it opens is said out loud.
What the register cannot do is stop the other failure — a set narrowed until nothing can move the ideology at all — because the answer to that is a minimum no procedure may amend, and a file is a file.
That is the whole of what this layer promises about a minimum: an edit to it is visible, attributable and diffable, and never prevented.
Preventing it belongs to where the repository lives — a protected branch, a required review, a signed commit — and to the team, which the framework does not configure for any project: it gives the frame, and a project that needs the harder guard adds it where its other guards are and says so in the ideology's own text.

### `F` — frame

A boundary the project will not cross whatever the evidence says: we do not sell attention, we do not ship what we cannot support, we do not grow by making the thing worse.
A frame is not a hypothesis, because no measurement can refute it — refusing it is the whole point.

| Key | | |
|---|---|---|
| `status` | required | `active`, `retired` |
| `adopted` | optional | date |

A frame carries the same amendment table an ideology does, and for a sharper reason: a frame is amended by decision rather than by argument, and a new boundary has to be applied backwards over everything already accepted.
That sweep is the real content of the word, and the row is where anyone finds out it was owed.

A frame also carries a journal of what it has refused, as a table below the statement:

```markdown
| date | what was refused | who asked |
|---|---|---|
| 2026-05-02 | selling aggregate timing data to tool vendors | growth |
```

A frame that has refused nothing in a long time is not proof of virtue.
It usually means either that nobody is testing the boundary or that the boundary was drawn where nothing was ever going to happen, and both are worth knowing.

### `H` — hypothesis

A claim about the world that could turn out to be false.
Exactly one claim:
a hypothesis carries a single threshold and a single verdict, so "studios need time roll-up **and** will pay for reporting" has one `refuted_if` for two things, and a measurement that settles half of it settles nothing while the record says `supported`.
Nothing checks this and nothing can — it is held by whoever writes the statement and by whoever reads it back.

| Key | | |
|---|---|---|
| `status` | required | see below |
| `class` | required | `I`, `II`, `III` — how it is confirmed |
| `population` | required | who the claim is about, bounded |
| `refuted_if` | required | the threshold, in the grammar below |
| `expires` | required | date after which confirmation no longer counts |
| `owner` | required | who answers for measuring it |
| `impact` | required | what it is worth if true |
| `grade` | optional | `high`, `moderate`, `low`, `very-low` |
| `action` | optional | what is being done on its strength |
| `declined` | optional | `<date> — <reason>`, and only where the status is |

**How the claim is measured is prose, not a key.** The instrument — what is observed, on what, over which cohort — belongs in the record's statement, and the procedure for writing a hypothesis asks whoever chooses the class to check that the declared measurement can produce a number the threshold compares against.
Nothing checks that mechanically, and that is the trade:
a required field is paid on every record, this register is deliberately short, and a field a procedure runs without is a field it does not need.
The cost is that two hypotheses can carry the same threshold, be measured by entirely different means, and compare as equals.

`impact` is written as a business outcome and not as a score.
"About half the 2027 paid-subscription plan, and nothing else in the plan drives it" is an impact; "high" is a label that ranks against other labels and against nothing real.
It is declared apart from anything about confidence on purpose, because true and unimportant is an ordinary combination and the two questions have different answers — what a hypothesis is worth decides whether to measure it at all, and how well it is measured decides what may be done once it holds.

Statuses, and they are a lifecycle rather than a scale of confidence:

| | |
|---|---|
| `untested` | written down, nothing measured, nobody relying on it yet |
| `assumed` | taken on faith and being built on — an honest state, not a defect |
| `supported` | a measurement met the threshold |
| `refuted` | a measurement did not |
| `expired` | its term ran out before anyone re-confirmed it |
| `declined` | true, and deliberately not ours to act on |

**`grade` and `action` are a pair, and neither does anything alone.** The grade says how much the evidence is worth; the action says what is being done on it — shipping a release, committing a quarter, running one more experiment.
What binds them is `grades` in the configuration, which says which actions each grade permits.
A grade with nothing attached is a label;
an action beyond its grade is a decision resting on evidence that does not carry it, and the register says so rather than leaving a reader to notice.

The scale is borrowed from evidence-based medicine, where certainty is rated high, moderate, low or very low and the guidance is explicit that a strong recommendation should not rest on low certainty.
What counts as a permitted action at each grade is not borrowed and never will be: a project betting a quarter on low certainty and one betting a release are both coherent, and which you are is not this format's business.

**`declined` carries the date and the reason in one value**, in that order:

```yaml
declined: 2026-12-02 — the core is for studios, and corporate revenue would
```

One key rather than two because the halves are useless apart.
A refusal with no reason answers nothing the next time the question comes round; a refusal with no date cannot be told from one that predates everything that has changed since.

`declined` is the one worth explaining.
A hypothesis can be confirmed and still be refused: the thing is real, and this project is not going to be the one to do it.
Recording that is what stops the question from being argued from scratch every six months, and a declined hypothesis keeps its reason and the date the decision was taken.

### `B` — bet

Which requirement rests on which hypotheses.
The join lives here and only here: a requirement never says what it stands on, so the register says what stands on it, and the other direction is computed.

| Key | | |
|---|---|---|
| `status` | required | `active`, `retired` |
| `requirement` | required | one requirement identifier |
| `all_of` | optional | hypotheses that are all needed |
| `any_of` | optional | hypotheses of which any one suffices |
| `instrument` | optional | `yes` where the requirement exists to measure |

The two lists are not decoration.
`all_of` is a chain — refute any one of them and the ground is gone.
`any_of` is a set of alternatives — the strongest of them carries the requirement.
Collapsing the two into a single list produces a number that is wrong in the optimistic direction, which is the direction that does no good.

`instrument` marks the requirement that exists so the measurement can be taken at all — the event, the attribution, the cohort tag.
It sits on the bet rather than on the requirement because being an instrument is a fact about the pair: the same requirement can measure one hypothesis and rest on another.
What it buys is an exemption.
When the hypothesis is refuted, what was built on it is put up for removal and the instrument is not, because the instrument is what the next bet will be measured with, and a project that tears down its measuring after every refutation ends up unable to ask anything twice.

Where a requirement has two independent sets of alternatives, write two bets naming it.
The record *is* the group; there is no nesting and no group label.
Two bets on one requirement are also how the mistake looks, so the checker asks whether it was deliberate.

### `U` — unclaimed by declaration

A requirement that rests on no hypothesis, said out loud, with the reason.

| Key | | |
|---|---|---|
| `status` | required | `active`, `retired` |
| `requirement` | required | one requirement identifier |

The reason is the statement of the record, and a declaration without one is an error — an unexplained declaration is indistinguishable from a shrug.

## How a hypothesis is confirmed

Confirmation is not one thing.
Three classes, differing in what they cost and in what they are worth:

| Class | What it is | What it costs |
|---|---|---|
| I | passive: an instrument already running produces the number | nothing per re-confirmation |
| II | an intervention: somebody runs an experiment | a piece of work each time |
| III | outside the system: interviews, observation, judgement | a person's time and attention |

The class is a claim about the measurement, and it has to be true.
Declaring class I over a quantity nothing instruments produces a hypothesis that will sit unconfirmed until its term runs out with nothing saying why.

Only class I is affordable to re-confirm continuously, and that is the whole reason the classes are written down: a register that treats every hypothesis as permanently confirmable is a register whose expiry dates are fiction.

### The threshold

`refuted_if` is declared before the first measurement, in this grammar:

```
proportion|mean|count   <  <=  >  >=   <number>  at n >= <integer>
```

for example `proportion < 0.25 at n >= 200`, `mean < 4.0 at n >= 50`, `count < 3 at n >= 1`.
Those four comparisons and no others: a threshold written with `=` is a coincidence rather than a boundary, and one written in prose is a threshold nobody can apply twice the same way.

The kind of quantity comes first because it decides what a fair test is: a proportion, a mean and a count do not carry the same error, and error is the whole of what stands between a threshold and a verdict.

Moving a threshold after the first measurement is how a hypothesis stops being falsifiable.
The record keeps enough history to notice.

### Crossing a threshold is not the same as refuting

A measurement is not the truth; it is the truth plus however far a sample of that size can miss.
So a value below its threshold has refuted nothing until it is below by more than that.

Take `proportion < 0.25 at n >= 200` and a measurement of `0.24` on exactly
200. That is forty-eight people where fifty were wanted.
     Two people the other way and the hypothesis lives.
     The reading is `supported`, and a checker that called it `refuted` would be burying something requirements and code stand on because of a coin toss.

What the checker does with the error is decided by the kind:

| Kind | How far the measurement can miss | Class I |
|---|---|---|
| `proportion` | from the proportion and its denominator | yes |
| `count` | from the count itself | yes |
| `mean` | not knowable from the row — it needs the spread of the values behind the mean, and the row carries the mean and the sample size | no |

A `mean` therefore cannot be class I. Nothing is wrong with the hypothesis;
it simply cannot be re-confirmed by machine, so re-confirmation is a human act performed on purpose.
Declaring class I over one is reported.

Two things need no error calculation at all and are always reported: a row claiming `refuted` while its value sits on the *safe* side of its own threshold, and one claiming `refuted` on a sample smaller than the threshold's own `at n >=`.
Both are the record contradicting a sentence its own author wrote.

A class III measurement is a person's reading — interviews, observation, judgement — and its population is often small enough that the error above swallows any answer: at `n = 2` the interval reaches 0.575 whatever both people said, and would compel `supported` over a reader who concluded the opposite.
So for class III the checker computes no interval: the threshold is still declared before the measurement and still binds by its own words — a `refuted` on the safe side of the bound or below the gate is still the record contradicting itself — but whether the reading crossed the line is the reader's verdict, and the reader is named.

A row that cannot be compared at all is reported before any of that, and the message says which of these it is:

- a `value` or an `n` that is not a number, including `nan` and `inf`
- a sample of nought or less, which measures nothing
- a `proportion` outside nought to one
- a `count` that is fewer than none, or has a fraction in it
- a `verdict` that is neither `supported` nor `refuted`

None of these is a judgement about the hypothesis.
They are the ways a row can fail to be a measurement, and they are errors because a register is typed by hand and a slipped decimal point should not be quietly weighed against a threshold.

### Evidence

Evidence is a table under the record, one row per measurement:

```markdown
| date | value | n | verdict | by |
|---|---|---|---|---|
| 2026-02-14 | 0.38 | 42 | supported | @kira |
| 2026-08-01 | 0.19 | 210 | refuted | telemetry |
```

Rows are appended.
A row is never edited and never removed — a measurement that turned out to be wrong gets a later row saying so, because a register whose inconvenient rows disappear is a register that only ever agrees with the present.

**Where a measurement came from is not recorded, and the consequence is yours to carry.** Two hypotheses confirmed off the same event stream are not two independent confirmations, and nothing here can tell them apart: the table has no column for the source, and the reading a bet gives — the weakest of what its `all_of` requires — combines what several hypotheses give a requirement without asking whether their numbers share a cause.
A requirement standing on three hypotheses all measured from one stream therefore reads exactly as well grounded as one standing on three separate readings, and it is not.
Whoever reads the dashboard is the one who knows.

This is a stated limit rather than an oversight: a column costs every row of every register forever, and no project has yet needed the reading it would buy.
A key on the hypothesis can be added later, when one does, because the format may gain keys and may not lose them.

## Requirements no hypothesis stands behind

The most useful thing this register produces is the list of requirements that rest on nothing anybody wrote down.
That list is a reading of the product, not a defect report: it says the system acquired something nobody can now say why it has.

It reads the requirements that have not been cancelled.
One that was withdrawn or superseded rests on no hypothesis and never will, and nothing of the system rests on it — counted in, it would sit on this list forever and its links would keep adding to somebody else's weight.
A bet naming no hypothesis at all does not take a requirement off the list either: both of its lists are optional, so such a record is well-formed and stands the requirement on nothing, which is what the list is for.

**No rule of this layer requires a requirement to be named by a bet, and none ever will.** Where a link is mandatory it gets invented, and an invented link is worse than an absent one because it looks like knowledge.
Every traceability practice that has demanded completeness has destroyed exactly this signal — once everything traces to something, the tracing confirms only that somebody drew a line.

What may be asked of an author is the declaration: one `U` record naming the requirement and saying why it stands alone.
The declaration retires itself the moment a real bet appears, and the checker says so.

The asymmetry is deliberate and is the reason the register works.
Declaring is a line and a sentence.
Inventing a bet means inventing a hypothesis — a bounded population, a quantity, a threshold, a date and a named owner — that somebody will be asked about next quarter.
It is cheaper to be honest, which is the only arrangement that survives contact with a deadline.

**That price is charged to people, and an agent is not sent the bill.** The same record costs it nothing; a plausible population and a round threshold arrive on demand, and what comes out passes every check here, because the checks are on the shape of a record and the invention is shaped correctly.
`owner` is where it is plainest: it names who answers for measuring the claim, and an agent that fills it in has committed a person who was never asked.

So an agent working on this register stakes a requirement only on hypotheses already in it.
Where none of them carries the claim, what it may offer is a `U` declaration or nothing — never a new `H`.
Both of those add no claim about the world; a hypothesis does, and a claim about the world is somebody's to make.

## Configuration

`grounds/grounds-config.json` — its presence is what says this project carries the register.

| Key | Default | |
|---|---|---|
| `rules` | `{}` | What a finding costs: `warn` (the default, and what `--strict` fails on), `report` (said, never fatal), `off` (not said at all). Keys are rule names; `srs_grounds.py` lists them when you name one it does not know |
| `grades` | `{}` | Which actions each grade permits: `{"high": ["release", "quarter"], "low": ["experiment"]}`. A grade absent from the map permits anything, which is what an empty map means for every grade |
| `period` | `"quarter"` | The unit the dashboard counts arrivals in: `month`, `quarter` or `year` |
| `confidence` | `0.95` | How sure a measurement has to be before it refutes: `0.9`, `0.95` or `0.99`. Higher keeps doubtful hypotheses alive longer |

Errors are not in this table and cannot be lowered: a malformed or repeated identifier, a missing required key, a bet naming a requirement that does not exist, and a declaration with no reason are all refusals to read the register, not opinions about it.

## The dashboard

`grounds/90-dashboard.md` is generated from the records and committed, so that a diff shows the readings move and a gate can compare what is committed against what the records say now.
It is never edited by hand — a summary somebody can edit is a summary that will be edited into agreement with what its author wishes were true.

**One reading counts by period, and the period is yours.** How many requirements arrived standing on no hypothesis is a rate rather than a total: one is noise and is meant to be, and five in a period with four of them in one area is the product having become something nobody said out loud.
What counts as "lately" is not the same for a product shipping weekly and one shipping twice a year, so `period` in the configuration says which unit to use — `month`, `quarter` or `year`, and `quarter` where nothing says otherwise.

Periods are calendar ones and never a window measured back from today.
This file is committed and compared against a fresh run, so a boundary that moved every night would fail the gate every morning while saying nothing new.
The dashboard names the unit it used in the section itself, so nobody has to look here to know what a row counts.

## Checking

```
python3 tools/srs_grounds.py            check and rewrite the dashboard
python3 tools/srs_grounds.py --no-write check only
python3 tools/srs_grounds.py --strict   treat warnings as errors
python3 tools/srs_grounds.py --cite ID… name records to a person: identifier, title, file, status
```

Exit 0 where nothing was found and, under `--strict`, no warning either; 1 on errors, or on warnings under `--strict`; 2 where it could not run at all.

The requirement model is read by running the viewer, not by parsing `specs/`.
Where the specification is unreadable the register says so and reports what it still can, rather than dying on somebody else's configuration.

## What not to do

- **Do not invent a bet to make a number look better.**
  The unclaimed list is the point, not the debt.
- **Do not edit an evidence row.**
  Append a new one.
- **Do not move a threshold once measurement has begun.**
  Write a new hypothesis and retire the old one, so that both are visible.
- **Do not write a hypothesis that cannot be false.**
  "Studios need better reporting" is an attitude.
  "At least a quarter of them export to a spreadsheet weekly" is a hypothesis.
- **Do not write the solution into the hypothesis.**
  "We need a comparison screen" tests whether the idea was popular.
  The hypothesis is about the need.
- **Do not let a tool change a record.**
  Everything in here is authored.
  The dashboard is the one file written by a machine, and the only one.
- **Do not have an agent write a hypothesis.**
  It can propose a bet on one that exists, or a declaration that there is none.
  A population, a threshold and an owner are claims a person makes and answers for.
