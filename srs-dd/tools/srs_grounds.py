#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.24.0 — the framework release this file came from
# annotation removed on install
# Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License
# annotation removed on install
"""The grounds checker: reads the register beside specs/ and reports on it.

    python3 srs-dd/tools/srs_grounds.py             check and rewrite 90-dashboard.md
    python3 srs-dd/tools/srs_grounds.py --no-write  check only
    python3 srs-dd/tools/srs_grounds.py --strict    treat warnings as errors
    python3 srs-dd/tools/srs_grounds.py --cite ID…  name records to a person
    python3 srs-dd/tools/srs_grounds.py --blast P…  what the requirements these
                                             files belong to are staked on
    python3 srs-dd/tools/srs_grounds.py --html      the dashboard as one page
    python3 srs-dd/tools/srs_grounds.py --html --link index.html,arch.html
                                                    and the pages beside it

The format is srs-dd/grounds.md's; this script only enforces it. The requirement
model comes from srs_view.py as a subprocess, so an optional subsystem never dies
on the mandatory one's configuration. Standard library only, Python 3.9.
"""

# file annotation removed on install

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
        "srs-dd/tools/srs_parse.py: missing — the grounds checker reads the record "
        "shape through it, and the two travel together. Copy it beside this "
        "file from the framework clone, or re-run tools/srs_init.py to "
        "refresh the tooling.\n")
    sys.exit(2)

# Re-exported: the number lives in srs_parse, the one file
# every checker — this one, the specification and the architecture — must have.
__version__ = srs_parse.__version__

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GROUNDS = os.path.join(ROOT, "grounds")
CONFIG = os.path.join(GROUNDS, "grounds-config.json")
# annotation removed on install
# The only path this tool ever writes. Everything else it does is read.
DASHBOARD = os.path.join(GROUNDS, "90-dashboard.md")
# annotation removed on install
VIEWER = os.path.join(ROOT, "srs-dd", "tools", "srs_view.py")

# Files in grounds/ that hold no records.
SKIP_FILES = {"README.md", "90-dashboard.md"}

# annotation removed on install
# The same broad net the specification checker uses, in this format's
# grammar: anything ID-shaped is captured and judged loudly afterwards.
RE_HEADING = re.compile(
    r"^###\s+([A-Za-z][A-Za-z0-9]*-\d+(?:-[A-Za-z0-9]+)*)"
    r"\s*(?:[—–-]\s*)?(.*)$")
# annotation removed on install
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
# annotation removed on install
# One number, one meaning, forever: the checker's part of that promise is
# that no two records in the register carry the same one.
RE_ID = re.compile(r"^(%s)-(%s)$" % ("|".join(sorted(KINDS)), srs_parse.NUMBER))   # annotation removed on install
# annotation removed on install

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

# annotation removed on install
CLASSES = ("I", "II", "III")
# annotation removed on install
GRADES = ("high", "moderate", "low", "very-low")
# `declined` carries both halves: a refusal without a reason answers nothing next
# time, one without a date cannot be told from one that predates everything.
RE_DECLINED = re.compile(r"^(\d{4}-\d{2}-\d{2})\s+[—–-]\s+(\S.*)$")
STATUSES = {
    "I": ("active", "dissolved"),
    "F": ("active", "retired"),
    "H": ("untested", "assumed", "supported", "refuted", "expired",
          "declined"),
    "B": ("active", "retired"),
    "U": ("active", "retired"),
}

# How much ground a hypothesis provides, weakest first; `declined` sits beside
# `refuted` because the core looked at it and said no.
STRENGTH = {"refuted": 0, "declined": 0, "expired": 1, "untested": 2,
            "assumed": 3, "supported": 4}
DEBT_STATUSES = ("refuted", "expired", "assumed")
# annotation removed on install
# What the specification calls a cancelled requirement; the readings below range
# over the live ones, as the viewer and the specification checker do.
CANCELLED = ("withdrawn", "superseded")
# annotation removed on install

# annotation removed on install
# Published names: a name here keeps its meaning forever, and is never given
# to a different rule.
RULES = ("bet-cancelled", "hypothesis-expired", "bet-duplicated",
         "declaration-superfluous", "threshold-moved", "evidence-dropped",
         "relied-on-untested", "never-measured", "verdict-unattributed",
         "action-beyond-grade", "declined-leftover", "action-without-grade",
         "class-untestable", "arguments-widened", "widening-undisclosed")
# annotation removed on install
SEVERITIES = ("warn", "report", "off")

