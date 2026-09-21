#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.19.0 — the framework release this file came from
"""Specification integrity checker and traceability matrix generator.

Standard library only, compatible with Python 3.9. The specification
markup rules are described in specs/README.md — that file is the single
normative document; this script only enforces it.

    python3 tools/srs_check.py             check and rewrite 90-traceability.md
    python3 tools/srs_check.py --no-write  check only
    python3 tools/srs_check.py --strict    treat warnings as errors (CI)

Project-specific settings (requirement areas, code roots, source file
extensions, statement lexicon) live in specs/srs-config.json. The
defaults below apply for any key absent from that file. The script knows
no natural language: the modal verbs, negation words, and rationale
markers it matches all come from the lexicon in the config.
"""

# annotation removed on install

import json
import os
import re
import subprocess
import sys

# The record shape is read by tools/srs_parse.py, which ships beside
# this file; what stays here is the judgement (ADR-0019). Bytecode is
# disabled first: this tool runs inside other people's repositories,
# and a __pycache__ they did not ask for is litter.
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import srs_parse                                        # noqa: E402
except ImportError:
    # Exit 2, not a traceback: 2 is reserved for "could not run at
    # all", and a checker that dies on its own import has not read
    # anybody's specification. The case is reachable — the tooling can
    # be copied by hand, one file at a time (docs/install.md).
    sys.stderr.write(
        "tools/srs_parse.py: missing — the checker reads the record shape "
        "through it, and the two travel together. Copy it beside this file "
        "from the framework clone, or re-run tools/srs_init.py to refresh "
        "the tooling.\n")
    sys.exit(2)

# Re-exported: the number lives in srs_parse, the one file this checker
# and the grounds checker both must have beside them (ADR-0021).
__version__ = srs_parse.__version__

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPECS = os.path.join(ROOT, "specs")
TRACE = os.path.join(SPECS, "90-traceability.md")
CONFIG = os.path.join(SPECS, "srs-config.json")

# Files in specs/ that do not contain requirements.
SKIP_FILES = {"README.md", "00-glossary.md", "constitution.md",
              "90-traceability.md", "91-open-issues.md", "92-baselines.md"}
SKIP_DIRS = {"archive", "adr"}

# Fallbacks used for keys absent from specs/srs-config.json. Edit the
# config, not these constants.
DEFAULTS = {
    "areas": ["CORE", "UI", "API", "DATA", "SEC"],
    "code_roots": ["src"],
    "test_roots": ["tests"],
    "code_extensions": [".py", ".ts", ".tsx", ".js", ".swift", ".kt",
                        ".go", ".rs", ".java", ".c", ".cpp", ".h", ".m"],
    "modal_verbs": ["shall", "must", "should", "may"],
    "negation_words": ["not"],
    "rationale_markers": ["Rationale"],
}

# Uppercase, matching the annotation grammar and the installer's rule.
RE_AREA_NAME = re.compile(r"^[A-Z][A-Z0-9]*$")


# Every rule that reports something short of an error carries a name, so a
# project can say what it costs — in `rules` in its configuration, or in a
# requirement's `exempt` field. The names are a published contract with the
# same one-way property as a metadata key: adding one is compatible,
# renaming one is not (ADR-0009).
# annotation removed on install
RULES = ("unknown-key", "draft-with-code", "rests-on-draft",
         "rests-on-withdrawn", "test-missing", "unlinked",
         "annotation-unknown-area", "annotation-superseded",
         "annotation-unlisted", "annotation-unpaired", "annotation-absent",
         "baseline-without-row", "file-range")

# `warn` fails a --strict run, `report` is printed and fails nothing, `off`
# is not printed at all.
SEVERITIES = ("warn", "report", "off")


def _config_fail(message):
    sys.stderr.write("specs/srs-config.json: %s\n" % message)
    sys.exit(2)


def load_config():
    # annotation removed on install
    """Loads and validates the config; fails with a friendly message
    rather than letting a bad value crash regex compilation later."""
    data = {}
    if os.path.exists(CONFIG):
        try:
            with open(CONFIG, "r", encoding="utf-8") as handle:
                data = json.load(handle)
        except ValueError as exc:
            _config_fail("invalid JSON — %s" % exc)
        except OSError as exc:
            _config_fail("cannot read — %s" % exc)
        if not isinstance(data, dict):
            _config_fail("the top level must be a JSON object")
    cfg = {}
    for key, fallback in DEFAULTS.items():
        value = data.get(key, fallback)
        if not isinstance(value, list) \
                or not all(isinstance(v, str) and v for v in value):
            _config_fail("%s must be a list of non-empty strings" % key)
        cfg[key] = value
    for key in ("areas", "modal_verbs", "rationale_markers"):
        if not cfg[key]:
            _config_fail("%s must not be empty" % key)
    for area in cfg["areas"]:
        if not RE_AREA_NAME.match(area):
            _config_fail("area %r must match [A-Z][A-Z0-9]*" % area)
    # `rules` is a mapping rather than a list, so it is validated apart from
    # the loop above — and by name, because a silently ignored typo here
    # would look exactly like a rule that never fires.
    rules = data.get("rules", {})
    if not isinstance(rules, dict):
        _config_fail("rules must be an object of rule name to severity")
    for name in sorted(rules):
        if name not in RULES:
            _config_fail("rules names an unknown rule %r; the rules are %s"
                         % (name, ", ".join(RULES)))
        if rules[name] not in SEVERITIES:
            _config_fail("rules[%r] must be one of %s"
                         % (name, "/".join(SEVERITIES)))
    cfg["rules"] = rules
    return cfg


