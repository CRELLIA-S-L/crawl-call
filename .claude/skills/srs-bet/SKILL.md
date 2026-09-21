---
name: srs-bet
description: Working with the grounds register — writing a hypothesis, staking a requirement on it with a bet, recording a measurement, and settling what happens when one is refuted. Invoke when the user wants to record why the product does something, when a measurement comes in, or when a hypothesis expires. For requirements themselves use srs and srs-new.
---

# Working with the grounds register

The format lives in `grounds/README.md` and is not restated here.
Read first: `grounds/README.md`, whole, in one call — it is the one file this procedure needs, and one read costs less than three.
Every record named to a person — a hypothesis, a bet, a requirement — is cited at its first mention from `python3 tools/srs_grounds.py --cite <ID>…` or `python3 tools/srs_view.py --cite <ID>…`, pasted as printed, never typed from the file.
The register answers what the specification does not — not what the system must do, but on what ground anyone decided it should: an ideology says who the product is for, a frame what it will not do for anyone, a hypothesis something about the world that could turn out to be false.
Only the last is measured.

## Writing a hypothesis

Section *`H` — hypothesis* and *The threshold* in `grounds/README.md`.

1. **What is claimed, and about whom.** A bounded population — "studios of five to fifty already tracking time", not "users" — or the claim is not falsifiable.
2. **What action would show it.** An action somebody takes — exports, returns, pays, invites — never an attitude; "studios need roll-up" cannot be false, and distrust the word *need*.
3. **What magnitude.** A proportion, a mean or a count; a claim with no size survives any result.
4. **The threshold**, `refuted_if`, in the grammar of *The threshold*, declared before the first measurement — afterwards every outcome is encouraging.
5. **What it is worth if true** — `impact`, as a business outcome, not a score; true and unimportant is the ordinary case this field tells apart.
6. **Term and owner** — a date, and a person rather than a team.
7. **The frames.** Read the frames the register holds first. Where one refuses the claim, add the row — `date`, `what was refused`, `who asked` — to that frame's journal and stop; the hypothesis is not written. Where none does, say so in a clause and go on. Nothing mechanical does this step.

Then judge what no checker reaches, and say what you found before the text is recorded — the population has an edge; the claim is an action, not an attitude; the magnitude is there and is not the threshold (a result between them refutes nothing — the claim survived and its size was wrong); no solution is smuggled into the need ("we need a comparison screen" is an answer, and measures whether the idea was popular). Where it is sound, say that too. A rewording goes through all four again; what may not be reworded is the threshold once a measurement has been taken — that is a new hypothesis, and the old one is retired.

## Choosing the class

Section *How a hypothesis is confirmed*. Ask how the number will be obtained, then check the class says the same: I — an instrument already running produces it; II — somebody runs an experiment; III — interviews, observation, judgement. Say where the declared measurement cannot produce a number the threshold compares against — class I over a quantity nothing instruments sits unconfirmed until its term runs out. Only class I is re-confirmed continuously; between measurements the honest status of II and III is `assumed`, with an owner, never `supported`.

## Staking a requirement on it

Section *`B` — bet*. One requirement, the hypotheses it rests on: `all_of` needed together, refute one and the ground is gone; `any_of` alternatives, the strongest carries it. Two independent sets of alternatives are two bets, and the checker asks whether that was deliberate.

Before the bet is recorded, read the hypothesis back against its own three numbers — the magnitude the statement claims, the threshold that refutes it, the sample it names — and say what you found even when nothing is wrong: they are meant to differ, and they must not differ by an order of magnitude ("three in ten" beside `proportion < 0.025` is a decimal point that moved, and passes every check).

A requirement that exists so the measurement can be taken — the event, the cohort tag, the attribution — is marked `instrument: yes` on its bet; it survives the refutation.

Nothing obliges a requirement to be named by a bet. **Stake only on hypotheses already in the register.** Where none carries the claim, offer a `U` declaration — this requirement rests on nothing, and why; it retires itself when a real bet appears — or offer nothing. Never write an `H`: for a person it costs a population, a threshold, a date and an owner asked about it next quarter; written by an agent it costs nothing, and `owner` commits a person who was never asked. If the claim looks worth making, say so and let them make it. How often the unclaimed are looked at is the dashboard's — `period` in `grounds/grounds-config.json`, `quarter` where nothing says otherwise.

## When a measurement lands

Section *Evidence*. Append a row; never edit one — a measurement that turned out wrong gets a later row saying so. The verdict is against `refuted_if`, not the magnitude, and is `supported` or `refuted` and nothing else; the other statuses are things that happen to a hypothesis. Do not write `refuted` because the value crossed the threshold — a sample of that size can miss by that much (`proportion < 0.25 at n >= 200` against `0.24` on 200 is two people); write what you believe and let the checker work out the interval — except for class III, where no interval is computed and the verdict is yours by name, bound only by the threshold's own words. A `mean` has no interval the row can carry, cannot be class I, and its verdict is argued in the rationale.

Confirmed is not ours: admission to the core is the maintainer's separate decision — absorb, spin off, refuse — put to them as its own question. A refusal is recorded with its reason and date.

## When a hypothesis is refuted

The requirements standing on it keep their code and lose their ground.

1. Read what stood on it — the bets name the requirements; one whose other grounds hold is not affected. Name each as `AGENTS.md` asks at first mention: requirements from `python3 tools/srs_view.py --cite <ID>…`, the hypothesis and its bets from `python3 tools/srs_grounds.py --cite <ID>…`.
2. Settle each with the maintainer, taking removal as the default.
3. "Somebody still uses it" is a new fact — something else holds it up; naming that hypothesis is the price of keeping the code.
4. Leave the instruments alone: a requirement its bet marks `instrument` is not put up for removal.
5. Cancel through the specification's usual procedure, not by deletion.

## What not to do

Section *What not to do* in `grounds/README.md`: no bet invented to make a number look better; no record edited to agree with a result — the dashboard is the one file a machine writes; no threshold moved once measurement began; no expiry deciding anything; no hypothesis written on somebody's behalf. Check with `python3 tools/srs_grounds.py`.
