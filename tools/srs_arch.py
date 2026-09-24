#!/usr/bin/env python3
#
# SRS-DD-0.20.1 — the framework release this file came from
"""The architecture layer's checker: reads arch/, holds it to the specification, writes the map.

    python3 tools/srs_arch.py              read, report, regenerate arch/90-map.md
    python3 tools/srs_arch.py --no-write   report only
    python3 tools/srs_arch.py --strict     treat warnings as errors

The requirement model is read by running tools/srs_view.py as a subprocess and parsing what it
publishes, which the framework promises to keep stable, so this file never learns the requirement
format. The layer's own records go through tools/srs_parse.py, the one reader both formats share.

Nothing here writes outside arch/: declining the layer, or deleting it, has to cost nothing.
"""
# annotation removed on install
# annotation removed on install
import ast
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
        "tools/srs_parse.py: missing — the architecture checker reads the record shape through "
        "it, and the two travel together. Copy it beside this file from the framework clone, or "
        "re-run tools/srs_init.py to refresh the tooling.\n")
    sys.exit(2)

# Re-exported: the number lives in srs_parse, the one file every checker must have beside it
# (ADR-0021).
__version__ = srs_parse.__version__

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCH = os.path.join(ROOT, "arch")
CONFIG = os.path.join(ARCH, "arch-config.json")
EDGES = os.path.join(ARCH, "edges.json")
EDGES_REL = os.path.join("arch", "edges.json")
MAP = os.path.join(ARCH, "90-map.md")
MAP_REL = os.path.join("arch", "90-map.md")
VIEWER = os.path.join(ROOT, "tools", "srs_view.py")

# Files in arch/ that hold no records.
SKIP_FILES = {"README.md", "90-map.md"}

# Loose enough to catch a heading that meant to be a record and failed, so that
# the identifier rule can say so instead of passing it over in silence.
RE_HEADING = re.compile(r"^###\s+([A-Za-z][A-Za-z0-9]*-\d+(?:-[A-Za-z0-9]+)*)\s*(?:[—–-]\s*)?(.*)$")
RE_ID = re.compile(r"^E-%s$" % srs_parse.NUMBER)   # annotation removed on install

REQUIRED_KEYS = ("status", "carries", "requirements")
STATUSES = ("proposed", "built", "superseded", "withdrawn")
CANCELLED = ("superseded", "withdrawn")
REALIZED = ("implemented", "partial")

# annotation removed on install
# Published names: a project writes them into arch/arch-config.json, so one is never renamed and
# never given to a different rule.
RULES = ("element-cancelled", "carrier-unclaimed", "requirement-uncarried", "element-empty",
         "dependency-undeclared", "element-cycle", "carrier-missing")

# `warn` fails a --strict run, `report` is printed and fails nothing, `off` is not printed at all.
SEVERITIES = ("warn", "report", "off")

# annotation removed on install
# How the `requirements` field is kept. `written` is the author's claim and the default;
# `derived` counts as carried what the element owns, and the record's key becomes optional.
MODES = ("written", "derived")


def fail_setup(message):
    """Something the layer could not be read through at all — exit 2, never 1."""
    sys.stderr.write("%s\n" % message)
    return 2


def load_config():
    # annotation removed on install
    """What each rule costs, as the project set it, and how the requirements are kept. A
    missing file means every default."""
    cfg = {"rules": {}, "requirements": "written"}
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
    return cfg, None


def load_edges():
    # annotation removed on install
    """The edges the project computed, as [(from, to, via)]. No file means no edges.

    Two ends and a note, read as the interface publishes them and no further: a shape the
    checker cannot read is a setup fault (exit 2), not a finding, because nothing about the
    layer is wrong when the file is. An end that is an element identifier is refused with the
    reason — the file names files, and a list of parts depending on parts is `depends_on`.
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


def rule_finding(warnings, reports, cfg, rule, text):
    # annotation removed on install
    """Route one rule's finding by what the project decided it costs."""
    severity = cfg["rules"].get(rule, "warn")
    if severity == "off":
        return
    (warnings if severity == "warn" else reports).append(text)


