#!/usr/bin/env python3
#
# SRS-DD-0.24.0 — the framework release this file came from
# annotation removed on install
# Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License
# annotation removed on install
"""The architecture layer's checker: reads arch/, holds it to the specification, writes the map.

    python3 srs-dd/tools/srs_arch.py              read, report, regenerate arch/90-map.md
    python3 srs-dd/tools/srs_arch.py --no-write   report only
    python3 srs-dd/tools/srs_arch.py --strict     treat warnings as errors
    python3 srs-dd/tools/srs_arch.py --cite E-NNN… name elements to a person
    python3 srs-dd/tools/srs_arch.py --drivers    the requirements that drive the cut
    python3 srs-dd/tools/srs_arch.py --plan       what moving to the designed parts requires
    python3 srs-dd/tools/srs_arch.py --draft      a cut to argue with, from the files no part carries
    python3 srs-dd/tools/srs_arch.py --price parts|areas|proposed
                                                  what a cut costs: links inside, out and in

The requirement model is read by running srs-dd/tools/srs_view.py as a subprocess and parsing what it
publishes, which the framework promises to keep stable, so this file never learns the requirement
format. The layer's own records go through srs-dd/tools/srs_parse.py, the one reader both formats share.

Nothing here writes outside arch/: declining the layer, or deleting it, has to cost nothing.
"""
# file annotation removed on install
# file annotation removed on install
import ast
import datetime
import json
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
        "srs-dd/tools/srs_parse.py: missing — the architecture checker reads the record shape through "
        "it, and the two travel together. Copy it beside this file from the framework clone, or "
        "re-run tools/srs_init.py to refresh the tooling.\n")
    sys.exit(2)

# Re-exported: the number lives in srs_parse, the one file every checker must
# have beside it.
__version__ = srs_parse.__version__

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARCH = os.path.join(ROOT, "arch")
GROUNDS = os.path.join(ROOT, "grounds")
CONFIG = os.path.join(ARCH, "arch-config.json")
EDGES = os.path.join(ARCH, "edges.json")
EDGES_REL = os.path.join("arch", "edges.json")
# annotation removed on install
UNITS = os.path.join(ARCH, "units.json")
UNITS_REL = os.path.join("arch", "units.json")
# annotation removed on install
MAP = os.path.join(ARCH, "90-map.md")
MAP_REL = os.path.join("arch", "90-map.md")
VIEWER = os.path.join(ROOT, "srs-dd", "tools", "srs_view.py")

# Files in arch/ that hold no records.
SKIP_FILES = {"README.md", "90-map.md"}

# Loose enough to catch a heading that meant to be a record and failed, so that
# the identifier rule can say so instead of passing it over in silence.
RE_HEADING = re.compile(r"^###\s+([A-Za-z][A-Za-z0-9]*-\d+(?:-[A-Za-z0-9]+)*)\s*(?:[—–-]\s*)?(.*)$")
RE_ID = re.compile(r"^E-%s$" % srs_parse.NUMBER)   # annotation removed on install
# annotation removed on install
RE_MOVE = re.compile(r"^M-%s$" % srs_parse.NUMBER)
# annotation removed on install

REQUIRED_KEYS = ("status", "carries", "requirements")
STATUSES = ("proposed", "built", "superseded", "withdrawn")
CANCELLED = ("superseded", "withdrawn")
REALIZED = ("implemented", "partial")

# annotation removed on install
# Designed and not built: it names where its files will be and owns none of them.
DESIGNED = ("proposed",)
NOT_OWNING = CANCELLED + DESIGNED
# annotation removed on install

# annotation removed on install
# Approved and unbuilt: what a cut is designed against.
APPROVED = ("deferred",)
# annotation removed on install

# annotation removed on install
# A move's keys and statuses; the two closed ones have left the model.
MOVE_KEYS = ("status", "from", "to", "moves", "adr")
MOVE_STATUSES = ("planned", "moving", "done", "abandoned")
MOVE_CLOSED = ("done", "abandoned")
# annotation removed on install

# annotation removed on install
# Published names: a project writes them into arch/arch-config.json, so one is never renamed and
# never given to a different rule.
RULES = ("element-cancelled", "carrier-unclaimed", "requirement-uncarried", "element-empty",
         "dependency-undeclared", "element-cycle", "carrier-missing",
         "requirement-unassigned", "element-built", "move-complete", "move-orphan",
         "dependency-forbidden", "interface-bypassed", "protects-uncarried",
         "element-ungrounded", "dependency-upward", "import-forbidden",
         "carrier-contested", "dependency-unpermitted", "unit-absent",
         "unit-unclaimed", "link-undeclared")
# annotation removed on install

# `warn` fails a --strict run, `report` is printed and fails nothing, `off` is not printed at all.
SEVERITIES = ("warn", "report", "off")

# annotation removed on install
# What a rule costs where the project has not said: a backlog is a note, not a warning.
# annotation removed on install
# The facts about units usually come from a repository this one does not own, so a
# disagreement with them is a conversation between two teams and not a build to fail;
# a project whose own pipeline produces them knows better and can price them up.
DEFAULT_SEVERITY = {"requirement-unassigned": "report", "unit-absent": "report",
                    "unit-unclaimed": "report", "link-undeclared": "report"}
# annotation removed on install
# annotation removed on install

# annotation removed on install
# How the `requirements` field is kept. `written` is the author's claim and the default;
# `derived` counts as carried what the element owns, and the record's key becomes optional.
MODES = ("written", "derived")
# annotation removed on install


def fail_setup(message):
    """Something the layer could not be read through at all — exit 2, never 1."""
    sys.stderr.write("%s\n" % message)
    return 2


# annotation removed on install
def load_config():
    """What each rule costs, as the project set it, and how the requirements are kept. A
    missing file means every default."""
    cfg = {"rules": {}, "requirements": "written", "forbidden": [], "layers": [],
           "forbidden_imports": [], "only": []}
    if not os.path.exists(CONFIG):
        return cfg, None
    try:
        with open(CONFIG, encoding="utf-8") as handle:
            raw = json.load(handle)
    except (OSError, ValueError) as exc:
        return None, "arch/arch-config.json: %s" % exc
    if not isinstance(raw, dict):
        return None, "arch/arch-config.json: the top level must be a JSON object"
    rules = raw.get("rules", {})
    if not isinstance(rules, dict):
        return None, "arch/arch-config.json: `rules` must be an object"
    for name, severity in rules.items():
        if name not in RULES:
            return None, ("arch/arch-config.json: unknown rule %r — this checker publishes %s"
                          % (name, ", ".join(RULES)))
        if severity not in SEVERITIES:
            return None, ("arch/arch-config.json: rule %r is %r, expected %s"
                          % (name, severity, "/".join(SEVERITIES)))
    cfg["rules"] = rules
    # annotation removed on install
    mode = raw.get("requirements", "written")
    if mode not in MODES:
        return None, ("arch/arch-config.json: `requirements` is %r, expected %s"
                      % (mode, "/".join(MODES)))
    cfg["requirements"] = mode
    # annotation removed on install
    # What the project forbids: two ends and the sentence its failure prints. An entry that
    # resolves to nothing reads as enforced and enforces nothing, so it is refused here.
    forbidden = raw.get("forbidden", [])
    if not isinstance(forbidden, list):
        return None, "arch/arch-config.json: `forbidden` must be a JSON list"
    for index, entry in enumerate(forbidden):
        where = "arch/arch-config.json: forbidden entry %d" % index
        if not isinstance(entry, dict):
            return None, "%s must be an object with `from`, `to` and `why`" % where
        for key in ("from", "to", "why"):
            value = entry.get(key)
            if not isinstance(value, str) or not value.strip():
                return None, "%s: `%s` must be text" % (where, key)
        if entry["from"] == "*" and entry["to"] == "*":
            return None, ("%s forbids every dependency, which is a typo for one side or the "
                          "other" % where)
        for key in ("from", "to"):
            if entry[key] != "*" and not RE_ID.match(entry[key]):
                return None, "%s: `%s` is %r, expected an element identifier or *" % (
                    where, key, entry[key])
    cfg["forbidden"] = forbidden
    # annotation removed on install
    # annotation removed on install
    # The order of the cut, top down: the first group may lean on every other and the last on
    # none. A part named in two groups has no place in it — every edge touching that part would
    # be judged both ways — so the order is refused here rather than read as policy.
    layers = raw.get("layers", [])
    if not isinstance(layers, list) or not all(isinstance(group, list) for group in layers):
        return None, "arch/arch-config.json: `layers` must be a JSON list of groups"
    placed = {}
    for index, group in enumerate(layers):
        for value in group:
            if not isinstance(value, str) or not RE_ID.match(value):
                return None, ("arch/arch-config.json: layers group %d holds %r, expected an "
                              "element identifier" % (index, value))
            if value in placed:
                return None, ("arch/arch-config.json: %s is in groups %d and %d, so the order "
                              "does not say where it stands" % (value, placed[value], index))
            placed[value] = index
    cfg["layers"] = layers
    # annotation removed on install
    # annotation removed on install
    # What a part may not import: the part, the module and the sentence its failure prints. The
    # far end is outside this system, so `depends_on` has nothing to name and the policy lives
    # here beside the forbidden pairs.
    banned = raw.get("forbidden_imports", [])
    if not isinstance(banned, list):
        return None, "arch/arch-config.json: `forbidden_imports` must be a JSON list"
    for index, entry in enumerate(banned):
        where = "arch/arch-config.json: forbidden_imports entry %d" % index
        if not isinstance(entry, dict):
            return None, "%s must be an object with `in`, `module` and `why`" % where
        for key in ("in", "module", "why"):
            value = entry.get(key)
            if not isinstance(value, str) or not value.strip():
                return None, "%s: `%s` must be text" % (where, key)
        if not RE_ID.match(entry["in"]):
            return None, "%s: `in` is %r, expected an element identifier" % (where, entry["in"])
    cfg["forbidden_imports"] = banned
    # annotation removed on install
    # annotation removed on install
    # Who may reach a part, said once instead of as a prohibition per other part. An empty `from`
    # says nobody may, which is a prohibition with a wildcard and not an allow-list, so it is a
    # typo for the other form and is refused here.
    only = raw.get("only", [])
    if not isinstance(only, list):
        return None, "arch/arch-config.json: `only` must be a JSON list"
    for index, entry in enumerate(only):
        where = "arch/arch-config.json: only entry %d" % index
        if not isinstance(entry, dict):
            return None, "%s must be an object with `to`, `from` and `why`" % where
        for key in ("to", "why"):
            value = entry.get(key)
            if not isinstance(value, str) or not value.strip():
                return None, "%s: `%s` must be text" % (where, key)
        if not RE_ID.match(entry["to"]):
            return None, "%s: `to` is %r, expected an element identifier" % (where, entry["to"])
        reachers = entry.get("from")
        if not isinstance(reachers, list) or not reachers:
            return None, ("%s: `from` must be a non-empty list of element identifiers — an empty "
                          "one says no part may reach it, which is a prohibition" % where)
        for value in reachers:
            if not isinstance(value, str) or not RE_ID.match(value):
                return None, ("%s: `from` holds %r, expected an element identifier"
                              % (where, value))
    cfg["only"] = only
    # annotation removed on install
    return cfg, None
    # annotation removed on install