CFG = load_config()
AREAS = CFG["areas"]
CODE_ROOTS = CFG["code_roots"]
TEST_ROOTS = CFG["test_roots"]
CODE_EXTENSIONS = CFG["code_extensions"]
RULE_SEVERITY = CFG["rules"]


def rule_finding(warnings, reports, rule, text, req=None):
    # annotation removed on install
    """Route one rule's finding by what the project decided it costs.

    A requirement may excuse itself from a rule in its own block; the
    project may lower or silence the rule everywhere. Anything not spoken
    for is a warning, which is what a --strict gate fails on.
    """
    if req is not None and rule in (req.meta.get("exempt") or []):
        return
    severity = RULE_SEVERITY.get(rule, "warn")
    if severity == "off":
        return
    (warnings if severity == "warn" else reports).append(text)

TYPES = ("FR", "NFR", "IF", "INV", "CON")

# Lifecycle order; also the row order of the status table in the matrix.
STATUSES = ("draft", "deferred", "partial", "implemented", "superseded",
            "withdrawn")
# annotation removed on install
# A cancelled requirement is retained under one of these rather than
# deleted, which is what keeps its number from ever being free again.
# The two terminal states, told apart from the rest wherever a rule has
# nothing to say about a requirement that is over: it has no link left to
# forget and no ground left to rest on.
CANCELLED = ("superseded", "withdrawn")
VERIFICATIONS = ("T", "D", "I", "A")

LINK_FIELDS = ("derives_from", "refines", "depends_on", "conflicts_with")
LIST_FIELDS = LINK_FIELDS + ("code", "tests", "exempt")
SCALAR_FIELDS = ("status", "verification", "superseded_by", "created")
KNOWN_FIELDS = set(LIST_FIELDS) | set(SCALAR_FIELDS)

# Of the known keys, the ones a requirement must carry. Everything else is
# optional, and a key that is neither is not an error: that is what
# lets a later version of the format add one without breaking a
# specification written against an earlier version.
REQUIRED_FIELDS = ("status", "verification")


# Keys a later version of the format renamed or withdrew, as
# {old: (replacement or None, version)}. Empty until the format first
# moves. The checker reports them; it never rewrites a specification —
# that belongs to the project (ADR-0009).
RETIRED_FIELDS = {}


def _alternation(words):
    return "|".join(re.escape(w) for w in words)


# Capture, then judgement, deliberately far apart in strictness.
# RE_HEADING is a broad net: anything ID-shaped is taken, junk like
# FR-CORE-010-B included, and RE_ID judges it loudly afterwards — a
# malformed identifier must never be skipped silently. The net lives
# here rather than in srs_parse because how a format numbers its
# entries is the format's own business, and the register beside specs/
# numbers its entries in two parts (ADR-0019).
RE_HEADING = re.compile(
    r"^###\s+([A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*-\d+"
    r"(?:-[A-Za-z0-9]+)*)\s*(?:[—–-]\s*)?(.*)$")
# annotation removed on install
RE_ID = re.compile(r"^(%s)-(%s)-(%s)$" % ("|".join(TYPES), "|".join(AREAS), srs_parse.NUMBER))


# The statement lexicon comes from the config; the patterns are
# language-neutral. Exactly one bolded modal verb per statement; the
# negation word may precede or follow the verb inside the bold markers
# ("**shall not**", "**не должна**"). The bold markers themselves are
# the word boundary, so no \b is needed.
def _modal_pattern(verbs, negations):
    verb_alt = _alternation(verbs)
    if not negations:
        return r"\*\*(?:%s)\*\*" % verb_alt
    neg_alt = _alternation(negations)
    return (r"\*\*(?:(?:%s)\s+)?(?:%s)(?:\s+(?:%s))?\*\*"
            % (neg_alt, verb_alt, neg_alt))


RE_MODAL = re.compile(
    _modal_pattern(CFG["modal_verbs"], CFG["negation_words"]),
    re.IGNORECASE)
RE_RATIONALE = re.compile(
    r"^\s*\*\*(?:%s)\.?\*\*" % _alternation(CFG["rationale_markers"]))

# Optional traceability annotations in source and test files. The two
# examples end in "srs-ignore" because this file is copied into every
# target, where they would otherwise be read as real annotations naming
# requirements that project never had.
#   implements: FR-CORE-010          -> the `code` field    srs-ignore
#   verifies: FR-CORE-010, FR-UI-020 -> the `tests` field   srs-ignore
# A line containing "srs-ignore" is exempt from annotation checking.
_ANNOT_ID = r"[A-Z]+-[A-Z0-9]+-%s(?!\d)" % srs_parse.NUMBER
RE_ANNOTATION = re.compile(
    r"\b(implements|verifies):\s*(%s(?:\s*,\s*%s)*)" % (_ANNOT_ID, _ANNOT_ID))