def read_model():
    # annotation removed on install
    """The requirement model, through the viewer's published JSON.

    A subprocess rather than an import: the viewer is a command with a promised output, and
    borrowing its internals would tie this checker to a shape nothing guarantees.
    """
    if not os.path.exists(VIEWER):
        return None, "tools/srs_view.py is not here — the architecture checker reads the " \
                     "requirement model through it"
    try:
        done = subprocess.run([sys.executable, VIEWER, "--json"], stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE)
    except OSError as exc:
        return None, "could not run tools/srs_view.py: %s" % exc
    if done.returncode != 0:
        return None, "tools/srs_view.py exited %d: %s" % (
            done.returncode, done.stderr.decode("utf-8", "replace").strip())
    try:
        return json.loads(done.stdout.decode("utf-8")), None
    except ValueError as exc:
        return None, "tools/srs_view.py produced unreadable JSON: %s" % exc


def collect_files():
    # annotation removed on install
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


def read_records(errors):
    # annotation removed on install
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


def as_list(value):
    """A bracketed list as the parser left it, or a single value as a list of one."""
    if isinstance(value, list):
        return value
    if value is None or value == "":
        return []
    return [value]


def check_records(records, model, errors, warnings, reports, cfg):
    # annotation removed on install
    """Everything decidable from one element and the requirement model."""
    seen = {}
    by_id = {r["id"]: r for r in model["requirements"]}
    derived = cfg["requirements"] == "derived"
    computed = carried_by(records, model, cfg)[1]
    for record in records:
        if not RE_ID.match(record.id):
            errors.append("%s — identifier does not match E-<NNN>" % record.where)
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
        # A dissolved part has nothing left to answer for, and saying so
        # every run is how a report teaches its reader to skim it.
        # Over what the element carries, not what it names: under `derived` a record naming
        # nothing may carry a dozen, and one naming nothing and owning nothing is empty even
        # though no key is missing.
        carried = named or computed.get(record.id)
        if not carried and not cancelled and ("requirements" in record.fields or derived):
            rule_finding(warnings, reports, cfg, "element-empty",
                         "%s — %s carries no requirement, so nothing says what it is for"
                         % (record.where, record.id))


def check_ownership(records, model, warnings, reports, cfg):
    # annotation removed on install
    """The two directions of the same decay: a file no part owns, a requirement no part carries.

    Both are computed from what the specification already publishes, so neither needs the language
    of a file read.
    """
    carried = set()
    claimed = set()
    written, computed = carried_by(records, model, cfg)
    for record in records:
        if not RE_ID.match(record.id):
            continue
        if record.fields.get("status") in CANCELLED:
            continue
        for path in as_list(record.fields.get("carries")):
            carried.add(path.rstrip("/"))
        claimed.update(written[record.id])
        claimed.update(computed[record.id])

    for requirement in model["requirements"]:
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


def where_git_put(path):
    """Where git says a path went, as a clause for the finding, or "" where it cannot tell:
    a rename in the working tree, a rename in the history, a deletion in the history — asked
    in that order, since the first is what the reader is in the middle of. Read-only, and
    silent where there is no git, no history or no answer: a finding must not depend on a
    tool that may be absent."""
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
    # Committed: the newest commit that touched the path, then that commit's whole diff with
    # rename detection — a pathspec on the log would hide the other end of a rename and report
    # every rename as a deletion (git-log(1): rename detection needs both sides in the diff).
    commit = git("log", "-1", "--format=%h", "--", path).strip()
    if commit:
        for line in git("show", "--name-status", "-M", "--format=", commit).splitlines():
            parts = line.split("\t")
            if parts[0].startswith("R") and len(parts) == 3 and parts[1] == path:
                return "; git renamed it to %s in %s" % (parts[2], commit)
            if parts[0] == "D" and len(parts) == 2 and parts[1] == path:
                return "; git deleted it in %s" % commit
    return ""


def check_carriers_exist(records, warnings, reports, cfg):
    # annotation removed on install
    """A path an element carries that nobody has: the record still reads, and it lies in the
    commonest way a map goes stale, so a named warning with where git says the file went."""
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED:
            continue
        for path in as_list(record.fields.get("carries")):
            clean = path.rstrip("/")
            if os.path.exists(os.path.join(ROOT, clean)):
                continue
            rule_finding(warnings, reports, cfg, "carrier-missing",
                         "%s — %s carries %s, which does not exist%s"
                         % (record.where, record.id, clean, where_git_put(clean)))