# annotation removed on install


# annotation removed on install
def load_units_file(today=None):
    """The facts the project supplied about its units, as (facts, problem, note).

    `facts` is None where there are none to use, which is both an absent file and one whose own
    stated life has run out: facts taken together are one reading of the system, and half a stale
    reading is not a fresher one. `note` is what the run has to say about that, since a run that
    used nothing must not look like one that found nothing, the point the standard makes about
    reading the code. A shape this cannot read is a setup fault and comes back as `problem`.
    """
    if not os.path.exists(UNITS):
        return None, None, None
    try:
        with open(UNITS, encoding="utf-8") as handle:
            raw = json.load(handle)
    except (OSError, ValueError) as exc:
        return None, "%s: %s" % (UNITS_REL, exc), None
    if not isinstance(raw, dict):
        return None, "%s: the top level must be a JSON object" % UNITS_REL, None
    for key in ("taken", "source"):
        if not isinstance(raw.get(key), str) or not raw[key].strip():
            return None, "%s: `%s` must be text" % (UNITS_REL, key), None
    try:
        taken = datetime.date(*[int(part) for part in raw["taken"].split("-")])
    except (TypeError, ValueError):
        return None, ("%s: `taken` is %r, expected a date as YYYY-MM-DD"
                      % (UNITS_REL, raw["taken"])), None
    names = raw.get("units")
    if not isinstance(names, list) or any(not isinstance(n, str) or not n.strip() for n in names):
        return None, "%s: `units` must be a JSON list of names" % UNITS_REL, None
    links = raw.get("links", [])
    if not isinstance(links, list):
        return None, "%s: `links` must be a JSON list" % UNITS_REL, None
    pairs = []
    for index, link in enumerate(links):
        where = "%s: link %d" % (UNITS_REL, index)
        if not isinstance(link, dict):
            return None, "%s must be an object with `from` and `to`" % where, None
        for key in ("from", "to"):
            if not isinstance(link.get(key), str) or not link[key].strip():
                return None, "%s: `%s` must be text" % (where, key), None
        pairs.append((link["from"], link["to"]))
    life = raw.get("life")
    if life is not None and (isinstance(life, bool) or not isinstance(life, int) or life < 0):
        return None, ("%s: `life` is %r, expected a whole number of days"
                      % (UNITS_REL, life)), None
    facts = {"taken": taken, "source": raw["source"], "life": life,
             "units": sorted(set(names)), "links": pairs}
    if life is not None:
        age = ((today or datetime.date.today()) - taken).days
        if age > life:
            return None, None, ("the facts in %s, taken from %s on %s, are %d days old and their "
                                "producer says they stay true for %d, so none of them was used: "
                                "nothing here was compared with the units"
                                % (UNITS_REL, raw["source"], raw["taken"], age, life))
    return facts, None, None
# annotation removed on install


# annotation removed on install
def units_of(records):
    """Which parts ship in each unit, computed from the names the parts claim.

    Written on the parts and nowhere else, so the two sides cannot disagree: a unit is a name, not
    a record, and what it holds is this.
    """
    held = {}
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED:
            continue
        for name in as_list(record.fields.get("units")):
            held.setdefault(name, []).append(record.id)
    return {name: sorted(ids, key=srs_parse.id_key) for name, ids in held.items()}
# annotation removed on install


# annotation removed on install
def load_edges():
    """The edges the project computed, as [(from, to, via)]; no file means no edges.

    A shape this cannot read is a setup fault, not a finding, and an end that is an element
    identifier is refused — the file names files.
    """
    if not os.path.exists(EDGES):
        return [], None
    try:
        with open(EDGES, encoding="utf-8") as handle:
            raw = json.load(handle)
    except (OSError, ValueError) as exc:
        return None, "%s: %s" % (EDGES_REL, exc)
    if not isinstance(raw, list):
        return None, "%s: the top level must be a JSON list" % EDGES_REL
    edges = []
    for index, entry in enumerate(raw):
        where = "%s: entry %d" % (EDGES_REL, index)
        if not isinstance(entry, dict):
            return None, "%s must be an object with `from` and `to`" % where
        ends = []
        for key in ("from", "to"):
            value = entry.get(key)
            if not isinstance(value, str) or not value:
                return None, "%s: `%s` must be a repository-relative file path" % (where, key)
            if RE_ID.match(value):
                return None, ("%s: `%s` is %s — the file names files, not elements; a part "
                              "depending on a part is written in `depends_on`" % (where, key, value))
            ends.append(value.rstrip("/"))
        via = entry.get("via", "")
        if not isinstance(via, str):
            return None, "%s: `via` must be text" % where
        edges.append((ends[0], ends[1], via))
    return edges, None
# annotation removed on install


# annotation removed on install
def rule_finding(warnings, reports, cfg, rule, text):
    """Route one rule's finding by what the project decided it costs, or by what the rule costs
    where the project has not said."""
    severity = cfg["rules"].get(rule, DEFAULT_SEVERITY.get(rule, "warn"))
    if severity == "off":
        return
    (warnings if severity == "warn" else reports).append(text)
# annotation removed on install


# annotation removed on install
def read_model():
    """The requirement model, through the viewer's published JSON — a subprocess, since the
    viewer is a command with a promised output and its internals are not."""
    if not os.path.exists(VIEWER):
        return None, "srs-dd/tools/srs_view.py is not here — the architecture checker reads the " \
                     "requirement model through it"
    try:
        done = subprocess.run([sys.executable, VIEWER, "--json"], stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE)
    except OSError as exc:
        return None, "could not run srs-dd/tools/srs_view.py: %s" % exc
    if done.returncode != 0:
        return None, "srs-dd/tools/srs_view.py exited %d: %s" % (
            done.returncode, done.stderr.decode("utf-8", "replace").strip())
    try:
        return json.loads(done.stdout.decode("utf-8")), None
    except ValueError as exc:
        return None, "srs-dd/tools/srs_view.py produced unreadable JSON: %s" % exc
# annotation removed on install


# annotation removed on install
def collect_files():
    """Every record file in the layer, subdirectories included."""
    out = []
    if not os.path.isdir(ARCH):
        return out
    for current, dirs, files in os.walk(ARCH):
        dirs.sort()
        for name in sorted(files):
            if not name.endswith(".md") or name in SKIP_FILES:
                continue
            full = os.path.join(current, name)
            out.append((full, os.path.relpath(full, ROOT)))
    return sorted(out, key=lambda pair: pair[1])
# annotation removed on install