class Requirement(object):
    def __init__(self, rid, title, path, line):
        self.id = rid
        self.title = title
        self.path = path          # path relative to the repository root
        self.line = line          # 1-based line number of the heading
        self.meta = {}
        self.statement = ""
        # Captured for readers (tools/srs_view.py); the checker itself
        # judges the statement only.
        self.rationale = ""

    def links(self, field):
        return self.meta.get(field, [])

    @property
    def where(self):
        return "%s:%d" % (self.path, self.line)


def _split_body(lines):
    """Statement and rationale, split at the first rationale marker.

    The split is the caller's and not the parser's: the marker comes
    from the project lexicon, so where a body divides is a question
    about language and not about shape. Fenced blocks are passed over
    while looking for the marker, and dropped from the statement —
    modal verbs are counted in prose only. The rationale keeps its
    blocks whole, because readers render them.
    """
    statement = []
    index = 0
    total = len(lines)
    while index < total:
        if srs_parse.RE_FENCE.match(lines[index]):
            index = srs_parse.skip_fence(lines, index)
            continue
        if RE_RATIONALE.match(lines[index]):
            break
        statement.append(lines[index])
        index += 1
    rationale = lines[index:] if index < total else []
    return "\n".join(statement).strip(), "\n".join(rationale).strip()


def parse_text(text, rel, errors):
    # annotation removed on install
    """Parses one specification file already held in memory.

    Split out of parse_file so a caller that has the text but not the
    file — tools/srs_view.py reading a past revision through `git
    show` — goes through the same parser. The parser is
    language-neutral: the lexicon is consulted by validate(), never
    here, and the one lexical question this function does ask — where
    the rationale begins — it asks of a body srs_parse already found.
    """
    requirements = []
    for entry in srs_parse.parse_entries(text, rel, errors, RE_HEADING):
        req = Requirement(entry.id, entry.title, entry.path, entry.line)
        req.meta = entry.fields
        req.statement, req.rationale = _split_body(entry.body)
        requirements.append(req)
    return requirements


def parse_file(path, rel, errors):
    with open(path, "r", encoding="utf-8") as handle:
        return parse_text(handle.read(), rel, errors)


def collect_spec_files():
    # annotation removed on install
    # Every markdown file under specs/ at any depth, except the decision
    # log, the archive and the reserved names — reserved at any depth, so
    # that a README.md inside an area's directory is for people. An area
    # written as one file and one written as a directory of files are the
    # same specification to this walk (ADR-0028).
    result = []
    for current, dirs, files in os.walk(SPECS):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(files):
            if not name.endswith(".md") or name in SKIP_FILES:
                continue
            full = os.path.join(current, name)
            result.append((full, os.path.relpath(full, ROOT)))
    return sorted(result, key=lambda pair: pair[1])


CYCLE_FIELDS = ("derives_from", "refines")

# annotation removed on install
# Walked on its own, not added to the pair above. Those two answer one
# question — why does this exist — which is why they share a graph. This
# one answers another, what is this meaningless without, and a path
# alternating between the two is a circle in neither sense.
DEPENDENCY_FIELDS = ("depends_on",)


def find_cycles(requirements, fields):
    # annotation removed on install
    """Loops in one link graph, as (cycle path, fields on it).

    The fields to walk are given, because the specification holds two
    graphs and not one: the derivation fields, which the caller passes
    together for the reason below, and the dependency field, which is
    walked by itself.

    One graph over both kinds of derivation link rather than one per kind.
    A cycle that alternates them — A derives from B, B refines A — is
    circular in exactly the way the rationale describes, and two separate
    walks see neither half of it.

    The fields are carried along so the message can still name them: a
    cycle drawn in one kind reads exactly as it did when there was a walk
    per kind.
    """
    graph = dict((r.id, [(t, field) for field in fields
                         for t in r.links(field)])
                 for r in requirements)
    cycles = []
    state = {}   # 0 untouched, 1 in progress, 2 done
    stack = []
    # The field each step of `stack` was entered by: via[i] joins stack[i]
    # to stack[i + 1], so a cycle opening at `start` was drawn with
    # via[start:] and the back-edge that closed it.
    via = []

    def walk(node):
        state[node] = 1
        stack.append(node)
        for nxt, field in graph.get(node, []):
            if nxt not in graph:
                continue
            if state.get(nxt, 0) == 0:
                via.append(field)
                walk(nxt)
                via.pop()
            elif state.get(nxt) == 1:
                start = stack.index(nxt)
                cycles.append((stack[start:] + [nxt],
                               sorted(set(via[start:] + [field]))))
        stack.pop()
        state[node] = 2

    for rid in graph:
        if state.get(rid, 0) == 0:
            walk(rid)
    return cycles


