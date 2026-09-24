#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.20.1 — the framework release this file came from
"""The grounds checker: reads the register beside specs/ and reports on it.

    python3 tools/srs_grounds.py             check and rewrite 90-dashboard.md
    python3 tools/srs_grounds.py --no-write  check only
    python3 tools/srs_grounds.py --strict    treat warnings as errors
    python3 tools/srs_grounds.py --blast P…  what the requirements these
                                             files belong to are staked on

The register's format is described in grounds/README.md — that file is the
normative one; this script only enforces it. Standard library only,
compatible with Python 3.9.

The requirement model is read by running tools/srs_view.py as a subprocess
rather than importing the checker: an optional subsystem must not die on the
mandatory one's configuration before it can say anything of its own, and a
register whose specification is broken still has plenty to report.
"""

# annotation removed on install

import datetime
import json
import math
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import srs_parse                                        # noqa: E402
except ImportError:
    sys.stderr.write(
        "tools/srs_parse.py: missing — the grounds checker reads the record "
        "shape through it, and the two travel together. Copy it beside this "
        "file from the framework clone, or re-run tools/srs_init.py to "
        "refresh the tooling.\n")
    sys.exit(2)

# Re-exported: the number lives in srs_parse, the one file this checker
# and the specification checker both must have beside them (ADR-0021).
__version__ = srs_parse.__version__

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GROUNDS = os.path.join(ROOT, "grounds")
CONFIG = os.path.join(GROUNDS, "grounds-config.json")
# annotation removed on install
# The only path this tool ever writes. Everything else it does is read.
DASHBOARD = os.path.join(GROUNDS, "90-dashboard.md")
VIEWER = os.path.join(ROOT, "tools", "srs_view.py")

# Files in grounds/ that hold no records.
SKIP_FILES = {"README.md", "90-dashboard.md"}

# annotation removed on install
# The same broad net the specification checker uses, in this format's
# grammar: anything ID-shaped is captured and judged loudly afterwards.
RE_HEADING = re.compile(
    r"^###\s+([A-Za-z][A-Za-z0-9]*-\d+(?:-[A-Za-z0-9]+)*)"
    r"\s*(?:[—–-]\s*)?(.*)$")
RE_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
# The threshold grammar the standard declares, and the four comparisons
# it names. A threshold nothing can apply twice the same way is not one.
RE_THRESHOLD = re.compile(
    r"^(proportion|mean|count)\s+(<=|>=|<|>)\s+"
    r"(\d+(?:\.\d+)?)\s+at\s+n\s*>=\s*(\d+)$")

# annotation removed on install
# The kinds the format defines, and the keys each declares. What a record
# means is the standard's business; this is the standard's shape as code.
KINDS = {"I": "ideology", "F": "frame", "H": "hypothesis",
         "B": "bet", "U": "unclaimed"}
# annotation removed on install
# One number, one meaning, forever: the checker's part of that promise is
# that no two records in the register carry the same one.
RE_ID = re.compile(r"^(%s)-(%s)$" % ("|".join(sorted(KINDS)), srs_parse.NUMBER))   # annotation removed on install

# annotation removed on install
REQUIRED = {
    "I": ("status", "admissible_arguments"),
    "F": ("status",),
    "H": ("status", "class", "population", "refuted_if", "expires",
          "owner", "impact"),
    "B": ("status", "requirement"),
    "U": ("status", "requirement"),
}

# annotation removed on install
CLASSES = ("I", "II", "III")
GRADES = ("high", "moderate", "low", "very-low")
# `declined` carries both halves because they are useless apart: a refusal
# with no reason answers nothing next time, one with no date cannot be told
# from one that predates everything since.
RE_DECLINED = re.compile(r"^(\d{4}-\d{2}-\d{2})\s+[—–-]\s+(\S.*)$")
STATUSES = {
    "I": ("active", "dissolved"),
    "F": ("active", "retired"),
    "H": ("untested", "assumed", "supported", "refuted", "expired",
          "declined"),
    "B": ("active", "retired"),
    "U": ("active", "retired"),
}

# How much ground a hypothesis provides, weakest first. `declined` is beside
# `refuted` on purpose: the core looked at it and said no, so a requirement
# standing on it stands on something nobody agreed to carry.
STRENGTH = {"refuted": 0, "declined": 0, "expired": 1, "untested": 2,
            "assumed": 3, "supported": 4}
DEBT_STATUSES = ("refuted", "expired", "assumed")
# annotation removed on install
# What the specification calls a cancelled requirement. The readings
# below range over the requirements that have not been cancelled, which
# is the reading the viewer's gap list and the specification checker's
# unclaimed-file rule already take — one file described two ways in one run
# is worse than either answer.
CANCELLED = ("withdrawn", "superseded")

# annotation removed on install
# Published names: a name here keeps its meaning forever, and is never given
# to a different rule.
RULES = ("bet-cancelled", "hypothesis-expired", "bet-duplicated",
         "declaration-superfluous", "threshold-moved", "evidence-dropped",
         "relied-on-untested", "never-measured", "verdict-unattributed",
         "action-beyond-grade", "declined-leftover", "action-without-grade",
         "class-untestable", "arguments-widened", "widening-undisclosed")
SEVERITIES = ("warn", "report", "off")

# annotation removed on install
# What counts as "lately" is the project's: a product shipping weekly and
# one shipping twice a year do not share a unit. Calendar periods only —
# a window measured back from today would move this file every night.
PERIODS = ("month", "quarter", "year")

# annotation removed on install
# A criterion that allows for error has to be told how much, and no answer
# is right everywhere. Named levels rather than a free number: a confidence
# somebody typed as 0.973 came from nowhere and cannot be discussed.
CONFIDENCES = (0.9, 0.95, 0.99)
# One-sided, because a threshold asks whether the truth is past it, not
# whether it sits inside a band. Two-sided quantiles here would demand more
# of a measurement than the sentence its author wrote does.
Z_ONE_SIDED = {0.9: 1.2816, 0.95: 1.6449, 0.99: 2.3263}

# annotation removed on install
# What a measurement's error is depends on what was measured. A mean's does
# not follow from anything the row carries — it needs the spread behind the
# mean, and the row holds the mean and the sample size. So a mean closes
# class I rather than falling back to a comparison that refutes on noise.
TESTABLE_KINDS = ("proportion", "count")

DEFAULTS = {"rules": {}, "grades": {}, "period": "quarter",
            "confidence": 0.95}