def live_carriers(records):
    # annotation removed on install
    """Every carrier a live element claims, as carrier -> [elements]: the map owner_of resolves
    a file against, read by the derivation and by the edges the project supplies. A cancelled
    element owns nothing the way it depends on nothing."""
    owners = {}
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED:
            continue
        for path in as_list(record.fields.get("carries")):
            owners.setdefault(path.rstrip("/"), []).append(record.id)
    return owners


def carried_by(records, model, cfg):
    # annotation removed on install
    """What each element carries, as ({id: written}, {id: derived}) — two sets per element,
    kept apart because they are two claims: the record's, that the part answers for the
    obligation; the derivation's, that the part owns a file the obligation names.

    The derived set is empty under `written`, and empty for a cancelled element under either
    mode: a dissolved part owns nothing the way it depends on nothing. Ownership is decided by
    owner_of over every live carrier, so the file a requirement names lands in the element
    whose carrier is nearest — by the rule that decides whether a carrier is unclaimed at all.
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


def owner_of(path, carried):
    # annotation removed on install
    """The carrier that covers a path: the path itself, or a directory above it.

    A directory in `carries` owns what is under it, so a part is described once rather than
    re-listed every time a file is added beside its siblings.
    """
    if path in carried:
        return path
    parts = path.split("/")
    for depth in range(len(parts) - 1, 0, -1):
        prefix = "/".join(parts[:depth])
        if prefix in carried:
            return prefix
    return None


def python_modules(records):
    # annotation removed on install
    """Every Python file the layer carries, as path -> element, plus the names that resolve.

    Two maps rather than one, because a bare module name is not unique: `a/util.py` and
    `b/util.py` both answer to `util`, and a dictionary keyed by the name would report the import
    against whichever file was read last. A name only one carried file answers to resolves; the
    rest are left alone, which is the same rule the unresolvable import gets.
    """
    by_path = {}
    for record in records:
        if not RE_ID.match(record.id) or record.fields.get("status") in CANCELLED:
            continue
        for path in as_list(record.fields.get("carries")):
            full = os.path.join(ROOT, path)
            if os.path.isfile(full) and path.endswith(".py"):
                by_path[path] = record.id
            elif os.path.isdir(full):
                for current, dirs, files in os.walk(full):
                    dirs[:] = [d for d in dirs if not d.startswith(".")]
                    for name in sorted(files):
                        if name.endswith(".py"):
                            rel = os.path.relpath(os.path.join(current, name), ROOT)
                            by_path[rel] = record.id
    by_name = {}
    for path in sorted(by_path):
        by_name.setdefault(os.path.basename(path)[:-3], []).append(path)
    # A name two carried files answer to resolves to neither: reporting it against whichever file
    # was read last is how this rule would name an element the importer never touched.
    unique = {name: paths[0] for name, paths in by_name.items() if len(paths) == 1}
    return by_path, unique


def imports_of(path):
    # annotation removed on install
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


def declared_dependencies(records):
    # annotation removed on install
    """The graph the elements declare, live elements only.

    One place, read by the reflexion check and by the cycle walk: two readings of `depends_on`
    would one day disagree about which elements are in the graph. A cancelled element is out of
    it — it keeps its field for the record, and a circle surviving through it would be one
    nothing live can break. Targets are kept as written, resolving or not: nothing here checks
    that a dependency names an element, and the walk has to tolerate one that does not.
    """
    declared = {}
    for record in records:
        if RE_ID.match(record.id) and record.fields.get("status") not in CANCELLED:
            declared[record.id] = set(as_list(record.fields.get("depends_on")))
    return declared


def check_dependencies_resolve(records, errors):
    # annotation removed on install
    """A dependency names an element the layer carries.

    Its own walk after every record is read, not a clause of check_records: that one reads
    records one at a time, and an element declared further down the file would be reported as
    absent. A cancelled element is present — it has a status that says it left — and a
    dependency on it is not this rule's finding.
    """
    present = set(record.id for record in records if RE_ID.match(record.id))
    for record in records:
        if record.id not in present:
            continue
        for target in as_list(record.fields.get("depends_on")):
            if target not in present:
                errors.append("%s — %s depends on %s, which no element carries"
                              % (record.where, record.id, target))


def check_cycles(records, warnings, reports, cfg):
    # annotation removed on install
    """Elements that depend on each other in a circle, each circle named once.

    A warning with a name where the same finding between requirements is an error with none:
    nothing here is broken by a circle — the map renders, the reflexion check runs — and two
    parts that need each other are a fact about the code the project may choose to live with.
    A dependency naming no element ends the path rather than the walk.
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
                # The degenerate circle has no "each other" in it, and the layer has no rule
                # of its own for a self-reference the way the specification checker does.
                # Located at the element the circle is named from, since a circle has no
                # single line of its own and the other findings all start with a place.
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