def normalize_meta(req, errors):
    """List fields must be bracketed lists; scalar fields single values.
    Coerces wrong shapes so later checks do not iterate a string
    character by character or crash on a list."""
    for field in LIST_FIELDS:
        value = req.meta.get(field)
        if value is not None and not isinstance(value, list):
            if field in ("code", "tests"):
                example = "[src/app.py]"
            elif field == "exempt":
                example = "[%s]" % RULES[0]
            else:
                example = "[FR-CORE-010]"
            errors.append("%s — %s must be a bracketed list, e.g. %s"
                          % (req.where, field, example))
            req.meta[field] = []
    for field in SCALAR_FIELDS:
        value = req.meta.get(field)
        if isinstance(value, list):
            errors.append("%s — %s must be a single value, not a list"
                          % (req.where, field))
            req.meta[field] = value[0] if value else ""


RE_RANGE_NAME = re.compile(r"^(\d{3,})-(\d{3,})\.md$")


def file_range_of(rel):
    """(low, high, kind) of the numbers a requirements file's name holds:
    a file directly under specs/ holds 000-999 ("plain"), a file named
    `NNN-NNN.md` in a subdirectory holds that range ("named"), and any
    other file in a subdirectory holds anything (None, None, None)."""
    parts = rel.replace(os.sep, "/").split("/")
    if len(parts) == 2:
        return 0, 999, "plain"
    match = RE_RANGE_NAME.match(parts[-1])
    if match:
        return int(match.group(1)), int(match.group(2)), "named"
    return None, None, None