# annotation removed on install
def read_grounds():
    """What each requirement rests on — `{requirement: [(hypothesis, status), …]}` — or None
    where the project keeps no register. Read through the register's own reader, imported from
    beside this file: the format of a record is that layer's business and not this one's.
    A bet that was retired is past, and a hypothesis a bet names and the register does not hold
    is the register's own finding to report, not this layer's."""
    if not os.path.isdir(GROUNDS):
        return None
    try:
        import srs_grounds
    except ImportError:
        return None
    unread = []
    records = srs_grounds.read_records(unread)
    hypotheses = {rid: rec for rid, rec in records.items() if rec.kind == "H"}
    rests = {}
    for rec in records.values():
        if rec.kind != "B" or rec.fields.get("status") == "retired":
            continue
        requirement = as_list(rec.fields.get("requirement"))
        named = as_list(rec.fields.get("all_of")) + as_list(rec.fields.get("any_of"))
        for rid in requirement:
            for hid in named:
                if hid not in hypotheses:
                    continue
                status = hypotheses[hid].fields.get("status")
                if isinstance(status, list):
                    status = status[0] if status else ""
                pair = (hid, status or "?")
                if pair not in rests.setdefault(rid, []):
                    rests[rid].append(pair)
    for rid in rests:
        rests[rid].sort(key=lambda pair: srs_parse.id_key(pair[0]))
    return rests


def stands_on(record, model, cfg, rests):
    """The hypotheses the obligations of one element rest on, with their state, in the order the
    specification holds its requirements."""
    written, computed = carried_by([record], model, cfg)
    order = spec_order(model)
    out = []
    for rid in sorted(written[record.id] | computed[record.id], key=order):
        for hid, status in rests.get(rid, ()):
            out.append((rid, hid, status))
    return out
# annotation removed on install


# annotation removed on install
def read_records(errors):
    """Every element the layer holds, in the order the files present them."""
    records = []
    for full, rel in collect_files():
        try:
            with open(full, encoding="utf-8") as handle:
                text = handle.read()
        except (OSError, UnicodeDecodeError) as exc:
            errors.append("%s — cannot read the file: %s" % (rel, exc))
            continue
        for entry in srs_parse.parse_entries(text, rel, errors, RE_HEADING):
            records.append(entry)
    return records
# annotation removed on install


def as_list(value):
    """A bracketed list as the parser left it, or a single value as a list of one."""
    if isinstance(value, list):
        return value
    if value is None or value == "":
        return []
    return [value]


# annotation removed on install
def partition(records, errors):
    """The layer's records by kind, told apart by the prefix of the identifier.

    A heading that is neither is reported here and reaches no check.
    """
    elements, moves = [], []
    for record in records:
        if RE_ID.match(record.id):
            elements.append(record)
        elif RE_MOVE.match(record.id):
            moves.append(record)
        else:
            errors.append("%s — identifier does not match E-<NNN> or M-<NNN>" % record.where)
    return elements, moves
# annotation removed on install


# annotation removed on install
def check_moves(moves, errors):
    """An identifier used twice, a required key absent, a status outside the four — the readings
    an element's record gets, and errors for the same reason."""
    seen = {}
    for record in moves:
        if record.id in seen:
            errors.append("%s — %s is already used at %s"
                          % (record.where, record.id, seen[record.id]))
            continue
        seen[record.id] = record.where
        for key in MOVE_KEYS:
            if key not in record.fields:
                errors.append("%s — required key %r is missing" % (record.where, key))
        status = record.fields.get("status")
        if status is not None and status not in MOVE_STATUSES:
            errors.append("%s — status %r is not one of %s"
                          % (record.where, status, ", ".join(MOVE_STATUSES)))
# annotation removed on install


# annotation removed on install
def check_grounded(records, model, warnings, reports, cfg, rests):
    """A part carrying a requirement that rests on ground the register has lost. `refuted` and
    `expired` only: `assumed` is the ordinary state of a register and would fire on everything."""
    if not rests:
        return
    titles = {r["id"]: r.get("title", "") for r in model["requirements"]}
    for record in sorted(records, key=lambda r: srs_parse.id_key(r.id)):
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED:
            continue
        for rid, hid, status in stands_on(record, model, cfg, rests):
            if status not in ("refuted", "expired"):
                continue
            rule_finding(warnings, reports, cfg, "element-ungrounded",
                         "%s — %s carries %s, which rests on %s (%s)"
                         % (record.where, record.id, rid, hid, status))
# annotation removed on install


# annotation removed on install
def check_moves_resolve(moves, elements, model, errors):
    """A move names parts and a decision that exist.

    The decision is resolved against the documents the viewer publishes, so the layer never learns
    where a project keeps them; that one is named after the record's value is the whole question.
    """
    present = set(record.id for record in elements)
    documents = [os.path.basename(path) for path in (model.get("documents") or ())]
    for record in moves:
        if not RE_MOVE.match(record.id):
            continue
        for key in ("from", "to"):
            for target in as_list(record.fields.get(key)):
                if target not in present:
                    errors.append("%s — %s names %s in `%s`, which no element carries"
                                  % (record.where, record.id, target, key))
        adr = record.fields.get("adr")
        if adr and not any(name == "%s.md" % adr or name.startswith("%s-" % adr)
                           for name in documents):
            errors.append("%s — %s names %s, and the specification holds no document named "
                          "after it" % (record.where, record.id, adr))
# annotation removed on install


# annotation removed on install
def check_move_state(moves, elements, warnings, reports, cfg):
    """Where a move in force has got to, read off what the elements at its ends claim.

    Claims and not ownership, since a move is carried out by editing records. A path at
    both ends has not arrived; one at neither cannot be moved as written.
    """
    by_id = dict((record.id, record) for record in elements)

    def claims(key, record):
        carriers = {}
        for eid in as_list(record.fields.get(key)):
            element = by_id.get(eid)
            if element is None:
                continue
            for path in as_list(element.fields.get("carries")):
                carriers.setdefault(path.rstrip("/"), []).append(eid)
        return carriers

    for record in moves:
        if not RE_MOVE.match(record.id) or record.fields.get("status") in MOVE_CLOSED:
            continue
        leaving, arriving = claims("from", record), claims("to", record)
        paths = [path.rstrip("/") for path in as_list(record.fields.get("moves"))]
        arrived = []
        for path in paths:
            at_to = owner_of(path, arriving) is not None
            at_from = owner_of(path, leaving) is not None
            if not at_to and not at_from:
                rule_finding(warnings, reports, cfg, "move-orphan",
                             "%s — %s moves %s, which no element at either end carries"
                             % (record.where, record.id, path))
            arrived.append(at_to and not at_from)
        if paths and all(arrived):
            rule_finding(warnings, reports, cfg, "move-complete",
                         "%s — %s has every path it moves at %s and none at %s, and its status "
                         "still says %s" % (record.where, record.id,
                                            ", ".join(as_list(record.fields.get("to"))) or "nothing",
                                            ", ".join(as_list(record.fields.get("from"))) or "nothing",
                                            record.fields.get("status")))
# annotation removed on install


# annotation removed on install
def check_records(records, model, errors, warnings, reports, cfg):
    """Everything decidable from one element and the requirement model."""
    seen = {}
    by_id = {r["id"]: r for r in model["requirements"]}
    derived = cfg["requirements"] == "derived"
    computed = carried_by(records, model, cfg)[1]
    for record in records:
        if not RE_ID.match(record.id):
            continue
        if record.id in seen:
            errors.append("%s — %s is already used at %s" % (record.where, record.id,
                                                             seen[record.id]))
            continue
        seen[record.id] = record.where

        for key in REQUIRED_KEYS:
            # The standard requires the field only where it is written.
            if key == "requirements" and derived:
                continue
            if key not in record.fields:
                errors.append("%s — required key %r is missing" % (record.where, key))
        status = record.fields.get("status")
        if status is not None and status not in STATUSES:
            errors.append("%s — status %r is not one of %s"
                          % (record.where, status, ", ".join(STATUSES)))

        cancelled = status in CANCELLED
        named = as_list(record.fields.get("requirements"))
        for rid in named:
            requirement = by_id.get(rid)
            if requirement is None:
                errors.append("%s — %s names %s, which the specification does not carry"
                              % (record.where, record.id, rid))
                continue
            if requirement.get("status") in CANCELLED:
                rule_finding(warnings, reports, cfg, "element-cancelled",
                             "%s — %s carries %s, which is %s"
                             % (record.where, record.id, rid, requirement["status"]))
        # Over what the element carries, not what it names: under `derived` a record naming
        # nothing may carry a dozen, and a dissolved part answers for nothing.
        carried = named or computed.get(record.id)
        if not carried and not cancelled and ("requirements" in record.fields or derived):
            rule_finding(warnings, reports, cfg, "element-empty",
                         "%s — %s carries no requirement, so nothing says what it is for"
                         % (record.where, record.id))
# annotation removed on install