def element_of(path, owners):
    # annotation removed on install
    """The one element that carries a path, or None."""
    carrier = owner_of(path, owners)
    if carrier is None or len(owners[carrier]) != 1:
        return None
    return owners[carrier][0]


def check_conformance(records, edges, warnings, reports, cfg):
    # annotation removed on install
    """The declared model against the one the code has.

    One direction only, as the requirement states it: an edge the code has and the model does not.
    The other direction — a declared edge nothing in the code walks — is a different reading and
    has no rule here.

    Two suppliers of edges and one comparison: the imports this checker reads from the Python it
    carries, and the edges the project put in arch/edges.json for the languages it does not read.
    Both land in the same `seen` set, so a pair is reported once whichever said it first.
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


def print_drivers(model, limit=10):
    # annotation removed on install
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


def render_map(records, model, cfg):
    # annotation removed on install
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
           "**Generated by `tools/srs_arch.py`. Do not edit by hand — "
           "run the command and commit the result.**", "",
           "What each part of this project is, what it carries and what state it is in.", ""]
    if derived:
        out += ["Requirements are derived: an entry in **bold** is one the record names, "
                "an entry in plain text one computed from what the element owns.", ""]
    out += ["| Element | Status | Carries | Requirements |", "|---|---|---|---|"]
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
        out.append("| **%s** %s | `%s` | %s | %s (%d realized) |"
                   % (record.id, record.title, record.fields.get("status") or "?",
                      carries, shown, live))
    out.append("")
    out.append("%d elements, carrying %d of the %d requirements this specification holds."
               % (len([r for r in records if RE_ID.match(r.id)]),
                  len(carrying), len(model["requirements"])))
    out.append("")
    return "\n".join(out)


def citation(record):
    # annotation removed on install
    """The form an element is named in to a person — the one the viewer prints for a
    requirement, over this layer's own records: identifier, title, file, status."""
    return "%s — %s (%s, %s)" % (record.id, record.title, record.path,
                                  record.fields.get("status") or "?")


def cite(wanted):
    # annotation removed on install
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


def main(argv=None):
    # annotation removed on install
    args = list(sys.argv[1:] if argv is None else argv)
    wanted = None
    if "--cite" in args:
        cut = args.index("--cite")
        wanted, args = args[cut + 1:], args[:cut]
        if not wanted:
            return fail_setup("--cite needs at least one element identifier\n"
                              "usage: srs_arch.py --cite E-NNN…")
    unknown = sorted(set(args) - {"--no-write", "--strict", "--drivers"})
    if unknown:
        return fail_setup("unknown flag(s): %s\n"
                          "usage: srs_arch.py [--no-write] [--strict] [--drivers] "
                          "[--cite E-NNN…]"
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

    if "--drivers" in args:
        return print_drivers(model)

    errors, warnings, reports = [], [], []
    records = read_records(errors)
    check_records(records, model, errors, warnings, reports, cfg)
    check_dependencies_resolve(records, errors)
    check_ownership(records, model, warnings, reports, cfg)
    check_carriers_exist(records, warnings, reports, cfg)
    check_conformance(records, edges, warnings, reports, cfg)
    check_cycles(records, warnings, reports, cfg)

    for text in warnings:
        sys.stdout.write("warning: %s\n" % text)
    for text in reports:
        sys.stdout.write("note: %s\n" % text)
    for text in errors:
        sys.stdout.write("error: %s\n" % text)

    if errors:
        sys.stdout.write("\nElements: %d. Errors: %d. (srs_arch %s)\n"
                         % (len(records), len(errors), __version__))
        return 1

    if write:
        with open(MAP, "w", encoding="utf-8") as handle:
            handle.write(render_map(records, model, cfg))

    sys.stdout.write("Elements: %d. Errors: 0. Warnings: %d.%s (srs_arch %s)\n"
                     % (len(records), len(warnings),
                        " Map rewritten: %s." % MAP_REL if write else "", __version__))
    if strict and warnings:
        sys.stdout.write("strict mode: %d warning(s) treated as errors.\n" % len(warnings))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