def validate(requirements):
    errors = []
    warnings = []
    reports = []

    by_id = {}
    for req in requirements:
        normalize_meta(req, errors)

        # annotation removed on install
        if req.id in by_id:
            errors.append("%s — identifier %s is already used at %s"
                          % (req.where, req.id, by_id[req.id].where))
        else:
            by_id[req.id] = req

        if not RE_ID.match(req.id):
            errors.append("%s — identifier does not match <TYPE>-<AREA>-<NNN>"
                          % req.where)
        if not req.title:
            errors.append("%s — requirement has no title" % req.where)

        for key in req.meta:
            # annotation removed on install
            if key in RETIRED_FIELDS:
                replacement, version = RETIRED_FIELDS[key]
                errors.append(
                    "%s — key %r was %s in %s"
                    % (req.where, key,
                       "renamed to %r" % replacement if replacement
                       else "withdrawn", version))
            # annotation removed on install
            # A key the format declares neither required nor optional is
            # tolerated, which is what lets a later version add one.
            elif key not in KNOWN_FIELDS:
                rule_finding(warnings, reports, "unknown-key",
                             "%s — unknown field %r" % (req.where, key), req)

        for name in req.meta.get("exempt") or []:
            if name not in RULES:
                errors.append("%s — exempt names an unknown rule %r; the "
                              "rules are %s"
                              % (req.where, name, ", ".join(RULES)))

        # A key that is absent is named as absent. Reporting it through the
        # value check instead — "status '' is not one of" — describes the
        # symptom and hides the cause.
        # annotation removed on install
        missing = set(key for key in REQUIRED_FIELDS if key not in req.meta)
        for key in sorted(missing):
            errors.append("%s — required key %r is missing" % (req.where, key))

        status = req.meta.get("status", "")
        if "status" not in missing and status not in STATUSES:
            errors.append("%s — status %r is not one of %s"
                          % (req.where, status, "/".join(STATUSES)))

        verification = req.meta.get("verification", "")
        if "verification" not in missing and verification not in VERIFICATIONS:
            errors.append("%s — verification method %r is not one of %s"
                          % (req.where, verification, "/".join(VERIFICATIONS)))

        # Statement and its binding force.
        if not req.statement:
            errors.append("%s — no statement" % req.where)
        else:
            # annotation removed on install
            # The mechanical half of the rule against a compound
            # statement: two verbs are two requirements, and a script can
            # say so. One verb carrying a list of objects is as compound
            # and is out of reach here, which is why the invariant is
            # inspected rather than tested and does not name this file.
            found = len(RE_MODAL.findall(req.statement))
            if found == 0:
                errors.append("%s — no bolded modal verb from the lexicon (%s)"
                              % (req.where, " / ".join(CFG["modal_verbs"])))
            elif found > 1:
                errors.append("%s — %d modal verbs, expected one: "
                              "this is two requirements, split them"
                              % (req.where, found))

        # Both statuses the standard defines as being realized oblige the
        # code field: they differ by how much is built, not by whether
        # anything is — `deferred` is the state for approved and not begun.
        # annotation removed on install
        code = req.meta.get("code", [])
        if status in ("implemented", "partial") and not code:
            errors.append("%s — status %s but the code field is empty"
                          % (req.where, status))

        # Implementation ahead of approval.
        # annotation removed on install
        if status == "draft" and code:
            rule_finding(warnings, reports, "draft-with-code",
                         "%s — %s is draft but the code field is not "
                         "empty: implementation ahead of approval"
                         % (req.where, req.id), req)

        # annotation removed on install
        for field in ("code", "tests"):
            for rel in req.meta.get(field, []):
                if not os.path.exists(os.path.join(ROOT, rel)):
                    errors.append("%s — %s points to a nonexistent path %s"
                                  % (req.where, field, rel))

        # Replacement for superseded requirements.
        # annotation removed on install
        replacement = req.meta.get("superseded_by", "")
        if status == "superseded" and not replacement:
            errors.append("%s — status superseded without superseded_by"
                          % req.where)
        if replacement and status != "superseded":
            errors.append("%s — superseded_by present but status is %r"
                          % (req.where, status))

    # annotation removed on install
    # Dangling links; approved-or-better requirements resting on drafts.
    for req in requirements:
        status = req.meta.get("status", "")
        for field in LINK_FIELDS:
            for target in req.links(field):
                if target not in by_id:
                    errors.append("%s — link to nonexistent requirement %s"
                                  % (req.where, target))
                elif target == req.id:
                    errors.append("%s — requirement links to itself" % req.where)
                elif (status in ("implemented", "partial")
                        and field in ("derives_from", "depends_on", "refines")
                        and by_id[target].meta.get("status") == "draft"):
                    rule_finding(warnings, reports, "rests-on-draft",
                                 "%s — %s is %s and rests on draft %s "
                                 "(%s): approve or revisit it"
                                 % (req.where, req.id, status, target,
                                    field), req)
                elif (status not in CANCELLED
                        and field in ("derives_from", "depends_on", "refines")
                        and by_id[target].meta.get("status") == "withdrawn"):
                    rule_finding(warnings, reports, "rests-on-withdrawn",
                                 "%s — %s is %s and rests on withdrawn %s "
                                 "(%s): re-point it, promote it, or withdraw "
                                 "it too" % (req.where, req.id, status,
                                             target, field), req)
                # Every live status, not just the built ones: a deferred
                # requirement whose ground was withdrawn is approved work
                # with nothing under it, and whoever builds it will not read
                # the parent. `conflicts_with` is out — a divergence from a
                # withdrawn requirement has lost nothing it stood on.
        # Only where the method is `T`: a requirement verified by
        # inspection or analysis has no test by design, and reporting those
        # would bury the ones that mean something. Read from this
        # requirement — this loop rebinds `req` and `status`, and reusing
        # the first loop's `verification` would judge all of them by the
        # last one's method.
        # annotation removed on install
        if status in ("implemented", "partial") \
                and req.meta.get("verification") == "T" \
                and not req.meta.get("tests"):
            rule_finding(warnings, reports, "test-missing",
                         "%s — %s says verification T and lists no test"
                         % (req.where, req.id), req)

        replacement = req.meta.get("superseded_by", "")
        if replacement:
            if replacement not in by_id:
                errors.append("%s — link to nonexistent requirement %s"
                              % (req.where, replacement))
            elif replacement == req.id:
                errors.append("%s — requirement links to itself" % req.where)

    # Total isolation is the one case where a missing link shows: the
    # checker can prove that what is written resolves, never that something
    # was left out.
    # annotation removed on install
    touched = set()
    for req in requirements:
        for field in LINK_FIELDS:
            for target in req.meta.get(field, []):
                touched.add(req.id)
                touched.add(target)
        replacement = req.meta.get("superseded_by", "")
        if replacement:
            touched.add(req.id)
            touched.add(replacement)
    for req in requirements:
        if req.meta.get("status") in CANCELLED:
            continue
        if req.id not in touched:
            rule_finding(warnings, reports, "unlinked",
                         "%s — %s is linked to nothing, and nothing links "
                         "to it" % (req.where, req.id), req)

    for cycle, fields in find_cycles(requirements, CYCLE_FIELDS):
        errors.append("cycle in %s links: %s"
                      % ("/".join(fields), " → ".join(cycle)))

    # annotation removed on install
    # A file's name may state the thousand it holds — `1000-1999.md` under
    # an area's directory — and a file directly under specs/ holds the
    # first thousand by the standard's convention, so a number filed in
    # the wrong file is a name that lies to whoever opens the file by eye.
    # A warning with the move in it: the plain file's first number past
    # 999 is the moment the area becomes a directory (ADR-0028).
    for req in requirements:
        low, high, kind = file_range_of(req.path)
        if low is None:
            continue
        number = srs_parse.id_key(req.id)[1]
        if low <= number <= high:
            continue
        thousand = number // 1000 * 1000
        wanted = "%04d-%04d.md" % (thousand, thousand + 999) if thousand else "000-999.md"
        if kind == "plain":
            area_dir = req.path[:-3]
            rule_finding(warnings, reports, "file-range",
                         "%s — %s is past the thousand this file holds; move the file whole "
                         "to %s/000-999.md and open %s there"
                         % (req.where, req.id, area_dir, wanted), req)
        else:
            rule_finding(warnings, reports, "file-range",
                         "%s — %s is outside the range this file's name states (%s); it belongs "
                         "in %s beside it"
                         % (req.where, req.id, os.path.basename(req.path)[:-3], wanted), req)

    # annotation removed on install
    # A separate walk, so a path that alternates between the two graphs is
    # reported by neither. The message names the field it was drawn in, so
    # the two read apart without any wording of their own.
    for cycle, fields in find_cycles(requirements, DEPENDENCY_FIELDS):
        errors.append("cycle in %s links: %s"
                      % ("/".join(fields), " → ".join(cycle)))

    return by_id, errors, warnings, reports