# annotation removed on install
def check_ownership(records, model, warnings, reports, cfg):
    """Three directions of the same decay: a file no part owns, a realized requirement no part
    carries, and an approved one no part has been designed for.

    `carried` is ownership of files, which a design has not got; `claimed` is which obligations a
    part answers for, which a design has.
    """
    carried = set()
    claimed = set()
    written, computed = carried_by(records, model, cfg)
    for record in records:
        if not RE_ID.match(record.id):
            continue
        if record.fields.get("status") in CANCELLED:
            continue
        if record.fields.get("status") not in DESIGNED:
            for path in as_list(record.fields.get("carries")):
                carried.add(path.rstrip("/"))
        claimed.update(written[record.id])
        claimed.update(computed[record.id])

    for requirement in model["requirements"]:
        # annotation removed on install
        # The only reading that says a design is unfinished before any code exists.
        if requirement.get("status") in APPROVED and requirement["id"] not in claimed:
            rule_finding(warnings, reports, cfg, "requirement-unassigned",
                         "%s — %s is %s and no element answers for it"
                         % (requirement["path"], requirement["id"], requirement["status"]))
        # annotation removed on install
        if requirement.get("status") not in REALIZED:
            continue
        if requirement["id"] not in claimed:
            rule_finding(warnings, reports, cfg, "requirement-uncarried",
                         "%s — %s is %s and no element carries it"
                         % (requirement["path"], requirement["id"], requirement["status"]))
        for path in (requirement.get("code") or []):
            if owner_of(path, carried) is None:
                rule_finding(warnings, reports, cfg, "carrier-unclaimed",
                             "%s — named by %s and carried by no element"
                             % (path, requirement["id"]))
# annotation removed on install


# annotation removed on install
def check_designed_built(records, model, warnings, reports, cfg):
    """A designed part whose files all exist and whose obligations are all realized: built, with
    only its status still saying otherwise."""
    by_id = {r["id"]: r for r in model["requirements"]}
    written, computed = carried_by(records, model, cfg)
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") not in DESIGNED:
            continue
        carries = written[record.id] | computed[record.id]
        # A record carrying nothing is the empty-element finding, not this one.
        if not carries:
            continue
        if any(by_id.get(rid, {}).get("status") not in REALIZED for rid in carries):
            continue
        if not all(os.path.exists(os.path.join(ROOT, path.rstrip("/")))
                   for path in as_list(record.fields.get("carries"))):
            continue
        rule_finding(warnings, reports, cfg, "element-built",
                     "%s — %s is %s, and every file it carries exists and every requirement it "
                     "carries is realized" % (record.where, record.id,
                                              record.fields.get("status")))
# annotation removed on install


def where_git_put(path):
    """Where git says a path went, as a clause for the finding, or "" where it cannot tell:
    a rename in the tree, then in the history, then a deletion. Read-only, and silent
    without git — a finding must not depend on a tool that may be absent.
    """
    def git(*args):
        try:
            # quotePath off: a path outside ASCII would otherwise come back quoted and
            # octal-escaped, and never equal the one the record wrote.
            run = subprocess.run(["git", "-c", "core.quotePath=false"] + list(args),
                                 capture_output=True, text=True, cwd=ROOT)
        except OSError:
            return ""
        return run.stdout if run.returncode == 0 else ""
    # Uncommitted: `R100\told\tnew` lines, against the index and the tree.
    for scope in (["diff", "--name-status", "-M", "HEAD"], ["diff", "--name-status", "-M", "--cached"]):
        for line in git(*scope).splitlines():
            parts = line.split("\t")
            if len(parts) == 3 and parts[0].startswith("R") and parts[1] == path:
                return "; renamed to %s in the working tree" % parts[2]
    # The newest commit that touched the path, then its whole diff: a pathspec on the log
    # would report every rename as a deletion (git-log(1)).
    commit = git("log", "-1", "--format=%h", "--", path).strip()
    if commit:
        for line in git("show", "--name-status", "-M", "--format=", commit).splitlines():
            parts = line.split("\t")
            if parts[0].startswith("R") and len(parts) == 3 and parts[1] == path:
                return "; git renamed it to %s in %s" % (parts[2], commit)
            if parts[0] == "D" and len(parts) == 2 and parts[1] == path:
                return "; git deleted it in %s" % commit
    return ""


# annotation removed on install
def check_carriers_exist(records, warnings, reports, cfg):
    """A path an element carries that nobody has, with where git says the file went.

    A designed part is exempt: its files are missing by construction.
    """
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED + DESIGNED:
            continue
        for path in as_list(record.fields.get("carries")):
            clean = path.rstrip("/")
            if os.path.exists(os.path.join(ROOT, clean)):
                continue
            rule_finding(warnings, reports, cfg, "carrier-missing",
                         "%s — %s carries %s, which does not exist%s"
                         % (record.where, record.id, clean, where_git_put(clean)))
# annotation removed on install


# annotation removed on install
def live_carriers(records):
    """Every carrier an element owns, as carrier -> [elements], for owner_of to resolve against.

    A cancelled element owns nothing, and a designed one does not own it yet.
    """
    owners = {}
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in NOT_OWNING:
            continue
        for path in as_list(record.fields.get("carries")):
            owners.setdefault(path.rstrip("/"), []).append(record.id)
    return owners
# annotation removed on install


# annotation removed on install
def carried_by(records, model, cfg):
    """What each element carries, as ({id: written}, {id: derived}): the record's claim and the
    derivation's, kept apart because they are two claims.

    The derived set is empty under `written`, and for an element that owns nothing.
    """
    written, derived = {}, {}
    for record in records:
        if not RE_ID.match(record.id):
            continue
        written[record.id] = set(as_list(record.fields.get("requirements")))
        derived[record.id] = set()
    owners = live_carriers(records)
    if cfg["requirements"] == "derived":
        for requirement in model["requirements"]:
            if requirement.get("status") not in REALIZED:
                continue
            for path in requirement.get("code") or []:
                for element in owners.get(owner_of(path, owners), ()):
                    derived[element].add(requirement["id"])
    return written, derived
# annotation removed on install


def spec_order(model):
    """A sort key placing identifiers the way the specification does: by type, then by the
    area order the project declared, then by number."""
    types = list(model.get("types") or ())
    areas = list(model.get("areas") or ())

    def key(rid):
        parts = rid.split("-")
        kind, area = parts[0], parts[1] if len(parts) > 2 else ""
        number = parts[-1]
        return (types.index(kind) if kind in types else len(types),
                areas.index(area) if area in areas else len(areas),
                int(number) if number.isdigit() else 0, rid)
    return key


# annotation removed on install
def owner_of(path, carried):
    """The carrier that covers a path: the path itself, or a directory above it, which owns
    what is under it."""
    if path in carried:
        return path
    parts = path.split("/")
    for depth in range(len(parts) - 1, 0, -1):
        prefix = "/".join(parts[:depth])
        if prefix in carried:
            return prefix
    return None
# annotation removed on install


# annotation removed on install
def python_modules(records):
    """Every Python file the layer carries, as path -> element, plus the names that resolve.

    Which part a file belongs to is asked of `element_of`, the one resolution the layer's standard
    states — the most specific claim, and nobody where two claim it equally. Assigning it here per
    record instead let the last record in the file win, so a part inside another owned its files
    or did not depending on the order the records were written in.

    Two maps, because a bare module name is not unique: a name two carried files answer to
    resolves to neither.
    """
    owners = live_carriers(records)
    carried = set()
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in NOT_OWNING:
            continue
        for path in as_list(record.fields.get("carries")):
            full = os.path.join(ROOT, path)
            if os.path.isfile(full) and path.endswith(".py"):
                carried.add(path)
            elif os.path.isdir(full):
                for current, dirs, files in os.walk(full):
                    dirs[:] = [d for d in dirs if not d.startswith(".")]
                    for name in sorted(files):
                        if name.endswith(".py"):
                            carried.add(os.path.relpath(os.path.join(current, name), ROOT))
    by_path = {}
    for path in sorted(carried):
        element = element_of(path, owners)
        if element is not None:
            by_path[path] = element
    by_name = {}
    for path in sorted(by_path):
        by_name.setdefault(os.path.basename(path)[:-3], []).append(path)
    # A name two carried files answer to resolves to neither: reporting it against whichever file
    # was read last is how this rule would name an element the importer never touched.
    unique = {name: paths[0] for name, paths in by_name.items() if len(paths) == 1}
    return by_path, unique
# annotation removed on install