# annotation removed on install
# What counts as "lately" is the project's. Calendar periods only — a window
# measured back from today would move this file every night.
PERIODS = ("month", "quarter", "year")
# annotation removed on install

# annotation removed on install
# Named levels rather than a free number: a confidence typed as 0.973 came from
# nowhere and cannot be discussed.
CONFIDENCES = (0.9, 0.95, 0.99)
# annotation removed on install
# One-sided: a threshold asks whether the truth is past it.
Z_ONE_SIDED = {0.9: 1.2816, 0.95: 1.6449, 0.99: 2.3263}

# annotation removed on install
# A mean's error does not follow from what the row carries, so a mean closes
# class I rather than refuting on noise.
TESTABLE_KINDS = ("proportion", "count")
# annotation removed on install

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


# annotation removed on install
def load_config():
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
    # What a weak hypothesis may be used for is appetite, so the map is the project's;
    # a grade absent from it permits anything.
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
    # annotation removed on install
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
# annotation removed on install


# annotation removed on install
def wilson_bounds(value, n, z):
    """Where a proportion's truth may sit, given `value` observed out of n: Wilson, not
    `p ± z·sqrt(pq/n)`, which runs off [0, 1] where thresholds are drawn."""
    denominator = 1.0 + z * z / n
    centre = (value + z * z / (2 * n)) / denominator
    half = z * math.sqrt(value * (1 - value) / n
                         + z * z / (4 * n * n)) / denominator
    return centre - half, centre + half
# annotation removed on install


def poisson_cdf(k, rate):
    """P(X <= k) for a Poisson of this rate, summed through logarithms so a large rate
    loses terms to underflow one at a time."""
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
    """Where a count's truth may sit, given k events observed: exact, since counts here
    are small and `k ± z·sqrt(k)` reads nought as certainty."""
    if k > POISSON_EXACT_TO:
        # Beyond the crossover the approximation is within two tenths of a percent and
        # costs no term per event.
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
# annotation removed on install


# Where the exact sum stops being worth its terms, chosen where the two methods
# already agree to a tenth of a percent.
POISSON_EXACT_TO = 1000


# annotation removed on install
# A register is written by hand, so a typo is ordinary input: every one of these
# used to crash the arithmetic or be judged in silence.
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


# annotation removed on install
# The two words a measurement may end in; a record's `status` has six, four of them
# things that happen to a hypothesis rather than things a measurement found.
VERDICTS = ("supported", "refuted")
# annotation removed on install


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

    `(None, None)` where the row compels none. With `interval` off — class III — only the
    threshold's own contradictions are compelled: a sample under its gate, a value on its
    safe side.
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
# annotation removed on install


def rule_finding(warnings, reports, cfg, rule, text):
    """Files a tunable finding at the severity this project chose."""
    severity = cfg["rules"].get(rule, "warn")
    if severity == "off":
        return
    line = "%s [%s]" % (text, rule)
    (warnings if severity == "warn" else reports).append(line)


# annotation removed on install
def collect_files():
    """Every record file in the register, subdirectories included: a register that grows a
    folder is not thereby exempt."""
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
# annotation removed on install


# annotation removed on install
def read_records(errors):
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
# annotation removed on install