def iter_source_files():
    """Yields repo-relative paths of source files under code and test roots,
    deduplicated when roots nest."""
    seen = set()
    extensions = tuple(CODE_EXTENSIONS)
    for root in list(CODE_ROOTS) + list(TEST_ROOTS):
        base = os.path.join(ROOT, root)
        if not os.path.isdir(base):
            continue
        for current, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for name in sorted(files):
                if not name.endswith(extensions):
                    continue
                # Spec fields use forward slashes; normalize for comparison.
                rel = os.path.relpath(os.path.join(current, name),
                                      ROOT).replace(os.sep, "/")
                if rel in seen:
                    continue
                seen.add(rel)
                yield rel


def read_annotations(path):
    # annotation removed on install
    """Every annotation one file carries, as (line number, keyword, id).

    The whole of the annotation grammar lives here — which lines are
    exempt, what an annotation looks like, how several identifiers share
    one. Both readers of it are downstream: this module's rules, and the
    viewer answering which requirements describe a path. Written twice it
    would one day be two grammars, and the copy a reader happened to reach
    would win.

    Triples rather than a set of identifiers, because a finding has to say
    where: the rules below quote `path:line`, and an identifier alone
    cannot be pointed at.
    """
    result = []
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for lineno, line in enumerate(handle, 1):
            # A line that says so is exempt, which is what lets a file
            # document the grammar without claiming a requirement.
            if "srs-ignore" in line:
                continue
            for match in RE_ANNOTATION.finditer(line):
                for rid in match.group(2).split(","):
                    result.append((lineno, match.group(1), rid.strip()))
    return result


def scan_annotations(by_id, errors, warnings, reports):
    """Cross-checks implements:/verifies: annotations against the spec.

    The code/tests fields remain the source of truth and the annotation is
    the mirror (ADR-0014); a mismatch is reported against the mirror.
    Returns what each scanned file claims, as {field: {path: {id, …}}},
    which is what the two pairing rules are computed from. An annotation
    naming a cancelled requirement is dead and claims nothing, so it never
    reaches `claims`. "annotated" holds every file that carried an
    annotation at all, resolving or not: that is how the unclaimed rule
    knows the file has already been spoken about, and by a report that
    names the line and the requirement rather than only the file.
    """
    claims = {"code": {}, "tests": {}, "annotated": set()}
    field_by_keyword = {"implements": "code", "verifies": "tests"}
    for rel in iter_source_files():
        claims["code"].setdefault(rel, set())
        claims["tests"].setdefault(rel, set())
        for lineno, keyword, rid in read_annotations(os.path.join(ROOT, rel)):
            where = "%s:%d" % (rel, lineno)
            claims["annotated"].add(rel)
            req = by_id.get(rid)
            if req is None:
                parts = rid.split("-")
                known_shape = (len(parts) == 3
                               and parts[0] in TYPES
                               and parts[1] in AREAS)
                if known_shape:
                    errors.append("%s — annotation references unknown "
                                  "requirement %s" % (where, rid))
                else:
                    rule_finding(
                        warnings, reports, "annotation-unknown-area",
                        "%s — annotation references %s with an unknown type "
                        "or area (an example? add srs-ignore to the line if "
                        "intended)" % (where, rid))
                continue
            if req.meta.get("status") in CANCELLED:
                rule_finding(
                    warnings, reports, "annotation-superseded",
                    "%s — annotation points at %s requirement %s"
                    % (where, req.meta["status"], rid), req)
                continue
            field = field_by_keyword[keyword]
            claims[field][rel].add(rid)
            if rel not in req.meta.get(field, []):
                rule_finding(
                    warnings, reports, "annotation-unlisted",
                    "%s — file carries `%s: %s` but is not listed in that "
                    "requirement's %s field" % (where, keyword, rid, field),
                    req)
    return claims


def check_pairing(requirements, claims, warnings, reports):
    # annotation removed on install
    """Every file a requirement names says so.

    The forward half of the link has always been checked; this is the half
    that decays, because only somebody at the file notices when it stops
    deserving the entry still pointing at it (ADR-0014). Silent for a file
    the checker does not read: a `code` field names the standard, the
    skills and the CI templates too, and none of those is annotated.
    """
    for req in requirements:
        if req.meta.get("status") not in ("implemented", "partial"):
            continue
        for keyword, field in (("implements", "code"), ("verifies", "tests")):
            for rel in req.meta.get(field, []):
                if rel not in claims[field]:
                    continue
                if req.id in claims[field][rel]:
                    continue
                rule_finding(
                    warnings, reports, "annotation-unpaired",
                    "%s — %s names %s in %s and the file does not carry "
                    "`%s: %s`" % (req.where, req.id, rel, field, keyword,
                                  req.id), req)