# annotation removed on install
def imports_of(path):
    """The module names one file imports, as written."""
    try:
        with open(path, encoding="utf-8") as handle:
            tree = ast.parse(handle.read())
    except (OSError, UnicodeDecodeError, SyntaxError):
        return []
    names = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            names.extend(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            names.append(node.module)
    return [name.split(".")[0] for name in names]
# annotation removed on install


# annotation removed on install
def declared_dependencies(records):
    """The graph the elements declare, live elements only, in one place — two readings of
    `depends_on` would disagree about who is in the graph. Targets are kept as written.
    """
    declared = {}
    for record in records:
        if RE_ID.match(record.id) and record.fields.get("status") not in CANCELLED:
            declared[record.id] = set(as_list(record.fields.get("depends_on")))
    return declared
# annotation removed on install


# annotation removed on install
def check_dependencies_resolve(records, errors):
    """A dependency names an element the layer carries; its own walk after every record is
    read, since one declared further down the file would otherwise be reported absent."""
    present = set(record.id for record in records if RE_ID.match(record.id))
    for record in records:
        if record.id not in present:
            continue
        for target in as_list(record.fields.get("depends_on")):
            if target not in present:
                errors.append("%s — %s depends on %s, which no element carries"
                              % (record.where, record.id, target))
# annotation removed on install


# annotation removed on install
def check_cycles(records, warnings, reports, cfg):
    """Elements that depend on each other in a circle, each circle named once.

    A warning, where the same finding between requirements is an error: nothing here is
    broken by a circle. A dependency naming no element ends the path, not the walk.
    """
    declared = declared_dependencies(records)
    where = dict((record.id, record.where) for record in records)
    colour = {}
    stack = []

    def walk(node):
        colour[node] = "grey"
        stack.append(node)
        for target in sorted(declared.get(node, ()), key=srs_parse.id_key):
            # Cancelled or never declared: a path ends here, and the name stays out of the
            # walk's own bookkeeping so a circle is never reported through it.
            if target not in declared:
                continue
            if colour.get(target) == "grey":
                circle = stack[stack.index(target):]
                # The degenerate circle has no "each other" in it, and is located at the element it is
                # named from, since a circle has no line of its own.
                if len(circle) == 1:
                    text = "%s — %s depends on itself" % (where[node], node)
                else:
                    text = ("%s — elements depend on each other in a circle: %s"
                            % (where[target], " → ".join(circle + [target])))
                rule_finding(warnings, reports, cfg, "element-cycle", text)
            elif target not in colour:
                walk(target)
        stack.pop()
        colour[node] = "black"

    for node in sorted(declared, key=srs_parse.id_key):
        if node not in colour:
            walk(node)
# annotation removed on install


# annotation removed on install
def element_of(path, owners):
    """The one element that carries a path, or None."""
    carrier = owner_of(path, owners)
    if carrier is None or len(owners[carrier]) != 1:
        return None
    return owners[carrier][0]
# annotation removed on install


# annotation removed on install
def check_protects(records, model, errors, warnings, reports, cfg):
    """What a part was cut to keep: a subset of what it carries, and an existing requirement.

    Empty is ordinary and silent. An identifier the specification does not carry is an error for
    the reason an unresolvable name always is here; one the part does not itself carry is a claim
    about somebody else's boundary.
    """
    known = set(r["id"] for r in model["requirements"])
    written, computed = carried_by(records, model, cfg)
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED:
            continue
        held = written[record.id] | computed[record.id]
        for rid in as_list(record.fields.get("protects")):
            if rid not in known:
                errors.append("%s — %s protects %s, which the specification does not carry"
                              % (record.where, record.id, rid))
            elif rid not in held:
                rule_finding(warnings, reports, cfg, "protects-uncarried",
                             "%s — %s protects %s and does not carry it"
                             % (record.where, record.id, rid))
# annotation removed on install


# annotation removed on install
def check_interfaces(records, edges, warnings, reports, cfg):
    """A part entered by a name its own `interface` does not state.

    What crosses a boundary is what the other side writes down — a module it imports, a path it
    was given — so the comparison is against the names, not against the files. A part that
    declares no interface is left to the rule that names what nobody has said: saying it twice
    would have a project price both away.
    """
    def states(face, name):
        # As a name and not as a substring: a one-letter module would otherwise be found
        # inside any word of the sentence, and the rule would pass for the wrong reason.
        return re.search(r"(?<![\w.])%s(?![\w.])" % re.escape(name), face) is not None

    faces = {}
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED:
            continue
        face = record.fields.get("interface")
        if face:
            faces[record.id] = face
    by_path, unique = python_modules(records)
    for path in sorted(by_path):
        for name in imports_of(os.path.join(ROOT, path)):
            target_path = unique.get(name)
            if target_path is None:
                continue
            target = by_path[target_path]
            if target == by_path[path] or target not in faces:
                continue
            if not states(faces[target], name):
                rule_finding(warnings, reports, cfg, "interface-bypassed",
                             "%s reaches %s by `%s`, which its interface does not state"
                             % (path, target, name))
    owners = live_carriers(records)
    for source, target_path, via in edges:
        element, target = element_of(source, owners), element_of(target_path, owners)
        if element is None or target is None or element == target or target not in faces:
            continue
        if not states(faces[target], target_path):
            rule_finding(warnings, reports, cfg, "interface-bypassed",
                         "%s reaches %s by `%s`, which its interface does not state"
                         % (source, target, target_path))
# annotation removed on install


# annotation removed on install
def dependency_pairs(records, edges):
    """Every dependency between two parts this checker can see, as (source, target, how).

    Three suppliers — the model a person declared, the imports of the one language read here, and
    the edges the project supplied — and `how` is what a finding prints, so a reader knows which
    of the three it came from. Shared by the two rules that judge an edge against a policy
    instead of against the model.
    """
    declared = declared_dependencies(records)
    pairs = [(source, target, "the model declares it")
             for source in sorted(declared, key=srs_parse.id_key)
             for target in sorted(declared[source], key=srs_parse.id_key)]
    by_path, unique = python_modules(records)
    for path in sorted(by_path):
        for name in imports_of(os.path.join(ROOT, path)):
            target_path = unique.get(name)
            if target_path is not None and by_path[target_path] != by_path[path]:
                pairs.append((by_path[path], by_path[target_path], "%s imports %s" % (path, name)))
    owners = live_carriers(records)
    for source, target_path, via in edges:
        element, target = element_of(source, owners), element_of(target_path, owners)
        if element is not None and target is not None and element != target:
            pairs.append((element, target, "%s uses %s" % (source, target_path)))
    return pairs
# annotation removed on install


# annotation removed on install
def check_forbidden(records, edges, errors, warnings, reports, cfg):
    """Dependencies the project said must not exist, in the model and in the code alike.

    A prohibition naming an element no record defines is refused here rather than reported: the
    entry resolves to nothing, and the layer would be enforcing a policy about a part nobody has.
    """
    present = set(record.id for record in records if RE_ID.match(record.id))
    for index, entry in enumerate(cfg["forbidden"]):
        for key in ("from", "to"):
            if entry[key] != "*" and entry[key] not in present:
                errors.append("arch/arch-config.json: forbidden entry %d names %s in `%s`, "
                              "which no element carries" % (index, entry[key], key))
    if errors:
        return

    def forbids(entry, source, target):
        return ((entry["from"] == "*" or entry["from"] == source)
                and (entry["to"] == "*" or entry["to"] == target))

    pairs = dependency_pairs(records, edges)

    said = set()
    for source, target, how in pairs:
        for entry in cfg["forbidden"]:
            if not forbids(entry, source, target) or (source, target, how) in said:
                continue
            said.add((source, target, how))
            rule_finding(warnings, reports, cfg, "dependency-forbidden",
                         "%s depends on %s and the project forbids it (%s): %s"
                         % (source, target, how, entry["why"]))
# annotation removed on install


# annotation removed on install
def sits_inside(records):
    """For each element, the elements carrying a path above one of its own.

    A part nests inside another when a path it carries lies under a path the other carries. It is
    the relation the resolution of a path to a part reads downward, read upward here, so the two
    cannot disagree about what nests in what.
    """
    owners = live_carriers(records)
    inside = {}
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in NOT_OWNING:
            continue
        above = set()
        for path in as_list(record.fields.get("carries")):
            pieces = path.rstrip("/").split("/")
            for depth in range(len(pieces) - 1, 0, -1):
                for other in owners.get("/".join(pieces[:depth]), ()):
                    if other != record.id:
                        above.add(other)
        if above:
            inside[record.id] = sorted(above, key=srs_parse.id_key)
    return inside


def placed_in_order(cfg):
    """Which group of the declared order each element stands in, by its number in the file."""
    return {element: index for index, group in enumerate(cfg["layers"]) for element in group}
# annotation removed on install


# annotation removed on install
def check_only(records, edges, errors, warnings, reports, cfg):
    """Who may reach a part, and the edges that come from anywhere else.

    The mirror of a prohibition: there the named pair is refused, here everything but the named
    few is. An entry about a part no record defines resolves to nothing and fails the run, the way
    a prohibition naming no part does.
    """
    if not cfg["only"]:
        return
    present = set(record.id for record in records if RE_ID.match(record.id))
    unknown = []
    for index, entry in enumerate(cfg["only"]):
        for eid in [entry["to"]] + list(entry["from"]):
            if eid not in present:
                unknown.append("arch/arch-config.json: only entry %d names %s, which no element "
                               "carries" % (index, eid))
    if unknown:
        errors.extend(unknown)
        return
    allowed = {}
    for entry in cfg["only"]:
        allowed.setdefault(entry["to"], []).append(entry)
    said = set()
    for source, target, how in dependency_pairs(records, edges):
        for entry in allowed.get(target, ()):
            if source in entry["from"] or (source, target, how) in said:
                continue
            said.add((source, target, how))
            rule_finding(warnings, reports, cfg, "dependency-unpermitted",
                         "%s depends on %s, which only %s may reach (%s): %s"
                         % (source, target, " and ".join(sorted(entry["from"], key=srs_parse.id_key)),
                            how, entry["why"]))
# annotation removed on install


# annotation removed on install
def check_units(records, facts, warnings, reports, cfg):
    """The units the parts name against the units the project says it has, both ways, and the
    links the facts hold against the dependencies the parts declare.

    One direction for the links, as for the code: facts about a system show what happened or what
    is permitted and never that something cannot happen. A link whose end no part names is left
    alone — that unit has already been reported as unknown, and saying it twice would have a
    project price both away.
    """
    if facts is None:
        return
    held = units_of(records)
    there = set(facts["units"])
    for name in sorted(held):
        if name not in there:
            rule_finding(warnings, reports, cfg, "unit-absent",
                         "the unit %s is named by %s and the facts do not hold it"
                         % (name, " and ".join(held[name])))
    for name in sorted(there - set(held)):
        rule_finding(warnings, reports, cfg, "unit-unclaimed",
                     "the facts hold the unit %s and no part names it" % name)
    declared = declared_dependencies(records)
    for source, target in facts["links"]:
        if source == target or source not in held or target not in held:
            continue
        if any(other in declared.get(element, ()) for element in held[source]
               for other in held[target]):
            continue
        rule_finding(warnings, reports, cfg, "link-undeclared",
                     "the facts link the unit %s to %s, and none of %s declares a dependency on "
                     "any of %s" % (source, target, " and ".join(held[source]),
                                    " and ".join(held[target])))
# annotation removed on install


# annotation removed on install
def check_code_read(records, edges, reports):
    """Whether this run compared the declared model with anything at all.

    The checker reads one language itself and takes every other one from the edges a project
    supplies; with neither there is nothing that can ever disagree with the model, and a run with
    no findings then says only that nothing was read. Not a rule the project prices: it is not a
    finding about the cut but a statement about what the run proved, and a project able to switch
    it off would be switching off the line that says its conformance check never ran.
    """
    if edges:
        return
    by_path, _names = python_modules(records)
    if by_path:
        return
    reports.append("no file an element carries is in a language this checker reads and "
                   "arch/edges.json is absent, so the declared model was compared with nothing: "
                   "no dependency was read from the code, which is not the same as finding none")
# annotation removed on install


# annotation removed on install
def check_contested(records, warnings, reports, cfg):
    """A path that more than one element in force claims.

    The layer's standard gives such a path to none of them, which is the right answer and a silent
    one: every rule that needs an owner then says nothing about that file, and the silence reads
    as conformance. This says why it is silent.
    """
    owners = live_carriers(records)
    for path in sorted(owners):
        if len(owners[path]) > 1:
            rule_finding(warnings, reports, cfg, "carrier-contested",
                         "%s is carried by %s, so it belongs to none of them"
                         % (path, " and ".join(sorted(owners[path], key=srs_parse.id_key))))
# annotation removed on install


# annotation removed on install
def check_forbidden_imports(records, errors, warnings, reports, cfg):
    """A module a part may not import, where the language of its files can be read.

    The far end is outside the system, so there is no element to name and no edge to declare:
    this is policy about what a part may build with, and it is read from the imports the checker
    already reads for the model. An entry about a part nobody has resolves to nothing and fails
    the run, the way a prohibition naming no part does.
    """
    if not cfg["forbidden_imports"]:
        return
    present = set(record.id for record in records if RE_ID.match(record.id))
    unknown = ["arch/arch-config.json: forbidden_imports entry %d names %s in `in`, which no "
               "element carries" % (index, entry["in"])
               for index, entry in enumerate(cfg["forbidden_imports"])
               if entry["in"] not in present]
    if unknown:
        errors.extend(unknown)
        return
    banned = {}
    for entry in cfg["forbidden_imports"]:
        banned.setdefault(entry["in"], []).append(entry)
    by_path, _names = python_modules(records)
    for path in sorted(by_path):
        entries = banned.get(by_path[path])
        if not entries:
            continue
        imported = set(imports_of(os.path.join(ROOT, path)))
        for entry in entries:
            if entry["module"] in imported:
                rule_finding(warnings, reports, cfg, "import-forbidden",
                             "%s imports %s, which %s may not: %s"
                             % (path, entry["module"], by_path[path], entry["why"]))
# annotation removed on install


# annotation removed on install
def check_layers(records, edges, errors, warnings, reports, cfg):
    """A dependency that runs against the order of groups the project declared.

    An element in no group is outside the order and nothing is said about it: that is how an
    order is adopted on a cut that already exists, one group at a time. Within one group nothing
    is reported either — a group is the level, and a project that wants two of its parts
    separated puts each in a group of its own.
    """
    if not cfg["layers"]:
        return
    present = set(record.id for record in records if RE_ID.match(record.id))
    place, unknown = {}, []
    for index, group in enumerate(cfg["layers"]):
        for element in group:
            if element not in present:
                unknown.append("arch/arch-config.json: layers group %d names %s, which no "
                               "element carries" % (index, element))
            else:
                place[element] = index
    if unknown:
        errors.extend(unknown)
        return
    said = set()
    for source, target, how in dependency_pairs(records, edges):
        if source not in place or target not in place:
            continue
        if place[target] >= place[source] or (source, target, how) in said:
            continue
        said.add((source, target, how))
        rule_finding(warnings, reports, cfg, "dependency-upward",
                     "%s in group %d depends on %s in group %d, which the order puts above it "
                     "(%s)" % (source, place[source], target, place[target], how))
# annotation removed on install


# annotation removed on install
def check_conformance(records, edges, warnings, reports, cfg):
    """The declared model against the one the code has, one direction only: an edge the code
    has and the model does not.

    Two suppliers, the imports read here and the edges the project supplies, into one `seen`
    set, so a pair is reported once.
    """
    by_path, unique = python_modules(records)
    declared = declared_dependencies(records)
    seen = set()

    def undeclared(element, target):
        if target == element or target in declared.get(element, set()):
            return False
        if (element, target) in seen:
            return False
        seen.add((element, target))
        return True

    for path in sorted(by_path):
        element = by_path[path]
        for name in imports_of(os.path.join(ROOT, path)):
            target_path = unique.get(name)
            if target_path is None:
                continue
            target = by_path[target_path]
            if undeclared(element, target):
                rule_finding(warnings, reports, cfg, "dependency-undeclared",
                             "%s — imports %s, carried by %s, and %s does not declare it"
                             % (path, name, target, element))

    # annotation removed on install
    # An end no single live element carries resolves to nothing and the edge is left alone, as an
    # import that resolves to no carried module is: the rule speaks only about what it can prove.
    owners = live_carriers(records)
    for source, target_path, via in edges:
        element, target = element_of(source, owners), element_of(target_path, owners)
        if element is None or target is None:
            continue
        if undeclared(element, target):
            rule_finding(warnings, reports, cfg, "dependency-undeclared",
                         "%s — uses %s, carried by %s, and %s does not declare it%s"
                         % (source, target_path, target, element,
                            " (%s)" % via if via else ""))
    # annotation removed on install
# annotation removed on install


# annotation removed on install
def print_draft(records, model, cfg, unread=()):
    """A cut to argue with, not a cut: the files no part carries, grouped by the directory they
    sit in, each group written out as a record to rename, split, merge and paste in.

    The join is the checker's own — what `carrier-unclaimed` reports, read the other way round —
    so a project adopting the layer on a mature codebase starts from the specification's own
    answer instead of from a blank file.
    """
    carried = live_carriers(records)
    taken = {r.id for r in records if RE_ID.match(r.id)}
    groups = {}
    for requirement in model["requirements"]:
        if requirement.get("status") not in REALIZED:
            continue
        for path in (requirement.get("code") or []):
            if owner_of(path, carried) is not None:
                continue
            where = os.path.dirname(path) or "."
            group = groups.setdefault(where, {"files": [], "requirements": []})
            if path not in group["files"]:
                group["files"].append(path)
            if requirement["id"] not in group["requirements"]:
                group["requirements"].append(requirement["id"])
    out = sys.stdout.write
    if unread:
        out("%d record(s) could not be read and are not accounted for here; the checker names "
            "them.\n\n" % len(unread))
    if not groups:
        out("Every file a realized requirement names is carried by a part: there is nothing to "
            "draft.\n")
        return 0
    order = spec_order(model)
    numbers = sorted(int(rid.split("-")[1]) for rid in taken) or [0]
    nxt = numbers[-1] + 10
    out("A draft cut, printed and never written: %d director%s holding files no part carries.\n"
        "A part has a responsibility and a name, and neither is computable — rename, split and "
        "merge these, then paste what survives into arch/00-elements.md.\n\n"
        % (len(groups), "y" if len(groups) == 1 else "ies"))
    for where in sorted(groups):
        group = groups[where]
        out("### E-%03d — <what %s is responsible for>\n\n" % (nxt, where))
        out("```yaml\nstatus: built\ncarries: [%s]\n" % ", ".join(sorted(group["files"])))
        out("requirements: [%s]\n"
            % ", ".join(sorted(group["requirements"], key=order)))
        out("depends_on: []\ninterface: <how this part is reached from outside>\n```\n\n")
        out("<One sentence: what this part answers for. An \"and\" in it is two parts.>\n\n")
        nxt += 10
    return 0
# annotation removed on install


# annotation removed on install
def print_plan(records, model, cfg, unread=()):
    """What moving to the designed parts requires: files changing hands with both ends named,
    obligations changing part, and the dependencies the design adds and drops.

    Printed and reported as nothing: the difference is the normal state of designing.
    """
    designed = [r for r in records
                if RE_ID.match(r.id) and r.fields.get("status") in DESIGNED]
    out = sys.stdout
    if unread:
        out.write("%d record(s) could not be read and are not in this plan; the checker names "
                  "them.\n" % len(unread))
    if not designed:
        out.write("No part is designed and unbuilt, so there is nothing to move.\n")
        return 0

    owners = live_carriers(records)          # built parts only: a design owns nothing yet
    written, computed = carried_by(records, model, cfg)
    titles = dict((r.id, r.title) for r in records if RE_ID.match(r.id))
    holders = {}
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED + DESIGNED:
            continue
        for rid in written[record.id] | computed[record.id]:
            holders.setdefault(rid, []).append(record.id)
    declared = declared_dependencies(records)
    designed_carriers = {}
    for record in designed:
        for path in as_list(record.fields.get("carries")):
            designed_carriers.setdefault(path.rstrip("/"), []).append(record.id)

    out.write("What moving to the designed parts requires. Printed, never decided: the records "
              "stay the author's.\n")
    order = spec_order(model)
    for record in sorted(designed, key=lambda r: srs_parse.id_key(r.id)):
        out.write("\n%s — %s\n" % (record.id, record.title))
        for path in as_list(record.fields.get("carries")):
            clean = path.rstrip("/")
            # Absent before owned: a path nobody has changes no hands, and resolving it would
            # name the part carrying the directory above it as losing a file it never held.
            if not os.path.exists(os.path.join(ROOT, clean)):
                note = "not in the repository yet"
            else:
                carrier = owner_of(clean, owners)
                note = ("from %s" % ", ".join(sorted(owners[carrier], key=srs_parse.id_key))
                        if carrier is not None else "no part owns it today")
            out.write("    file  %s — %s\n" % (clean, note))
        for rid in sorted(written[record.id] | computed[record.id], key=order):
            where = ", ".join(sorted(holders.get(rid, ()), key=srs_parse.id_key))
            out.write("    holds %s — %s\n"
                      % (rid, "from %s" % where if where else "no part carries it today"))
        for target in sorted(declared.get(record.id, ()), key=srs_parse.id_key):
            out.write("    needs %s — a dependency the built parts do not have\n" % target)

    # A built part the design claims every file of is being dissolved, and its edges go with it.
    dissolving = []
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED + DESIGNED:
            continue
        paths = [p.rstrip("/") for p in as_list(record.fields.get("carries"))]
        if not paths or not all(owner_of(path, designed_carriers) is not None
                                for path in paths):
            continue
        dissolving.append(record.id)
    if dissolving:
        out.write("\nFalls away:\n")
        for eid in sorted(dissolving, key=srs_parse.id_key):
            out.write("    %s — %s keeps no file of its own under the design\n"
                      % (eid, titles.get(eid, eid)))
            for target in sorted(declared.get(eid, ()), key=srs_parse.id_key):
                out.write("    %s → %s — the dependency goes with it\n" % (eid, target))
    return 0
# annotation removed on install


# annotation removed on install
def links_of(model):
    """Every link between two requirements, as pairs, from what the viewer publishes under
    `incoming` — the one place that holds them all, so no list of link fields is copied here."""
    pairs = []
    for target, named in sorted(model.get("incoming", {}).items()):
        for entry in named:
            if len(entry) == 2:
                pairs.append((entry[1], target))
    return pairs


def price_cut(groups, model):
    """What a cut costs, group by group: links with both ends inside, links leaving, links
    arriving. `groups` is {name: {requirement, …}}; a requirement in no group is counted once at
    the end, because a cut that covers less than the specification is the first thing to say."""
    member = {}
    for name, held in groups.items():
        for rid in held:
            member[rid] = name
    rows = {name: {"inside": 0, "out": 0, "in": 0} for name in groups}
    for source, target in links_of(model):
        here, there = member.get(source), member.get(target)
        if here is None and there is None:
            continue
        if here == there:
            rows[here]["inside"] += 1
        else:
            if here is not None:
                rows[here]["out"] += 1
            if there is not None:
                rows[there]["in"] += 1
    uncovered = sorted((r["id"] for r in model["requirements"]
                        if r["id"] not in member and r.get("status") not in CANCELLED),
                       key=srs_parse.id_key)
    return rows, uncovered


def print_price(groups, model, title, titles=None):
    """The price of one cut, widest group first: the reading is comparative, so the order is the
    one that puts the parts worth arguing about at the top."""
    rows, uncovered = price_cut(groups, model)
    out = sys.stdout.write
    # Distinct, not the sum: a requirement two parts both answer for is covered once, and the
    # sum would say the cut covers more than the specification holds.
    covered = len(set().union(*groups.values()) if groups else set())
    out("%s — %d group(s), %d of %d requirements covered.\n"
        "Links with both ends inside a group, then leaving it, then arriving.\n\n"
        % (title, len(groups), covered,
           len([r for r in model["requirements"] if r.get("status") not in CANCELLED])))
    for name in sorted(groups, key=lambda n: (-len(groups[n]), n)):
        count = rows[name]
        out("%-12s %4d held · %4d inside · %4d out · %4d in%s\n"
            % (name, len(groups[name]), count["inside"], count["out"], count["in"],
               "   %s" % titles[name] if titles and name in titles else ""))
    if uncovered:
        out("\n%d requirement(s) in no group: %s\n"
            % (len(uncovered), ", ".join(uncovered[:12])
               + (", …" if len(uncovered) > 12 else "")))
    return 0


def groups_of_parts(records, model, cfg):
    """The cut the layer holds: one group per element in force, holding what it carries."""
    written, computed = carried_by(records, model, cfg)
    groups, titles = {}, {}
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED:
            continue
        groups[record.id] = written[record.id] | computed[record.id]
        titles[record.id] = record.title
    return groups, titles


def groups_of_areas(model):
    """The cut the specification already made: one group per area."""
    groups = {}
    for requirement in model["requirements"]:
        if requirement.get("status") in CANCELLED:
            continue
        area = requirement.get("area") or requirement["id"].split("-")[1]
        groups.setdefault(area, set()).add(requirement["id"])
    return groups
# annotation removed on install


# annotation removed on install
def propose_cut(model, seeds):
    """A cut from the links themselves: every requirement joins the driver it is nearest to over
    the links, a tie going to the lower identifier, and whatever no driver reaches forms the
    remainder. One walk from all the seeds at once, so the result is the same on every run."""
    neighbours = {}
    for source, target in links_of(model):
        neighbours.setdefault(source, set()).add(target)
        neighbours.setdefault(target, set()).add(source)
    standing = [r["id"] for r in model["requirements"] if r.get("status") not in CANCELLED]
    nearest = {}
    frontier = [(0, seed, seed) for seed in seeds if seed in set(standing)]
    while frontier:
        step = []
        for distance, seed, rid in sorted(frontier, key=lambda item: (item[0], item[1], item[2])):
            if rid in nearest:
                continue
            nearest[rid] = seed
            for other in sorted(neighbours.get(rid, ())):
                if other not in nearest:
                    step.append((distance + 1, seed, other))
        frontier = [item for item in step if item[2] not in nearest]
    groups = {}
    for rid in standing:
        groups.setdefault(nearest.get(rid, "—"), set()).add(rid)
    return groups
# annotation removed on install


# annotation removed on install
def print_drivers(model, limit=10):
    """The requirements that lead, by what makes a requirement drive structure.

    Incoming links first — over this repository the ones that took part in an architecture
    decision carry three times as many — and the type as the tie-break, because an interface or
    an invariant constrains structure by construction. Candidates for a person to accept: the
    trade-off nobody wrote down is not in the model to be found.
    """
    incoming = model.get("incoming", {})
    weight = {"IF": 0, "INV": 1, "CON": 2, "NFR": 3, "FR": 4}
    ranked = sorted(model["requirements"],
                    key=lambda r: (-len(incoming.get(r["id"], [])),
                                   weight.get(r["id"].split("-")[0], 9), r["id"]))
    sys.stdout.write("Architectural drivers, most constrained first. "
                     "A design is worked against a few of these, not all of them.\n\n")
    for entry in ranked[:limit]:
        sys.stdout.write("%s — %s (%s, %s)\n    %d incoming, type %s\n"
                         % (entry["id"], entry["title"], entry["path"], entry["status"],
                            len(incoming.get(entry["id"], [])), entry["id"].split("-")[0]))
    return 0
# annotation removed on install


# annotation removed on install
def render_map(records, model, cfg, moves=()):
    """The map, generated from the records and never edited by hand.

    Under `derived` an entry the record names is bold and one computed from what the element
    owns is plain, and the map says so above the table: the two are different claims, and a
    reader deciding whether a part answers for an obligation has to see which one they hold.
    """
    by_id = {r["id"]: r for r in model["requirements"]}
    derived = cfg["requirements"] == "derived"
    written, computed = carried_by(records, model, cfg)
    order = spec_order(model)
    out = ["# The map", "",
           "**Generated by `srs-dd/tools/srs_arch.py`. Do not edit by hand — "
           "run the command and commit the result.**", "",
           "What each part of this project is, what it carries and what state it is in.", ""]
    if derived:
        out += ["Requirements are derived: an entry in **bold** is one the record names, "
                "an entry in plain text one computed from what the element owns.", ""]
    # annotation removed on install
    inside, place = sits_inside(records), placed_in_order(cfg)
    out += ["| Element | Status | Where | Carries | Requirements |", "|---|---|---|---|---|"]
    carrying = set()
    for record in sorted(records, key=lambda r: srs_parse.id_key(r.id)):   # annotation removed on install
        if not RE_ID.match(record.id):
            continue
        carries = ", ".join("`%s`" % p for p in as_list(record.fields.get("carries"))) or "—"
        named = as_list(record.fields.get("requirements"))
        extra = sorted(computed[record.id] - set(named), key=order)
        shown = ", ".join(["**%s**" % rid for rid in named] + extra) or "—"
        held = set(named) | set(extra)
        carrying |= held
        live = sum(1 for rid in held if by_id.get(rid, {}).get("status") in REALIZED)
        where = ", ".join(
            ["inside **%s**" % other for other in inside.get(record.id, ())]
            + (["level %d" % place[record.id]] if record.id in place else [])) or "—"
        out.append("| **%s** %s | `%s` | %s | %s | %s (%d realized) |"
                   % (record.id, record.title, record.fields.get("status") or "?",
                      where, carries, shown, live))
    # annotation removed on install
    out.append("")
    out.append("%d elements, carrying %d of the %d requirements this specification holds."
               % (len([r for r in records if RE_ID.match(r.id)]),
                  len(carrying), len(model["requirements"])))
    out.append("")

    # annotation removed on install
    # Only the moves in force; no section where there are none.
    live = [record for record in sorted(moves, key=lambda r: srs_parse.id_key(r.id))
            if RE_MOVE.match(record.id) and record.fields.get("status") not in MOVE_CLOSED]
    if live:
        out += ["## What is moving", "",
                "| Move | Status | From | To | What moves |", "|---|---|---|---|---|"]
        for record in live:
            out.append("| **%s** %s | `%s` | %s | %s | %s |"
                       % (record.id, record.title, record.fields.get("status") or "?",
                          ", ".join(as_list(record.fields.get("from"))) or "—",
                          ", ".join(as_list(record.fields.get("to"))) or "—",
                          ", ".join("`%s`" % path
                                    for path in as_list(record.fields.get("moves"))) or "—"))
        out.append("")
    # annotation removed on install
    return "\n".join(out)
# annotation removed on install


# annotation removed on install
def citation(record):
    """The form an element is named in to a person — the one the viewer prints for a
    requirement, over this layer's own records: identifier, title, file, status."""
    return "%s — %s (%s, %s)" % (record.id, record.title, record.path,
                                  record.fields.get("status") or "?")
# annotation removed on install


# annotation removed on install
def cite(wanted):
    """Print each element asked for, ready to paste, in the order asked; an identifier no
    element carries is named on stderr and fails the run, in the same run as the rest."""
    known = {}
    for record in read_records([]):
        known.setdefault(record.id, record)
    missing = [eid for eid in wanted if eid not in known]
    for eid in wanted:
        if eid in known:
            sys.stdout.write("%s\n" % citation(known[eid]))
    for eid in missing:
        sys.stderr.write("no element %s\n" % eid)
    return 1 if missing else 0
# annotation removed on install


# annotation removed on install
def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    wanted = None
    if "--cite" in args:
        cut = args.index("--cite")
        wanted, args = args[cut + 1:], args[:cut]
        if not wanted:
            return fail_setup("--cite needs at least one element identifier\n"
                              "usage: srs_arch.py --cite E-NNN…")
    priced = None
    if "--price" in args:
        cut = args.index("--price")
        rest = args[cut + 1:]
        if not rest or rest[0] not in ("parts", "areas", "proposed"):
            return fail_setup("--price needs one of: parts, areas, proposed\n"
                              "usage: srs_arch.py --price parts|areas|proposed")
        priced = rest[0]
        args = args[:cut] + rest[1:]
    unknown = sorted(set(args) - {"--no-write", "--strict", "--drivers", "--plan", "--draft"})
    if unknown:
        return fail_setup("unknown flag(s): %s\n"
                          "usage: srs_arch.py [--no-write] [--strict] [--drivers] [--plan] "
                          "[--draft] [--price parts|areas|proposed] [--cite E-NNN…]"
                          % " ".join(unknown))
    strict = "--strict" in args
    write = "--no-write" not in args

    if not os.path.isdir(ARCH):
        return fail_setup("arch/ directory not found: %s\nThe architecture layer is optional; "
                          "install it with tools/srs_init.py --arch yes." % ARCH)
    if wanted is not None:
        return cite(wanted)

    cfg, problem = load_config()
    if problem:
        return fail_setup(problem)
    model, problem = read_model()
    if problem:
        return fail_setup(problem)
    edges, problem = load_edges()
    if problem:
        return fail_setup(problem)
    # annotation removed on install
    facts, problem, stale = load_units_file()
    if problem:
        return fail_setup(problem)
    # annotation removed on install

    if "--drivers" in args:
        return print_drivers(model)

    # A reading and not a check: nothing about the layer is held to anything here.
    if "--plan" in args:
        unread = []
        elements = partition(read_records(unread), unread)[0]
        return print_plan(elements, model, cfg, unread)

    # annotation removed on install
    if priced is not None:
        if priced == "areas":
            return print_price(groups_of_areas(model), model, "The areas the specification declares")
        if priced == "proposed":
            incoming = model.get("incoming", {})
            weight = {"IF": 0, "INV": 1, "CON": 2, "NFR": 3, "FR": 4}
            ranked = sorted(model["requirements"],
                            key=lambda r: (-len(incoming.get(r["id"], [])),
                                           weight.get(r["id"].split("-")[0], 9), r["id"]))
            seeds = [r["id"] for r in ranked[:10]]
            sys.stdout.write("A cut proposed from the links, seeded by the drivers: %s.\n"
                             "Printed, never written — a part has a responsibility and a name, "
                             "and neither is computable.\n\n" % ", ".join(seeds))
            return print_price(propose_cut(model, seeds), model, "The cut the links suggest")
        unread = []
        elements = partition(read_records(unread), unread)[0]
        groups, titles = groups_of_parts(elements, model, cfg)
        return print_price(groups, model, "The parts the layer holds", titles)
    # annotation removed on install

    # annotation removed on install
    if "--draft" in args:
        unread = []
        elements = partition(read_records(unread), unread)[0]
        return print_draft(elements, model, cfg, unread)
    # annotation removed on install

    errors, warnings, reports = [], [], []
    records = read_records(errors)
    elements, moves = partition(records, errors)
    check_records(elements, model, errors, warnings, reports, cfg)
    check_dependencies_resolve(elements, errors)
    check_ownership(elements, model, warnings, reports, cfg)
    check_contested(elements, warnings, reports, cfg)
    check_designed_built(elements, model, warnings, reports, cfg)
    check_carriers_exist(elements, warnings, reports, cfg)
    check_conformance(elements, edges, warnings, reports, cfg)
    check_code_read(elements, edges, reports)
    check_units(elements, facts, warnings, reports, cfg)
    # annotation removed on install
    # Said with the findings rather than swallowed: a run that used no facts must not
    # read like one that found nothing wrong with them.
    if stale:
        reports.append(stale)
    # annotation removed on install
    check_cycles(elements, warnings, reports, cfg)
    check_forbidden(elements, edges, errors, warnings, reports, cfg)
    check_layers(elements, edges, errors, warnings, reports, cfg)
    check_forbidden_imports(elements, errors, warnings, reports, cfg)
    check_only(elements, edges, errors, warnings, reports, cfg)
    check_interfaces(elements, edges, warnings, reports, cfg)
    check_protects(elements, model, errors, warnings, reports, cfg)
    check_grounded(elements, model, warnings, reports, cfg, read_grounds() or {})
    check_moves(moves, errors)
    check_moves_resolve(moves, elements, model, errors)
    check_move_state(moves, elements, warnings, reports, cfg)

    for text in warnings:
        sys.stdout.write("warning: %s\n" % text)
    for text in reports:
        sys.stdout.write("note: %s\n" % text)
    for text in errors:
        sys.stdout.write("error: %s\n" % text)

    moved = " Moves: %d." % len(moves) if moves else ""
    if errors:
        sys.stdout.write("\nElements: %d.%s Errors: %d. (srs_arch %s)\n"
                         % (len(elements), moved, len(errors), __version__))
        return 1

    if write:
        with open(MAP, "w", encoding="utf-8") as handle:
            handle.write(render_map(elements, model, cfg, moves))

    sys.stdout.write("Elements: %d.%s Errors: 0. Warnings: %d.%s (srs_arch %s)\n"
                     % (len(elements), moved, len(warnings),
                        " Map rewritten: %s." % MAP_REL if write else "", __version__))
    if strict and warnings:
        sys.stdout.write("strict mode: %d warning(s) treated as errors.\n" % len(warnings))
        return 1
    return 0
# annotation removed on install


if __name__ == "__main__":
    sys.exit(main())