def read_model():
    """The requirement model, or None with the reason it could not be read."""
    if not os.path.exists(VIEWER):
        return None, "srs-dd/tools/srs_view.py is not here"
    try:
        done = subprocess.run([sys.executable, VIEWER, "--json"],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as exc:
        return None, "could not run srs-dd/tools/srs_view.py: %s" % exc
    if done.returncode != 0:
        detail = done.stderr.decode("utf-8", "replace").strip().split("\n")
        return None, "srs-dd/tools/srs_view.py exited %d: %s" % (
            done.returncode, detail[-1] if detail else "no output")
    try:
        return json.loads(done.stdout.decode("utf-8")), None
    except ValueError as exc:
        return None, "srs-dd/tools/srs_view.py produced unreadable JSON: %s" % exc


# annotation removed on install
def history_of(paths):
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
# annotation removed on install


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


# annotation removed on install
def check_history(records, cfg, warnings, reports):
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
            # annotation removed on install

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
    # annotation removed on install

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
# annotation removed on install


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
# annotation removed on install


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
# exists to produce. That is the invented link `srs-dd/grounds.md`
# warns about, in the shape that costs an agent least to write: it
# arrives well-formed and passes every check on the shape.
def stakes(rec):
    """Whether this bet actually stands its requirement on something."""
    return bool(as_list(rec.fields.get("all_of"))
                + as_list(rec.fields.get("any_of")))
# annotation removed on install


# annotation removed on install
def live(entry):
    """Whether a requirement of the model has not been cancelled."""
    return entry.get("status") not in CANCELLED
# annotation removed on install


# annotation removed on install,
# annotation removed on install,
# annotation removed on install,
# annotation removed on install
def validate(records, model, model_error, cfg):
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
            # annotation removed on install
        # annotation removed on install

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
        # annotation removed on install

        # A refusal is recorded so the same question returning in six
        # months is answered from the record instead of argued again.
        if rec.fields.get("status") == "declined" \
                and "declined" not in rec.fields:
            errors.append("%s — %s is declined and carries no `declined` "
                          "value, so neither the reason nor the date of the "
                          "refusal is on the record" % (rec.where, hid))
    # annotation removed on install

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
    # Kept apart from `by_requirement`: a declaration is retired only by a bet that
    # actually stands the requirement on something.
    staking = {}
    # annotation removed on install
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
            # annotation removed on install
            if stakes(rec):
                staking.setdefault(req, []).append(rid)
            # annotation removed on install
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
    # What a hypothesis says about itself against what the register does with it; both
    # readings are of the same pair, so they are computed together.
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
    # annotation removed on install

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
    # annotation removed on install

    # annotation removed on install
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
    # annotation removed on install

    check_history(records, cfg, warnings, reports)

    if model_error:
        reports.append("the requirement model could not be read (%s); the "
                       "bets were not resolved against it" % model_error)
    return errors, warnings, reports
# annotation removed on install


def _pick(hyps, names, strongest):
    """The strongest or weakest of the named hypotheses, as (rank, id); ties break on the
    identifier so an unchanged dashboard comes out byte for byte the same."""
    ranked = [(STRENGTH[hyps[n].fields["status"]], n) for n in names
              if n in hyps and hyps[n].fields.get("status") in STRENGTH]
    if not ranked:
        return None
    if strongest:
        return sorted(ranked, key=lambda pair: (-pair[0], pair[1]))[0]
    return sorted(ranked)[0]


# annotation removed on install
def decide(records, req):
    """The hypothesis that decides a requirement, as (rank, id), read off the bets every
    time rather than stored, which keeps the join in one direction.

    Within a bet: the weakest required, the strongest offered, the weaker of the two.
    Across bets: the weakest. The hypothesis and not its rank alone, since two statuses
    can share one.
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
# annotation removed on install


def confirmation_dates(rec):
    """Dates of the evidence rows under a hypothesis, oldest first."""
    out = []
    for row in table_with(rec, "verdict"):
        if row and RE_DATE.match(row[0]):
            out.append(row[0])
    return sorted(out)


# annotation removed on install
def reversals(records):
    """Per author: verdicts given, and how many a later one reversed — read from the
    evidence table, whose rows carry their own dates, not from history."""
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
# annotation removed on install


# annotation removed on install,
# annotation removed on install
def build_dashboard(records, model, incoming, cfg):
    kinds = {k: [i for i, r in sorted(records.items(), key=lambda kv: srs_parse.id_key(kv[0])) if r.kind == k]
             for k in KINDS}
    out = ["# Grounds dashboard", "",
           "**Generated by `srs-dd/tools/srs_grounds.py`. Do not edit by hand —",
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
    # annotation removed on install

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
        # The denominator is what the sentence names, requirements carrying a bet, not the
        # rows whose bet resolves; a bet naming no hypothesis counts here and not in `weak`.
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

    # annotation removed on install
    # The list no rule here may shorten: demanding a bet would replace a requirement
    # standing on nothing with an invented one.
    # annotation removed on install
    # The rate, not the total, over a calendar period: this file is committed and
    # compared, and a window anchored to today would fail the gate every morning.
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
                    "period. `srs-dd/tools/srs_dates.py` writes one from the "
                    "history." % undated, ""]
    # annotation removed on install
    # annotation removed on install

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
            # Filtered here, not in the model: the viewer owes every incoming link to whoever
            # asks, but a requirement nobody kept stands on nothing.
            links = len([1 for _field, other in incoming.get(req, [])
                         if other in model and live(model[other])])
            files = len(model[req].get("code", []))
            rows.append((links + files, links, files, req))
            # annotation removed on install
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
# annotation removed on install


# annotation removed on install
def blast(records, model, paths):
    """What the requirements these files belong to are staked on, by the specification file
    they are written in and by their `code` and `tests` entries — the second being what a
    commit usually touches. Quiet where nothing is staked, since the hook runs on every
    commit."""
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
# annotation removed on install


# annotation removed on install
def citation(rec):
    """The form a record is named in to a person: identifier, title, file, status, as the
    viewer prints it for a requirement."""
    return "%s — %s (%s, %s)" % (rec.id, rec.title, rec.path,
                                  rec.fields.get("status") or "?")
# annotation removed on install


# annotation removed on install
def cite(records, wanted):
    """Each record asked for, ready to paste, in the order asked; an identifier no record
    carries is named on stderr and fails the run."""
    missing = [rid for rid in wanted if rid not in records]
    for rid in wanted:
        if rid in records:
            sys.stdout.write("%s\n" % citation(records[rid]))
    for rid in missing:
        sys.stderr.write("no record %s\n" % rid)
    return 1 if missing else 0
# annotation removed on install


# annotation removed on install
# The published set, copied from the Published pages table of the specification's standard; a
# suite holds this copy to it. OWN is this page's place in the set: a page is not linked to
# itself, and a caller that names it has made a mistake worth hearing about.
PAGES = (("index.html", "the specification"),
         ("arch.html", "the architecture document"),
         ("grounds.html", "the grounds dashboard"))
OWN = "grounds.html"
# annotation removed on install

# annotation removed on install
# The dashboard as a page. Its own stylesheet and its own translator: the layers are installed
# one without the other, so neither reaches into the other's tools for either.
STYLE = """
:root { --bg: #ffffff; --fg: #1a1d21; --muted: #6b7280; --line: #e2e5e9; --panel: #f7f8fa; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #15171a; --fg: #e8eaed; --muted: #9aa0a6; --line: #2b2f34; --panel: #1c1f23; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.6 -apple-system,
       BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
main { max-width: 56rem; margin: 0 auto; padding: 2rem 1rem 4rem; }
nav.pages { font-size: .9rem; margin-bottom: 1.4rem; }
nav.pages a { color: #2c5fd0; }
nav.pages span { color: var(--muted); padding: 0 .4rem; }
h1 { font-size: 1.9rem; margin: 0 0 .4rem; }
h2 { font-size: 1.3rem; margin: 2.2rem 0 .6rem; padding-bottom: .3rem;
     border-bottom: 1px solid var(--line); }
h3 { font-size: 1.05rem; margin: 1.6rem 0 .4rem; }
p { margin: .5rem 0; }
code { font: 13px/1.5 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
       background: var(--panel); border: 1px solid var(--line); border-radius: 3px;
       padding: 0 .25rem; }
em { color: var(--muted); font-style: normal; }
table { border-collapse: collapse; margin: .8rem 0; font-size: .95rem; width: 100%; }
th, td { border: 1px solid var(--line); padding: .35rem .6rem; text-align: left;
         vertical-align: top; }
th { background: var(--panel); font-weight: 600; }
"""

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Grounds</title>
<style>%s</style>
</head>
<body>
<main>
%s
</main>
</body>
</html>
"""

# The spans this dashboard writes. Underscores only at a word boundary, so a path outside
# backticks is not read as emphasis.
RE_SPAN = re.compile(r"\*\*(.+?)\*\*|`(.+?)`|(?<![\w])_(.+?)_(?![\w])")


def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def spans(text):
    out, last = [], 0
    for match in RE_SPAN.finditer(text):
        out.append(esc(text[last:match.start()]))
        bold, code, emphasis = match.groups()
        if bold is not None:
            out.append("<strong>%s</strong>" % esc(bold))
        elif code is not None:
            out.append("<code>%s</code>" % esc(code))
        else:
            out.append("<em>%s</em>" % esc(emphasis))
        last = match.end()
    out.append(esc(text[last:]))
    return "".join(out)


def cells(line):
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


# annotation removed on install
def nav(named):
    """The links to the other pages of the set, in the set's own order. Exactly what the caller
    named: nothing where it named nothing, and no page that is not in the set."""
    held = [(name, label) for name, label in PAGES if name in named]
    if not held:
        return ""
    parts = []
    for index, (name, label) in enumerate(held):
        if index:
            parts.append("<span>·</span>")
        parts.append('<a href="%s">%s</a>' % (esc(name), esc(label)))
    return '<nav class="pages">%s</nav>' % "".join(parts)


def read_links(value):
    """The names a caller gave, or a sentence saying what is wrong with them."""
    named, known = [], dict(PAGES)
    for name in (part.strip() for part in value.split(",")):
        if not name:
            continue
        if name == OWN:
            return None, ("%s is this page itself; name the pages beside it" % name)
        if name not in known:
            return None, ("%s is not one of the published pages: %s"
                          % (name, ", ".join(n for n, _l in PAGES if n != OWN)))
        if name not in named:
            named.append(name)
    return named, ""
# annotation removed on install


def to_page(dashboard, named=()):
    """The dashboard as one page. The markdown is this file's own output, so the grammar is
    closed: three heading levels, paragraphs and tables."""
    body, paragraph, table = [], [], None

    def flush():
        if paragraph:
            body.append("<p>%s</p>" % spans(" ".join(paragraph)))
            del paragraph[:]

    def close_table():
        nonlocal table
        if table is not None:
            body.append("</tbody></table>")
            table = None

    for line in dashboard.split("\n"):
        stripped = line.strip()
        if stripped.startswith("|"):
            flush()
            row = cells(stripped)
            if all(set(cell) <= set("-: ") and cell for cell in row):
                continue          # the rule under the heads, which HTML draws itself
            if table is None:
                body.append("<table><thead><tr>%s</tr></thead><tbody>"
                            % "".join("<th>%s</th>" % spans(cell) for cell in row))
                table = True
                continue
            body.append("<tr>%s</tr>" % "".join("<td>%s</td>" % spans(cell) for cell in row))
            continue
        close_table()
        if not stripped:
            flush()
            continue
        heading = re.match(r"^(#{1,3}) (.+)$", stripped)
        if heading:
            flush()
            level = len(heading.group(1))
            body.append("<h%d>%s</h%d>" % (level, spans(heading.group(2)), level))
            continue
        paragraph.append(stripped)
    flush()
    close_table()
    return PAGE % (STYLE, nav(named) + "\n" + "\n".join(body))
# annotation removed on install


# annotation removed on install
def main():
    argv = sys.argv[1:]
    paths = []
    if "--blast" in argv:
        cut = argv.index("--blast")
        paths = argv[cut + 1:]
        argv = argv[:cut] + ["--blast"]
    # annotation removed on install
    named = []
    if "--link" in argv:
        cut = argv.index("--link")
        rest = argv[cut + 1:]
        if not rest:
            sys.stderr.write("--link needs the page(s) to link: %s\n"
                             % ", ".join(n for n, _l in PAGES if n != OWN))
            return 2
        named, problem = read_links(rest[0])
        if problem:
            sys.stderr.write("%s\n" % problem)
            return 2
        argv = argv[:cut] + ["--link"] + rest[1:]
    # annotation removed on install
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
    unknown = sorted(flags - {"--no-write", "--strict", "--blast", "--cite", "--html",
                              "--link"})
    if unknown:
        sys.stderr.write("unknown flag(s): %s\nusage: srs_grounds.py "
                         "[--no-write] [--strict] [--blast PATH…] [--cite ID…] "
                         "[--html [--link PAGE,…]]\n" % " ".join(unknown))
        return 2
    if "--link" in flags and "--html" not in flags:
        sys.stderr.write("--link belongs to --html: the dashboard's markdown links nothing\n")
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

    # annotation removed on install
    # A page on stdout is a page alone: the findings move to the other stream so that
    # redirecting the output gives a file and not a file with a report in its head.
    said = sys.stderr if "--html" in flags else sys.stdout
    # annotation removed on install
    for line in reports:
        said.write("report: %s\n" % line)
    for line in warnings:
        said.write("warning: %s\n" % line)
    for line in errors:
        said.write("error: %s\n" % line)

    # annotation removed on install
    if "--html" in flags:
        # A broken register produces no dashboard in either form.
        if errors:
            said.write("\nRecords: %d. Errors: %d. Nothing printed.\n"
                       % (len(records), len(errors)))
            return 1
        sys.stdout.write(to_page(build_dashboard(records, model, incoming or {}, cfg), named))
        said.write("\nRecords: %d. Errors: 0. Warnings: %d. Page printed. (srs_grounds %s)\n"
                   % (len(records), len(warnings), __version__))
        if warnings and "--strict" in flags:
            said.write("strict mode: %d warning(s) treated as errors.\n" % len(warnings))
            return 1
        return 0
    # annotation removed on install

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
# annotation removed on install


if __name__ == "__main__":
    sys.exit(main())