def check_unclaimed(requirements, claims, warnings, reports):
    # annotation removed on install
    """A file neither live end claims: no requirement still standing names
    it and it names none itself. Either behaviour with no requirement
    behind it, or a helper that will never have one — and the project says
    which by tuning the rule.

    A cancelled requirement counts for neither side. Its `code` field is
    the record of what it once pointed at and not a claim on the file now,
    and an annotation naming it is reported as dead by scan_annotations,
    which is why that side never reaches `claims` at all. Left in, a
    withdrawal would quietly take its files out of sight along with itself.
    """
    named = set()
    for req in requirements:
        if req.meta.get("status") in CANCELLED:
            continue
        for field in ("code", "tests"):
            named.update(req.meta.get(field, []))
    for rel in sorted(claims["code"]):
        if rel in named:
            continue
        if rel in claims["annotated"]:
            # The file said something about itself. If what it said does
            # not resolve — an unknown requirement, a cancelled one —
            # the annotation check has already reported it with the line
            # and the identifier. Adding "and it claims none" would
            # contradict that report on the same file in the same run.
            continue
        rule_finding(warnings, reports, "annotation-absent",
                     "%s — no requirement names this file and it claims "
                     "none" % rel)


def check_baselines(warnings, reports):
    # annotation removed on install
    """A `spec/v*` tag the baseline log has no row for.

    The row is what makes a baseline; a tag is a bookmark on it. One
    without the other is a claim to freeze something no reader can look
    up. Silent where the tags are absent — a project that never tags is
    keeping a perfectly good log — and not silent where git could not be
    asked at all, which is a different thing: the first answers the
    question, the second leaves it unasked.
    """
    rel = os.path.join("specs", "92-baselines.md")
    try:
        with open(os.path.join(ROOT, rel), "r", encoding="utf-8") as handle:
            logged = set(re.findall(r"`(spec/v[^`]+)`", handle.read()))
    except OSError:
        # annotation removed on install
        # A log that is not there has a row for nothing, which is the
        # condition this rule reports satisfied for every tag at once.
        # Returning here answered the most complete form of the defect with
        # silence — and the rule's whole subject is a tag freezing a state
        # the log does not describe.
        logged = set()
    # annotation removed on install
    # An empty list and an unanswerable question are told apart by how git
    # exits: no tags is a successful run returning nothing, no repository
    # is a failure. Reporting the second keeps a green run from meaning
    # "checked" when the rule never ran.
    try:
        listed = subprocess.check_output(
            ["git", "-C", ROOT, "tag", "-l", "spec/v*"],
            stderr=subprocess.DEVNULL).decode("utf-8", "replace").split()
    except (OSError, subprocess.CalledProcessError):
        # Inside 120 columns with the "note: " prefix: the installer runs
        # this checker and a suite holds its whole output to that width.
        reports.append(
            "%s — no readable history, so baseline tags went uncompared"
            % rel)
        return
    for tag in sorted(tag for tag in listed if tag not in logged):
        rule_finding(warnings, reports, "baseline-without-row",
                     "%s — no row for baseline tag %s; the tag freezes a "
                     "state the log does not describe" % (rel, tag))


def collect_code_files():
    result = set()
    extensions = tuple(CODE_EXTENSIONS)
    for root in CODE_ROOTS:
        base = os.path.join(ROOT, root)
        if not os.path.isdir(base):
            continue
        for current, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for name in files:
                if name.endswith(extensions):
                    full = os.path.join(current, name)
                    result.add(os.path.relpath(full, ROOT)
                               .replace(os.sep, "/"))
    return result


def _cell(text):
    """Escapes pipes so a title cannot break the markdown table."""
    return text.replace("|", "\\|")