def period_of(date, period):
    """The calendar period a date falls in, as its own label."""
    if period == "month":
        return "%d-%02d" % (date.year, date.month)
    if period == "year":
        return "%d" % date.year
    return "%d-Q%d" % (date.year, (date.month - 1) // 3 + 1)


def _config_fail(message):
    sys.stderr.write("grounds/grounds-config.json: %s\n" % message)
    sys.exit(2)


def load_config():
    # annotation removed on install
    cfg = dict(DEFAULTS)
    if not os.path.exists(CONFIG):
        return cfg
    try:
        with open(CONFIG, "r", encoding="utf-8") as handle:
            raw = json.load(handle)
    except ValueError as exc:
        _config_fail("invalid JSON: %s" % exc)
    if not isinstance(raw, dict):
        _config_fail("the top level must be a JSON object")
    rules = raw.get("rules", {})
    if not isinstance(rules, dict):
        _config_fail("rules must be an object of rule name to severity")
    for name, severity in sorted(rules.items()):
        if name not in RULES:
            _config_fail("unknown rule %r; known rules are: %s"
                         % (name, ", ".join(RULES)))
        if severity not in SEVERITIES:
            _config_fail("rule %r: severity must be one of %s"
                         % (name, ", ".join(SEVERITIES)))
    cfg["rules"] = rules
    # annotation removed on install
    # What a weakly supported hypothesis may be used for is a matter of
    # appetite, so the map is the project's and the format only says it
    # exists. A grade absent from it permits anything.
    grades = raw.get("grades", {})
    if not isinstance(grades, dict):
        _config_fail("grades must be an object of grade to permitted actions")
    for grade, actions in sorted(grades.items()):
        if grade not in GRADES:
            _config_fail("unknown grade %r; the format defines: %s"
                         % (grade, ", ".join(GRADES)))
        if not isinstance(actions, list) \
                or not all(isinstance(a, str) and a for a in actions):
            _config_fail("grade %r: permitted actions must be a list of "
                         "non-empty strings" % grade)
    cfg["grades"] = grades
    period = raw.get("period", DEFAULTS["period"])
    if period not in PERIODS:
        _config_fail("period must be one of %s" % ", ".join(PERIODS))
    cfg["period"] = period
    # annotation removed on install
    confidence = raw.get("confidence", DEFAULTS["confidence"])
    if confidence not in CONFIDENCES:
        _config_fail("confidence must be one of %s"
                     % ", ".join(str(c) for c in CONFIDENCES))
    cfg["confidence"] = confidence
    return cfg


# annotation removed on install
def wilson_bounds(value, n, z):
    """Where a proportion's truth may sit, given `value` observed out of n.

    Wilson's interval and not value ± z·sqrt(pq/n): the plain one runs off
    the end of [0, 1] near zero and one, which is exactly where a threshold
    on a proportion tends to be drawn.
    """
    denominator = 1.0 + z * z / n
    centre = (value + z * z / (2 * n)) / denominator
    half = z * math.sqrt(value * (1 - value) / n
                         + z * z / (4 * n * n)) / denominator
    return centre - half, centre + half


def poisson_cdf(k, rate):
    """P(X <= k) for a Poisson of this rate.

    Summed through logarithms so that a large rate loses the first terms to
    underflow one at a time instead of the whole sum at once.
    """
    if k < 0:
        return 0.0
    total, log_term = 0.0, -rate
    for i in range(int(k) + 1):
        if i:
            log_term += math.log(rate) - math.log(i)
        total += math.exp(log_term)
    return min(1.0, total)


# annotation removed on install
def poisson_bounds(k, confidence):
    """Where a count's truth may sit, given k events observed.

    Exact rather than k ± z·sqrt(k), because counts in a register of
    hypotheses are small and the approximation is worst there: it puts the
    bound for nought observations at nought, which would read as certainty
    from the one measurement that carries none.
    """
    if k > POISSON_EXACT_TO:
        # Far from nought the normal approximation is within two tenths of a
        # percent of the exact bound, and the exact one costs a term per
        # event counted. A register recording millions of events would wait
        # half a minute to be told what a square root answers at once.
        spread = Z_ONE_SIDED[confidence] * math.sqrt(k)
        return k - spread, k + spread

    tail = 1.0 - confidence

    def solve(target, at):
        low, high = 0.0, max(20.0, k + 20.0 * math.sqrt(k + 1.0))
        for _ in range(80):
            middle = (low + high) / 2
            if poisson_cdf(at, middle) > target:
                low = middle
            else:
                high = middle
        return (low + high) / 2
    return (0.0 if k == 0 else solve(1.0 - tail, k - 1)), solve(tail, k)


# Beyond this many events the exact sum is not worth its terms; see
# poisson_bounds. Chosen where the two methods already agree to a tenth of
# a percent, so the seam is invisible in any message either produces.
POISSON_EXACT_TO = 1000


# annotation removed on install
# A register is written by hand, so a typo is ordinary input rather than an
# attack. Every one of these used to reach the arithmetic and either crash
# it or be silently judged, which for a checker is the same failure: it
# stops being runnable on the file somebody actually has.
def measurement_fault(kind, value, n):
    """Why this row cannot be compared to a threshold of this kind, or None."""
    for name, number in (("value", value), ("n", n)):
        if math.isnan(number) or math.isinf(number):
            return "%s %r is not a number anything can be compared against" \
                % (name, number)
    if n <= 0:
        return "a sample of %g measures nothing" % n
    if kind == "proportion" and not 0.0 <= value <= 1.0:
        return "a proportion of %g is outside nought to one" % value
    if kind == "count" and value < 0:
        return "a count of %g is fewer than none of them" % value
    if kind == "count" and value != int(value):
        return "a count of %g is not a whole number of things" % value
    return None


# annotation removed on install
# The two words a measurement may end in. A record's `status` has six, and
# four of them are things that happen to a hypothesis rather than things a
# measurement found.
VERDICTS = ("supported", "refuted")


def _crosses(op, edge, bound):
    """Whether a value sits past a threshold, the way the threshold asks."""
    if op == "<":
        return edge < bound
    if op == "<=":
        return edge <= bound
    if op == ">":
        return edge > bound
    return edge >= bound


# annotation removed on install
def verdict_owed(threshold, value, n, cfg, interval=True):
    """The verdict a measurement compels, with the phrase that says why.

    `(None, None)` where the row does not compel one: the kind carries no
    error the row can produce, and the raw value is on the refuting side, so
    whether it refuted is exactly the question nothing here can answer.
    With `interval` off — a class III reading — the two contradictions of
    the threshold's own words are still compelled, a sample smaller than
    its gate and a value on its safe side, and nothing beyond them is: how
    far a person's reading of two people can miss is not this arithmetic's.
    """
    kind, op, raw_bound, raw_gate = threshold.groups()
    bound, gate = float(raw_bound), int(raw_gate)
    if n < gate:
        return VERDICTS[0], ("its sample of %g is smaller than the "
                             "threshold's own at n >= %d" % (n, gate))
    if not _crosses(op, value, bound):
        return VERDICTS[0], ("its value of %g is on the safe side of %s %g"
                             % (value, op, bound))
    if kind not in TESTABLE_KINDS or not interval:
        return None, None
    if kind == "proportion":
        low, high = wilson_bounds(value, n, Z_ONE_SIDED[cfg["confidence"]])
    else:
        low, high = poisson_bounds(value, cfg["confidence"])
    edge = high if op in ("<", "<=") else low
    if _crosses(op, edge, bound):
        return VERDICTS[1], ("at %g%% confidence the truth behind %g is no "
                             "further than %.4g, which is still %s %g"
                             % (cfg["confidence"] * 100, value, edge, op,
                                bound))
    return VERDICTS[0], ("%g is %s %g by less than a sample of %g can miss "
                         "by: at %g%% confidence the truth reaches %.4g"
                         % (value, op, bound, n, cfg["confidence"] * 100,
                            edge))


def rule_finding(warnings, reports, cfg, rule, text):
    """Files a tunable finding at the severity this project chose."""
    severity = cfg["rules"].get(rule, "warn")
    if severity == "off":
        return
    line = "%s [%s]" % (text, rule)
    (warnings if severity == "warn" else reports).append(line)


def collect_files():
    # annotation removed on install
    """Every record file in the register, subdirectories included.

    The layout in the standard is flat, and a register that grows a folder
    is not thereby exempt: `every record in it` has to mean every one, or
    a file one directory down goes unread with nothing said about it.
    """
    out = []
    if not os.path.isdir(GROUNDS):
        return out
    for current, dirs, files in os.walk(GROUNDS):
        dirs.sort()
        for name in sorted(files):
            if not name.endswith(".md") or name in SKIP_FILES:
                continue
            full = os.path.join(current, name)
            out.append((full, os.path.relpath(full, ROOT)))
    return sorted(out, key=lambda pair: pair[1])


def read_records(errors):
    # annotation removed on install
    records = {}
    seen = {}
    for full, rel in collect_files():
        try:
            with open(full, "r", encoding="utf-8") as handle:
                text = handle.read()
        except (OSError, UnicodeDecodeError) as exc:
            errors.append("%s — cannot read the file: %s" % (rel, exc))
            continue
        for entry in srs_parse.parse_entries(text, rel, errors, RE_HEADING):
            match = RE_ID.match(entry.id)
            if not match:
                errors.append("%s — identifier does not match <KIND>-<NNN> "
                              "with a kind the standard defines (%s)"
                              % (entry.where, ", ".join(sorted(KINDS))))
                continue
            entry.kind = match.group(1)
            if entry.id in seen:
                errors.append("%s — %s is already used at %s"
                              % (entry.where, entry.id, seen[entry.id]))
                continue
            seen[entry.id] = entry.where
            records[entry.id] = entry
    return records


def read_model():
    """The requirement model, or None with the reason it could not be read."""
    if not os.path.exists(VIEWER):
        return None, "tools/srs_view.py is not here"
    try:
        done = subprocess.run([sys.executable, VIEWER, "--json"],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as exc:
        return None, "could not run tools/srs_view.py: %s" % exc
    if done.returncode != 0:
        detail = done.stderr.decode("utf-8", "replace").strip().split("\n")
        return None, "tools/srs_view.py exited %d: %s" % (
            done.returncode, detail[-1] if detail else "no output")
    try:
        return json.loads(done.stdout.decode("utf-8")), None
    except ValueError as exc:
        return None, "tools/srs_view.py produced unreadable JSON: %s" % exc


def history_of(paths):
    # annotation removed on install
    """Past revisions of the register's record files, oldest first.

    Returns (revisions, problem). Where `problem` is a sentence the
    history could not be read, and the rules standing on it are not run
    and not passed — a history nobody can read is also a history nobody
    can audit, and a reader told nothing assumes the check ran.
    """
    def git(*args):
        return subprocess.check_output(
            ["git", "-C", ROOT] + list(args),
            stderr=subprocess.DEVNULL).decode("utf-8", "replace")

    try:
        if git("rev-parse", "--is-shallow-repository").strip() == "true":
            return [], "the clone is shallow, so earlier revisions are absent"
        listed = git("log", "--format=%H", "--", *paths).split()
    except (OSError, subprocess.CalledProcessError):
        return [], "this is not a repository, or git could not read it"

    revisions = []
    for rev in reversed(listed):                  # oldest first
        texts = {}
        for path in paths:
            try:
                texts[path] = git("show", "%s:%s" % (rev, path))
            except (OSError, subprocess.CalledProcessError):
                continue                          # not in the tree yet
        revisions.append(texts)
    return revisions, None


def hypotheses_in(text, path):
    """The hypothesis records of one file's text, by identifier."""
    out = {}
    for entry in srs_parse.parse_entries(text, path, [], RE_HEADING):
        match = RE_ID.match(entry.id)
        if match and match.group(1) == "H":
            out[entry.id] = entry
    return out


def ideologies_in(text, path):
    """The ideology records of one file's text, by identifier."""
    out = {}
    for entry in srs_parse.parse_entries(text, path, [], RE_HEADING):
        match = RE_ID.match(entry.id)
        if match and match.group(1) == "I":
            out[entry.id] = entry
    return out


def check_history(records, cfg, warnings, reports):
    # annotation removed on install
    """The rules that read the register's history rather than its files.

    Replayed from one walk: the ordering of a threshold against the
    first measurement recorded under it, the evidence rows that were
    once there, and the growth of what may move an ideology.
    """
    paths = [rel for _full, rel in collect_files()]
    revisions, problem = history_of(paths)
    if problem:
        reports.append(
            "the register's history could not be read (%s); the "
            "threshold-moved, evidence-dropped, arguments-widened and "
            "widening-undisclosed rules did not run, which is not the same "
            "as passing" % problem)
        return

    threshold = {}        # id -> (value, revision index, ever changed)
    first_measured = {}   # id -> index of the revision that first showed one
    rows_ever = {}        # id -> {row: index first seen}
    arguments = {}        # id -> the admissible set as last seen
    amendments = {}       # id -> {amendment row: index first seen}
    widened = {}          # id -> [(what was added, whether it was disclosed)]
    for index, texts in enumerate(revisions):
        for path, text in sorted(texts.items()):
            for hid, entry in sorted(hypotheses_in(text, path).items(), key=lambda kv: srs_parse.id_key(kv[0])):
                value = entry.fields.get("refuted_if")
                if hid not in threshold:
                    threshold[hid] = (value, index, False)
                elif threshold[hid][0] != value:
                    threshold[hid] = (value, index, True)
                rows = [tuple(r) for r in table_with(entry, "verdict")]
                if rows and hid not in first_measured:
                    first_measured[hid] = index
                for row in rows:
                    rows_ever.setdefault(hid, {}).setdefault(row, index)
            # annotation removed on install
            for iid, entry in sorted(ideologies_in(text, path).items(), key=lambda kv: srs_parse.id_key(kv[0])):
                value = entry.fields.get("admissible_arguments")
                admits = frozenset(value if isinstance(value, list)
                                   else [value] if value else [])
                rows = [tuple(r) for r in table_with(entry, "what changed")]
                # Read before the rows are folded in below: what makes a
                # widening disclosed is an amendment arriving *with* it, and
                # one written later describes a set that had already moved.
                disclosed = any(len(row) >= 4 and row[3].strip()
                                and row not in amendments.get(iid, {})
                                for row in rows)
                added = admits - arguments[iid] if iid in arguments else None
                if added:
                    widened.setdefault(iid, []).append(
                        (sorted(added), disclosed))
                arguments[iid] = admits
                for row in rows:
                    amendments.setdefault(iid, {}).setdefault(row, index)

    # A record that is simply gone takes its measurements with it, which is
    # the easiest way to make an inconvenient one disappear and the one the
    # loop below cannot see: it walks what is here.
    for hid in sorted(rows_ever, key=srs_parse.id_key):
        if hid not in records:
            rule_finding(warnings, reports, cfg, "evidence-dropped",
                         "grounds — %s recorded %d measurement(s) and is no "
                         "longer in the register at all; an entry is "
                         "retired in a status that says so, never deleted"
                         % (hid, len(rows_ever[hid])))

    # annotation removed on install
    for iid in sorted(widened, key=srs_parse.id_key):
        if iid not in records:
            continue
        rec = records[iid]
        for added, disclosed in widened[iid]:
            rule_finding(warnings, reports, cfg, "arguments-widened",
                         "%s — %s widened what may move it, admitting %s; "
                         "widening is the move a capture is made of, and "
                         "this layer prices it rather than refusing it"
                         % (rec.where, iid, ", ".join(added)))
            if not disclosed:
                rule_finding(warnings, reports, cfg, "widening-undisclosed",
                             "%s — %s widened without an amendment naming "
                             "the territory it opens; named in advance that "
                             "is a prediction somebody can go and check, "
                             "named afterwards it is whatever happened"
                             % (rec.where, iid))

    for hid in sorted(records, key=srs_parse.id_key):
        rec = records[hid]
        if rec.kind != "H":
            continue
        moved = threshold.get(hid)
        measured = first_measured.get(hid)
        # `>=` and not `>`: inside one commit there is no ordering, so a
        # threshold changed in the very commit that records the first
        # measurement is the abuse done in one step instead of two. The
        # `ever changed` flag is what keeps a hypothesis born with its
        # first measurement out of this — declaring is not moving.
        if moved and moved[2] and measured is not None and moved[1] >= measured:
            rule_finding(warnings, reports, cfg, "threshold-moved",
                         "%s — %s had its threshold changed after the first "
                         "measurement was recorded under it; a threshold "
                         "named after the result turns every outcome into an "
                         "encouraging one" % (rec.where, hid))
        now = {tuple(r) for r in table_with(rec, "verdict")}
        for row in sorted(rows_ever.get(hid, {})):
            if row not in now:
                rule_finding(warnings, reports, cfg, "evidence-dropped",
                             "%s — %s once recorded the measurement %s and "
                             "no longer does; the older one is what the "
                             "newer is a change from"
                             % (rec.where, hid, " | ".join(row)))


def statement_of(entry):
    """The record's prose, with any table below it left out."""
    lines = []
    for line in entry.body:
        if line.lstrip().startswith("|"):
            break
        lines.append(line)
    return "\n".join(lines).strip()


# annotation removed on install
# The tables this format names, each by the one column only it has, and the
# heading it must then carry. A table with none of these markers is one the
# format has not named and is left alone.
NAMED_TABLES = {
    "verdict": ["date", "value", "n", "verdict", "by"],
    "what was refused": ["date", "what was refused", "who asked"],
    "what changed": ["date", "what changed", "why", "territory it opens"],
}


def tables_of(entry):
    """Every table under a record, as (heading cells, rows).

    A record can carry more than one — a frame keeps its refusals and its
    amendments — so tables are told apart by their heading and never by
    their order, which is what the standard promises a reader.
    """
    out = []
    heading, rows = None, []
    for line in entry.body:
        text = line.strip()
        cells = ([c.strip() for c in text.strip("|").split("|")]
                 if text.startswith("|") else None)
        if cells is None:
            if heading is not None:
                out.append((heading, rows))
            heading, rows = None, []
            continue
        if all(set(c) <= set("-: ") for c in cells):
            continue                      # the separator under a heading
        if heading is None:
            heading = cells
            continue
        rows.append(cells)
    if heading is not None:
        out.append((heading, rows))
    return out


def table_with(entry, column):
    """The rows of the record's table that has this column, or nothing."""
    for heading, rows in tables_of(entry):
        if column in heading:
            return rows
    return []


def as_date(value):
    """The value as a date, or None. A shape that passes and a date that
    cannot exist are the same answer here — neither can be compared."""
    if not isinstance(value, str) or not RE_DATE.match(value):
        return None
    try:
        return datetime.date.fromisoformat(value)
    except ValueError:
        return None


def as_list(value):
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def active(rec):
    return rec.fields.get("status") == "active"


# annotation removed on install
# A bet naming no hypothesis stands its requirement on nothing. The
# format leaves both lists optional, so the record is legal — and read
# as a claim it would take the requirement off the one list this layer
# exists to produce. That is the invented link `grounds/README.md`
# warns about, in the shape that costs an agent least to write: it
# arrives well-formed and passes every check on the shape.
def stakes(rec):
    """Whether this bet actually stands its requirement on something."""
    return bool(as_list(rec.fields.get("all_of"))
                + as_list(rec.fields.get("any_of")))


# annotation removed on install
def live(entry):
    """Whether a requirement of the model has not been cancelled."""
    return entry.get("status") not in CANCELLED


def validate(records, model, model_error, cfg):
    # annotation removed on install,
    # annotation removed on install,
    # annotation removed on install,
    # annotation removed on install
    errors, warnings, reports = [], [], []
    today = datetime.date.today()

    hyps = {i: r for i, r in records.items() if r.kind == "H"}
    bets = {i: r for i, r in records.items() if r.kind == "B"}
    decls = {i: r for i, r in records.items() if r.kind == "U"}

    for rid in sorted(records, key=srs_parse.id_key):
        rec = records[rid]
        for key in REQUIRED[rec.kind]:
            if key not in rec.fields:
                errors.append("%s — %s is missing the required key %r"
                              % (rec.where, rid, key))
        status = rec.fields.get("status")
        if status is not None and status not in STATUSES[rec.kind]:
            errors.append(
                "%s — %s carries status %r, which the format does not define "
                "for a %s (%s)" % (rec.where, rid, status, KINDS[rec.kind],
                                   ", ".join(STATUSES[rec.kind])))
        kls = rec.fields.get("class")
        if rec.kind == "H" and kls is not None and kls not in CLASSES:
            errors.append(
                "%s — %s carries class %r, which the format does not define "
                "(%s)" % (rec.where, rid, kls, ", ".join(CLASSES)))
        named = rec.fields.get("requirement")
        if rec.kind in ("B", "U") and named is not None \
                and not isinstance(named, str):
            errors.append(
                "%s — %s carries requirement %r, and the format defines one "
                "requirement identifier there, not a list"
                % (rec.where, rid, named))
        expires = rec.fields.get("expires")
        if rec.kind == "H" and expires is not None and not as_date(expires):
            errors.append(
                "%s — %s carries expires %r, which is not a date the format "
                "defines (YYYY-MM-DD)" % (rec.where, rid, expires))
        for heading, rows in tables_of(rec):
            for marker, declared in sorted(NAMED_TABLES.items()):
                if marker in heading and heading != declared:
                    errors.append(
                        "%s — %s carries a table headed | %s |, and the "
                        "format declares | %s | for that one; read by "
                        "position, the difference is silent"
                        % (rec.where, rid, " | ".join(heading),
                           " | ".join(declared)))
            for row in rows:
                if len(row) != len(heading):
                    errors.append(
                        "%s — %s has a table row with %d cell(s) where its "
                        "heading declares %d: | %s |"
                        % (rec.where, rid, len(row), len(heading),
                           " | ".join(row)))
        grade = rec.fields.get("grade")
        if rec.kind == "H" and grade is not None and grade not in GRADES:
            errors.append(
                "%s — %s carries grade %r, which the format does not define "
                "(%s)" % (rec.where, rid, grade, ", ".join(GRADES)))
        declined = rec.fields.get("declined")
        if rec.kind == "H" and declined is not None \
                and not (isinstance(declined, str)
                         and RE_DECLINED.match(declined)):
            errors.append(
                "%s — %s carries declined %r, which is not the grammar the "
                "format defines (a date, a dash, and the reason)"
                % (rec.where, rid, declined))
        threshold = rec.fields.get("refuted_if")
        if rec.kind == "H" and threshold is not None \
                and not (isinstance(threshold, str)
                         and RE_THRESHOLD.match(threshold)):
            errors.append(
                "%s — %s carries refuted_if %r, which is not the grammar the "
                "format defines (proportion|mean|count, one of < <= > >=, a "
                "number, at n >= a whole number)" % (rec.where, rid, threshold))

    # annotation removed on install
    for hid in sorted(hyps, key=srs_parse.id_key):
        rec = hyps[hid]

        # annotation removed on install
        # The threshold was written before the measurement so that the
        # verdict would stop being a matter of opinion. A verdict left free
        # to disagree with it gives that back.
        threshold = RE_THRESHOLD.match(rec.fields.get("refuted_if") or "")
        if threshold and threshold.group(1) not in TESTABLE_KINDS \
                and rec.fields.get("class") == "I":
            rule_finding(warnings, reports, cfg, "class-untestable",
                         "%s — %s is class I over a %s, and how far a %s can "
                         "miss does not follow from anything its rows carry; "
                         "re-confirmation here is a human act, not an "
                         "automatic one"
                         % (rec.where, hid, threshold.group(1),
                            threshold.group(1)))
        for row in table_with(rec, "verdict") if threshold else []:
            if len(row) < 4:
                continue
            date, verdict = row[0] or "no date", row[3]
            if verdict not in VERDICTS:
                errors.append(
                    "%s — %s gives the measurement of %s the verdict %r, "
                    "which is not one a measurement can reach (%s)"
                    % (rec.where, hid, date, verdict, " or ".join(VERDICTS)))
                continue
            try:
                value, sample = float(row[1]), float(row[2])
            except ValueError:
                errors.append(
                    "%s — %s measures %s as %r out of %r, which no threshold "
                    "can be compared against"
                    % (rec.where, hid, date, row[1], row[2]))
                continue
            fault = measurement_fault(threshold.group(1), value, sample)
            if fault:
                errors.append(
                    "%s — %s calls the measurement of %s %r against "
                    "refuted_if %r, and %s, so no comparison was made"
                    % (rec.where, hid, date, verdict,
                       rec.fields["refuted_if"], fault))
                continue
            # annotation removed on install
            # A class III measurement is a person's reading, and its
            # populations are small: the interval at n = 2 compels
            # `supported` whatever both people said. The threshold stays
            # declared and its own words still bind — a sample below its
            # gate, a value on its safe side — but how far the reading can
            # miss is not computed, and the verdict is the reader's, who is named.
            owed, why = verdict_owed(threshold, value, sample, cfg,
                                     interval=rec.fields.get("class") != "III")
            if owed is not None and owed != verdict:
                errors.append(
                    "%s — %s calls the measurement of %s %r against "
                    "refuted_if %r, and %s, so the verdict it compels is %r"
                    % (rec.where, hid, date, verdict,
                       rec.fields["refuted_if"], why, owed))

        # Forty thousand in a cohort and a dozen conversations both end in
        # the word `supported`, and only for the second is the word
        # somebody's reading.
        if rec.fields.get("class") == "III":
            for row in table_with(rec, "verdict"):
                if len(row) >= 5 and not row[4]:
                    rule_finding(warnings, reports, cfg,
                                 "verdict-unattributed",
                                 "%s — %s is class III and its measurement "
                                 "of %s gives a verdict with nobody named; "
                                 "a reading with no reader is not evidence "
                                 "anyone can weigh"
                                 % (rec.where, hid, row[0] or "no date"))

        # A grade with nothing attached is a label. The binding is what
        # makes it do work, and the map is the project's own.
        action, grade = rec.fields.get("action"), rec.fields.get("grade")
        permitted = cfg["grades"].get(grade) if grade else None
        if action and permitted is not None and action not in permitted:
            rule_finding(warnings, reports, cfg, "action-beyond-grade",
                         "%s — %s is graded %s and declares the action %r, "
                         "which that grade does not permit here (%s)"
                         % (rec.where, hid, grade, action,
                            ", ".join(permitted) or "nothing"))
        # annotation removed on install
        # The quieter half: an action beyond its grade can be compared,
        # an action with no grade cannot.
        if action and not grade and cfg["grades"]:
            rule_finding(warnings, reports, cfg, "action-without-grade",
                         "%s — %s declares the action %r and no grade, so "
                         "there is nothing to say whether its evidence "
                         "carries it" % (rec.where, hid, action))

        # annotation removed on install
        # One line says it was refused on a date and for a reason; the
        # status says it holds. Which is current, only the author knows.
        if "declined" in rec.fields \
                and rec.fields.get("status") != "declined":
            rule_finding(warnings, reports, cfg, "declined-leftover",
                         "%s — %s is %s and still carries a `declined` "
                         "value; a refusal left behind by a later "
                         "measurement says the opposite of the status"
                         % (rec.where, hid,
                            rec.fields.get("status") or "without a status"))

        # A refusal is recorded so the same question returning in six
        # months is answered from the record instead of argued again.
        if rec.fields.get("status") == "declined" \
                and "declined" not in rec.fields:
            errors.append("%s — %s is declined and carries no `declined` "
                          "value, so neither the reason nor the date of the "
                          "refusal is on the record" % (rec.where, hid))

    # A declaration that gives no reason is indistinguishable from a shrug.
    for rid in sorted(decls, key=srs_parse.id_key):
        rec = decls[rid]
        if not statement_of(rec):
            errors.append("%s — %s declares %s unclaimed and gives no reason"
                          % (rec.where, rid,
                             rec.fields.get("requirement", "a requirement")))

    staked = {}
    for rid in sorted(bets, key=srs_parse.id_key):
        rec = bets[rid]
        if not active(rec):
            continue
        for name in as_list(rec.fields.get("all_of")) \
                + as_list(rec.fields.get("any_of")):
            staked.setdefault(name, []).append(rid)

    def never_measured(hid):
        """Whether the more specific rule will speak for this record.

        Checked against the severity a project chose and not only against
        the facts: stepping aside for a finding nobody will see would leave
        the record unreported by either rule.

        Compared rather than tested for `off`, because the quiet case is
        not the only one. A project that lowered `never-measured` to a
        report lowered that rule and not this one, and the expiry that is
        owed as a warning would come out as a report instead — a
        second rule's severity changed by a setting that never named it.
        Silence is only earned where the other rule speaks at least as
        loudly as this one would have.
        """
        rec = hyps.get(hid)
        loudness = {"warn": 2, "report": 1, "off": 0}
        other = loudness[cfg["rules"].get("never-measured", "warn")]
        mine = loudness[cfg["rules"].get("hypothesis-expired", "warn")]
        return (other >= mine and other > 0
                and hid in staked and rec is not None
                and not table_with(rec, "verdict"))

    # A hypothesis whose term has run out. Reported, never rewritten: expiry
    # is not a verdict, and only a measurement can answer what the status is.
    for rid in sorted(hyps, key=srs_parse.id_key):
        rec = hyps[rid]
        expires = as_date(rec.fields.get("expires"))
        if expires is None:
            continue                      # already reported as a bad value
        if expires < today and not never_measured(rid):
            rule_finding(warnings, reports, cfg, "hypothesis-expired",
                         "%s — %s ran out of term on %s"
                         % (rec.where, rid, expires.isoformat()))

    # Every pointer into a model this register does not own.
    for rid in sorted(records, key=srs_parse.id_key):
        rec = records[rid]
        if rec.kind not in ("B", "U") or model is None:
            continue
        named = rec.fields.get("requirement")
        if isinstance(named, str) and named and named not in model:
            errors.append("%s — %s names requirement %s, which is not in the "
                          "requirement model" % (rec.where, rid, named))

    # Both ends of every bet.
    by_requirement = {}
    # annotation removed on install
    # Kept apart from `by_requirement`: two bets on one requirement is a
    # fact about the records whatever they name, while a declaration is
    # only retired by a bet that actually stands the requirement on
    # something.
    staking = {}
    for rid in sorted(bets, key=srs_parse.id_key):
        rec = bets[rid]
        for name in as_list(rec.fields.get("all_of")) \
                + as_list(rec.fields.get("any_of")):
            if name not in hyps:
                errors.append("%s — %s names hypothesis %s, which is not in "
                              "the register" % (rec.where, rid, name))
        req = rec.fields.get("requirement")
        if not isinstance(req, str) or not req:
            continue
        if active(rec):
            by_requirement.setdefault(req, []).append(rid)
            if stakes(rec):
                staking.setdefault(req, []).append(rid)
        if model is None:
            continue
        target = model.get(req)
        if target is None:
            continue                      # already reported above
        if target.get("status") in CANCELLED:
            rule_finding(warnings, reports, cfg, "bet-cancelled",
                         "%s — %s stands on %s, which is %s"
                         % (rec.where, rid, req, target["status"]))

    # annotation removed on install
    # What a hypothesis says about itself against what the register does
    # with it. Both readings are of the same pair — the record and the bets
    # standing on it — so they are computed together.
    for name in sorted(staked, key=srs_parse.id_key):
        if name not in hyps:
            continue                      # already reported as dangling
        rec = hyps[name]
        on = ", ".join(sorted(staked[name], key=srs_parse.id_key))
        if rec.fields.get("status") == "untested":
            rule_finding(warnings, reports, cfg, "relied-on-untested",
                         "%s — %s is `untested`, which says nobody relies "
                         "on it, and %s does; the honest status for a "
                         "hypothesis being built on is `assumed`"
                         % (rec.where, name, on))
        expires = as_date(rec.fields.get("expires"))
        if expires is not None and expires < today \
                and not table_with(rec, "verdict"):
            rule_finding(warnings, reports, cfg, "never-measured",
                         "%s — %s passed its term on %s with no measurement "
                         "recorded at all, and %s stands on it"
                         % (rec.where, name, expires.isoformat(), on))

    # Two bets on one requirement turn a maximum into a minimum without
    # saying so, which is the only failure the record encoding introduces.
    # annotation removed on install
    for req in sorted(by_requirement, key=srs_parse.id_key):
        names = sorted(by_requirement[req], key=srs_parse.id_key)
        if len(names) > 1:
            rule_finding(warnings, reports, cfg, "bet-duplicated",
                         "%s — %s is named by more than one bet (%s); two "
                         "are two independent sets of alternatives, and the "
                         "reduction reads them that way"
                         % (records[names[0]].where, req, ", ".join(names)))

    # A declaration retires itself when a real bet turns up.
    for rid in sorted(decls, key=srs_parse.id_key):
        rec = decls[rid]
        if not active(rec):
            continue
        req = rec.fields.get("requirement")
        if isinstance(req, str) and req in staking:
            rule_finding(warnings, reports, cfg, "declaration-superfluous",
                         "%s — %s declares %s unclaimed, and %s names it"
                         % (rec.where, rid, req,
                            ", ".join(sorted(staking[req], key=srs_parse.id_key))))

    check_history(records, cfg, warnings, reports)

    if model_error:
        reports.append("the requirement model could not be read (%s); the "
                       "bets were not resolved against it" % model_error)
    return errors, warnings, reports


def _pick(hyps, names, strongest):
    """The strongest or weakest of the named hypotheses, as (rank, id).

    Ties break on the identifier so that a dashboard regenerated from
    unchanged records comes out byte for byte the same.
    """
    ranked = [(STRENGTH[hyps[n].fields["status"]], n) for n in names
              if n in hyps and hyps[n].fields.get("status") in STRENGTH]
    if not ranked:
        return None
    if strongest:
        return sorted(ranked, key=lambda pair: (-pair[0], pair[1]))[0]
    return sorted(ranked)[0]


def decide(records, req):
    # annotation removed on install
    """The hypothesis that decides a requirement, as (rank, id).

    Nothing stores what a requirement rests on. It is read off the bets
    every time it is needed, which is what keeps the join in one direction.

    Within a bet: the weakest of what it requires, the strongest of what it
    offers as alternatives, and the weaker of those two. Across the bets of
    one requirement: the weakest. None where nothing decides it.

    The hypothesis is returned rather than its rank alone because two
    statuses can share a rank, and naming a status the record does not
    carry is worse than saying nothing.
    """
    hyps = {i: r for i, r in records.items() if r.kind == "H"}
    best = None
    for rid in sorted(records, key=srs_parse.id_key):
        rec = records[rid]
        if rec.kind != "B" or not active(rec) \
                or rec.fields.get("requirement") != req:
            continue
        candidates = [
            _pick(hyps, as_list(rec.fields.get("all_of")), strongest=False),
            _pick(hyps, as_list(rec.fields.get("any_of")), strongest=True),
        ]
        candidates = [c for c in candidates if c is not None]
        if not candidates:
            continue
        weakest = sorted(candidates)[0]
        best = weakest if best is None else sorted([best, weakest])[0]
    return best


def confirmation_dates(rec):
    """Dates of the evidence rows under a hypothesis, oldest first."""
    out = []
    for row in table_with(rec, "verdict"):
        if row and RE_DATE.match(row[0]):
            out.append(row[0])
    return sorted(out)


def reversals(records):
    # annotation removed on install
    """Per author: verdicts given, and how many a later one reversed.

    Read from the evidence table and not from history. A verdict and the
    measurement that reversed it are two rows of the same table, ordered
    by their own dates, so the file in front of us holds the whole
    answer.
    """
    given, turned = {}, {}
    for hid in sorted(records, key=srs_parse.id_key):
        rec = records[hid]
        if rec.kind != "H":
            continue
        rows = [r for r in table_with(rec, "verdict") if len(r) >= 5]
        rows.sort(key=lambda r: (as_date(r[0]) or datetime.date.min, r[0]))
        for index, row in enumerate(rows):
            verdict, author = row[3], row[4]
            given[author] = given.get(author, 0) + 1
            if any(later[3] != verdict for later in rows[index + 1:]):
                turned[author] = turned.get(author, 0) + 1
    return given, turned


def build_dashboard(records, model, incoming, cfg):
    # annotation removed on install,
    # annotation removed on install
    kinds = {k: [i for i, r in sorted(records.items(), key=lambda kv: srs_parse.id_key(kv[0])) if r.kind == k]
             for k in KINDS}
    out = ["# Grounds dashboard", "",
           "**Generated by `tools/srs_grounds.py`. Do not edit by hand —",
           "the next run will overwrite it.**", "",
           "Records: %d — %s." % (len(records), ", ".join(
               "%d %s" % (len(kinds[k]), KINDS[k]) for k in "IFHBU")), ""]

    out += ["## The core", "",
            "Ideologies: %d." % len(kinds["I"]), ""]
    supported = [records[i] for i in kinds["H"]
                 if records[i].fields.get("status") == "supported"]
    out += ["| Class | Supported | Oldest confirmation | Newest |",
            "|---|---|---|---|"]
    for cls in ("I", "II", "III"):
        members = [r for r in supported if r.fields.get("class") == cls]
        dates = [d for r in members for d in confirmation_dates(r)]
        out.append("| %s | %d | %s | %s |"
                   % (cls, len(members),
                      dates[0] if dates else "—", dates[-1] if dates else "—"))
    out += ["",
            "Given as dates and not as a count of days: this file is",
            "committed and compared against a fresh run, so a number that",
            "moved every night would fail the gate every morning without",
            "saying anything new.", ""]

    # annotation removed on install
    out += ["## What each frame has refused", ""]
    if kinds["F"]:
        for fid in kinds["F"]:
            rec = records[fid]
            rows = table_with(rec, "what was refused")
            out.append("**%s — %s**" % (fid, rec.title))
            out.append("")
            if rows:
                out += ["| date | what was refused | who asked |",
                        "|---|---|---|"]
                for row in rows:
                    out.append("| %s |" % " | ".join(row[:3]))
            else:
                out.append("Nothing recorded. A frame that has turned down "
                           "nothing is either untested or drawn where "
                           "nothing was going to happen.")
            out.append("")
    else:
        out += ["No frames are recorded.", ""]

    # annotation removed on install
    out += ["## Verdicts a later measurement reversed", ""]
    given, turned = reversals(records)
    if given:
        out += ["| who | verdicts | reversed |", "|---|---|---|"]
        for author in sorted(given):
            out.append("| %s | %d | %d |"
                       % (author, given[author], turned.get(author, 0)))
        out += ["",
                "The affordable half of weighting a judgement by its "
                "author's",
                "accuracy. The expensive half — calibration questions with "
                "known",
                "answers — is a programme somebody runs, not a file format.",
                ""]
    else:
        out += ["No verdicts are recorded.", ""]

    out += ["## The debt", ""]
    if model is None:
        out += ["The requirement model could not be read, so nothing here",
                "was computed. This is not a reading of zero debt.", ""]
    else:
        staked = sorted({r.fields.get("requirement")
                         for r in records.values()
                         if r.kind == "B" and active(r)
                         and r.fields.get("requirement")}, key=srs_parse.id_key)
        rows, weak = [], 0
        for req in staked:
            decided = decide(records, req)
            if decided is None:
                continue
            status = records[decided[1]].fields["status"]
            weak += 1 if status in DEBT_STATUSES else 0
            rows.append("| %s | %s | %s |" % (req, decided[1], status))
        # annotation removed on install
        # The denominator is what the sentence names — requirements carrying
        # a bet — and not the rows below it, which are the ones whose bet
        # resolves. A bet naming no hypothesis carries neither `refuted` nor
        # `expired` nor `assumed`, so it counts here and not in `weak`: it
        # rests on nothing, which is a different reading and belongs to the
        # list below. The two questions differ, and one record answers them
        # differently.
        if staked:
            out += ["Of %d requirements carrying a bet, %d rest on "
                    "hypotheses that are" % (len(staked), weak),
                    "`refuted`, `expired` or `assumed` — %.0f%%."
                    % (100.0 * weak / len(staked)), ""]
            if len(rows) != len(staked):
                out += ["%d of them are named by a bet that stakes them on no "
                        "hypothesis at all" % (len(staked) - len(rows)),
                        "and so appear in no row below.", ""]
            if rows:
                out += ["| Requirement | Decided by | Status |",
                        "|---|---|---|"] + rows + [""]
        else:
            out += ["No requirement carries a bet, so there is nothing to",
                    "reduce. This is not a reading of zero debt.",
                    ""]

    # annotation removed on install
    # The list no rule of this layer is allowed to shorten. A requirement
    # standing on nothing is a reading, and demanding a bet would replace it
    # with invented ones.
    # annotation removed on install
    # The rate, not the total: one requirement standing on nothing is noise
    # and is meant to be, and five in a quarter with four of them in one
    # area is the product having become something nobody said out loud.
    # A calendar period and not "the last ninety days", whatever length the
    # configuration names: this file is committed and compared, and a window
    # anchored to today would move every night and fail the gate every
    # morning without saying anything new.
    out += ["## Requirements that arrived standing on nothing", "",
            "Counted by %s, which is what `period` says in the register's "
            "configuration." % cfg["period"], ""]
    if model is None:
        out += ["The requirement model could not be read, so this is not a "
                "reading of none.", ""]
    else:
        claimed = {r.fields.get("requirement") for r in records.values()
                   if r.kind == "B" and active(r) and stakes(r)}
        buckets, undated = {}, 0
        for req in sorted(model, key=srs_parse.id_key):
            if req in claimed or not live(model[req]):
                continue
            date = as_date(model[req].get("created"))
            if date is None:
                undated += 1
                continue
            entry = buckets.setdefault(period_of(date, cfg["period"]), {})
            entry[model[req].get("area", "?")] = \
                entry.get(model[req].get("area", "?"), 0) + 1
        if buckets:
            out += ["| %s | arrived unclaimed | areas |" % cfg["period"],
                    "|---|---|---|"]
            for label in sorted(buckets):
                areas = buckets[label]
                out.append("| %s | %d | %s |"
                           % (label, sum(areas.values()),
                              ", ".join("%s %d" % (a, n)
                                        for a, n in sorted(areas.items()))))
            out.append("")
        else:
            out += ["Nothing arrived unclaimed in any dated period.", ""]
        if undated:
            out += ["%d of them carry no `created` date and fall in no "
                    "period. `tools/srs_dates.py` writes one from the "
                    "history." % undated, ""]

    out += ["## Requirements resting on no hypothesis", ""]
    if model is None:
        out += ["The requirement model could not be read, so this list is",
                "not a list of none.", ""]
    else:
        claimed = {r.fields.get("requirement") for r in records.values()
                   if r.kind == "B" and active(r) and stakes(r)}
        standing = [req for req in sorted(model, key=srs_parse.id_key) if live(model[req])]
        rows = []
        for req in standing:
            if req in claimed:
                continue
            # annotation removed on install
            # Filtered here rather than in the model: the viewer owes every
            # incoming link to whoever asks it, and the procedure for
            # withdrawing a requirement reads exactly the links from
            # cancelled ones to settle what breaks. What does not follow is
            # that such a link still holds weight — a requirement nobody
            # kept stands on nothing.
            links = len([1 for _field, other in incoming.get(req, [])
                         if other in model and live(model[other])])
            files = len(model[req].get("code", []))
            rows.append((links + files, links, files, req))
        out += ["%d of %d requirements. Weight is what stands on them: how "
                "many" % (len(rows), len(standing)),
                "requirements link to them, plus how many files their `code` "
                "field names.", ""]
        if rows:
            out += ["| Requirement | Incoming | Code files | Weight |",
                    "|---|---|---|---|"]
            for weight, links, files, req in sorted(rows, key=lambda r: (-r[0], r[3])):
                out.append("| %s | %d | %d | %d |" % (req, links, files, weight))
            out.append("")
    return "\n".join(out).rstrip() + "\n"


def blast(records, model, paths):
    # annotation removed on install
    """What the requirements these files belong to are staked on.

    A file belongs to a requirement two ways and both count: the
    specification file the requirement is written in, and the `code` or
    `tests` entries naming it. The second is the one a commit usually
    touches, and it is the one this exists for — the moment somebody is
    changing the code is the moment what it rests on is worth knowing.
    Matching only the first made this silent on every commit that
    changed no specification, which is most of them.

    Quiet where nothing is staked: a report that speaks on every commit
    is a report nobody reads, and the hook this feeds runs on all of
    them.
    """
    if model is None:
        return 0
    wanted = {os.path.normpath(p) for p in paths}
    here = set()
    for record in model.values():
        named = [record.get("path", "")]
        named += record.get("code") or []
        named += record.get("tests") or []
        if wanted & {os.path.normpath(p) for p in named if p}:
            here.add(record["id"])
    if not here:
        return 0
    said = False
    for rid in sorted(records, key=srs_parse.id_key):
        rec = records[rid]
        if rec.kind != "B" or not active(rec):
            continue
        req = rec.fields.get("requirement")
        if req not in here:
            continue
        grounds = []
        for name in as_list(rec.fields.get("all_of")) \
                + as_list(rec.fields.get("any_of")):
            status = records[name].fields.get("status", "?") \
                if name in records else "not in the register"
            grounds.append("%s (%s)" % (name, status))
        if not said:
            sys.stdout.write("\nWhat this commit touches is staked on:\n")
            said = True
        sys.stdout.write("  %s — %s rests on %s\n"
                         % (req, rid, ", ".join(grounds) or "nothing named"))
    return 0


def citation(rec):
    # annotation removed on install
    """The form a record is named in to a person — the one the viewer
    prints for a requirement, over the register's own records: identifier,
    title, file, status."""
    return "%s — %s (%s, %s)" % (rec.id, rec.title, rec.path,
                                  rec.fields.get("status") or "?")


def cite(records, wanted):
    # annotation removed on install
    """Print each record asked for, ready to paste, in the order asked; an
    identifier no record carries is named on stderr and fails the run, in
    the same run as the rest. `records` is the register keyed by identifier,
    as read_records returns it."""
    missing = [rid for rid in wanted if rid not in records]
    for rid in wanted:
        if rid in records:
            sys.stdout.write("%s\n" % citation(records[rid]))
    for rid in missing:
        sys.stderr.write("no record %s\n" % rid)
    return 1 if missing else 0


def main():
    # annotation removed on install
    argv = sys.argv[1:]
    paths = []
    if "--blast" in argv:
        cut = argv.index("--blast")
        paths = argv[cut + 1:]
        argv = argv[:cut] + ["--blast"]
    wanted = None
    if "--cite" in argv:
        cut = argv.index("--cite")
        wanted = argv[cut + 1:]
        argv = argv[:cut] + ["--cite"]
        if not wanted:
            sys.stderr.write("--cite needs at least one record identifier\n"
                             "usage: srs_grounds.py --cite ID…\n")
            return 2
    flags = set(argv)
    unknown = sorted(flags - {"--no-write", "--strict", "--blast", "--cite"})
    if unknown:
        sys.stderr.write("unknown flag(s): %s\nusage: srs_grounds.py "
                         "[--no-write] [--strict] [--blast PATH…] [--cite ID…]\n"
                         % " ".join(unknown))
        return 2
    if not os.path.isdir(GROUNDS):
        sys.stderr.write("no grounds/ directory here — this project carries "
                         "no register, and there is nothing to check.\n")
        return 2

    errors = []
    records = read_records(errors)
    if wanted is not None:
        # A citation reads the records and nothing else: the configuration
        # prices findings, and a citation is not one.
        return cite(records, wanted)
    cfg = load_config()
    model_json, model_error = read_model()
    model = incoming = None
    if model_json is not None:
        model = {r["id"]: r for r in model_json["requirements"]}
        incoming = model_json.get("incoming", {})

    if "--blast" in flags:
        return blast(records, model, paths)

    found, warnings, reports = validate(records, model, model_error, cfg)
    errors += found

    for line in reports:
        sys.stdout.write("report: %s\n" % line)
    for line in warnings:
        sys.stdout.write("warning: %s\n" % line)
    for line in errors:
        sys.stdout.write("error: %s\n" % line)

    wrote = ""
    if not errors and "--no-write" not in flags:
        text = build_dashboard(records, model, incoming or {}, cfg)
        with open(DASHBOARD, "w", encoding="utf-8") as handle:
            handle.write(text)
        wrote = " Dashboard rewritten: grounds/90-dashboard.md."

    sys.stdout.write(
        "\nRecords: %d. Errors: %d. Warnings: %d.%s (srs_grounds %s)\n"
        % (len(records), len(errors), len(warnings), wrote, __version__))

    if errors:
        return 1
    if warnings and "--strict" in flags:
        sys.stderr.write("strict mode: %d warning(s) treated as errors.\n"
                         % len(warnings))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