def build_traceability(requirements):
    # annotation removed on install
    # The matrix is compared byte-for-byte by the CI freshness gate.
    # Everything here must stay deterministic: files and IDs are sorted,
    # link fields iterate in the fixed LINK_FIELDS order.
    by_id = dict((r.id, r) for r in requirements)

    # annotation removed on install
    # The reverse of every link is computed here and stored nowhere:
    # a specification records one direction, and this is the other.
    incoming = {}
    for req in requirements:
        for field in LINK_FIELDS:
            for target in req.links(field):
                if target in by_id:
                    incoming.setdefault(target, []).append((field, req.id))

    lines = []
    lines.append("# Traceability matrix")
    lines.append("")
    lines.append("**Generated by `tools/srs_check.py`. Do not edit by hand —")
    lines.append("the next run will overwrite it.**")
    lines.append("")
    lines.append("Total requirements: %d." % len(requirements))
    lines.append("")

    by_status = {}
    for req in requirements:
        by_status.setdefault(req.meta.get("status", "?"), []).append(req)
    lines.append("| Status | Requirements |")
    lines.append("|---|---|")
    for status in STATUSES:
        lines.append("| `%s` | %d |" % (status, len(by_status.get(status, []))))
    lines.append("")

    lines.append("## Requirement → code → verification")
    lines.append("")
    lines.append("| Requirement | Status | Method | Code | Tests |")
    lines.append("|---|---|---|---|---|")
    # annotation removed on install
    for req in sorted(requirements, key=lambda r: srs_parse.id_key(r.id)):
        code = "<br>".join("`%s`" % p for p in req.meta.get("code", [])) or "—"
        tests = "<br>".join("`%s`" % p for p in req.meta.get("tests", [])) or "—"
        lines.append("| **%s** %s | `%s` | %s | %s | %s |"
                     % (req.id, _cell(req.title), req.meta.get("status", "?"),
                        req.meta.get("verification", "?"), _cell(code),
                        _cell(tests)))
    lines.append("")

    lines.append("## Incoming links")
    lines.append("")
    lines.append("Who links to each requirement. Computed; not stored in the "
                 "requirements themselves.")
    lines.append("")
    referenced = sorted(incoming.keys(), key=srs_parse.id_key)
    if referenced:
        lines.append("| Requirement | Referenced by |")
        lines.append("|---|---|")
        for rid in referenced:
            refs = ", ".join("%s (%s)" % (src, field)
                             for field, src in sorted(incoming[rid], key=lambda p: srs_parse.id_key(p[1])))
            lines.append("| **%s** | %s |" % (rid, refs))
    else:
        lines.append("No links yet.")
    lines.append("")

    lines.append("## Requirements without listed tests")
    lines.append("")
    untested = [r for r in sorted(requirements, key=lambda r: srs_parse.id_key(r.id))
                if not r.meta.get("tests") and r.meta.get("status") in ("implemented", "partial")]
    if untested:
        lines.append("Verified by means other than testing — or the check has "
                     "not been set up yet.")
        lines.append("")
        for req in untested:
            lines.append("- **%s** (`%s`, method `%s`) — %s"
                         % (req.id, req.meta.get("status", "?"),
                            req.meta.get("verification", "?"), req.title))
    else:
        lines.append("None.")
    lines.append("")

    lines.append("## Code files outside the specification")
    lines.append("")
    # annotation removed on install
    # A cancelled requirement's `code` field records what it once pointed at,
    # not a claim on the file now. Counted in, a withdrawal would be the
    # quietest way to take a file out of this list — the same reading the
    # unclaimed-file rule takes above and the viewer's gap list takes in
    # tools/srs_view.py, so that all three answer one question the same way.
    covered = set()
    for req in requirements:
        if req.meta.get("status") in CANCELLED:
            continue
        for path in req.meta.get("code", []):
            covered.add(path)
    all_code = collect_code_files()
    orphans = sorted(all_code - covered)
    lines.append("No requirement references them: %d of %d."
                 % (len(orphans), len(all_code)))
    lines.append("")
    for path in orphans:
        lines.append("- `%s`" % path)
    lines.append("")

    return "\n".join(lines) + "\n"


def main():
    # annotation removed on install
    args = sys.argv[1:]
    unknown = [a for a in args if a not in ("--no-write", "--strict")]
    if unknown:
        sys.stderr.write("unknown flag(s): %s\nusage: srs_check.py "
                         "[--no-write] [--strict]\n" % ", ".join(unknown))
        return 2
    write = "--no-write" not in args
    strict = "--strict" in args

    if not os.path.isdir(SPECS):
        sys.stderr.write("specs/ directory not found: %s\n" % SPECS)
        return 2

    parse_errors = []
    requirements = []
    files = collect_spec_files()
    for full, rel in files:
        # A specification file saved in some other encoding is a defect
        # to report, not a stack trace to decipher.
        try:
            requirements.extend(parse_file(full, rel, parse_errors))
        except (OSError, UnicodeDecodeError) as exc:
            parse_errors.append("%s — cannot read the file: %s" % (rel, exc))

    by_id, errors, warnings, reports = validate(requirements)
    claims = scan_annotations(by_id, errors, warnings, reports)
    check_pairing(requirements, claims, warnings, reports)
    check_unclaimed(requirements, claims, warnings, reports)
    check_baselines(warnings, reports)
    errors = parse_errors + errors

    for text in warnings:
        sys.stdout.write("warning: %s\n" % text)
    # Lowered rules are still said out loud; what they no longer do is fail
    # a --strict run, which is the whole difference the project asked for.
    for text in reports:
        sys.stdout.write("note: %s\n" % text)

    if errors:
        sys.stdout.write("\n")
        for text in errors:
            sys.stdout.write("error: %s\n" % text)
        sys.stdout.write("\nFiles scanned: %d. Requirements: %d. Errors: %d. "
                         "(srs_check %s)\n"
                         % (len(files), len(requirements), len(errors),
                            __version__))
        return 1

    if strict and warnings:
        sys.stdout.write("\nstrict mode: %d warning(s) treated as errors. "
                         "(srs_check %s)\n" % (len(warnings), __version__))
        return 1

    sys.stdout.write("Files scanned: %d. Requirements: %d. No errors. "
                     "(srs_check %s)\n"
                     % (len(files), len(requirements), __version__))

    if write:
        with open(TRACE, "w", encoding="utf-8") as handle:
            handle.write(build_traceability(requirements))
        sys.stdout.write("Traceability matrix rewritten: %s\n"
                         % os.path.relpath(TRACE, ROOT))

    return 0


if __name__ == "__main__":
    sys.exit(main())
