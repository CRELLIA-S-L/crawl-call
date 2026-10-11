#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.24.0 — the framework release this file came from
# annotation removed on install
# Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License
# annotation removed on install
"""Specification integrity checker and traceability matrix generator.

    python3 srs-dd/tools/srs_check.py             check and rewrite 90-traceability.md
    python3 srs-dd/tools/srs_check.py --no-write  check only
    python3 srs-dd/tools/srs_check.py --strict    treat warnings as errors (CI)

The rules are srs-dd/standard.md's; this script only enforces them, and knows no
natural language — verbs, negations and markers come from specs/srs-config.json.
Standard library only, compatible with Python 3.9.
"""

# file annotation removed on install

import json
import os
import re
import subprocess
import sys

# The shape is read by srs_parse beside this file; the judgement stays here
#. No bytecode: this runs in other people's repositories.
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import srs_parse                                        # noqa: E402
except ImportError:
    # Exit 2, not a traceback: it has read nobody's specification. Reachable, since
    # the tooling can be copied by hand (docs/install.md).
    sys.stderr.write(
        "srs-dd/tools/srs_parse.py: missing — the checker reads the record shape "
        "through it, and the two travel together. Copy it beside this file "
        "from the framework clone, or re-run tools/srs_init.py to refresh "
        "the tooling.\n")
    sys.exit(2)

# Re-exported: the number lives in srs_parse, the one file
# every checker — this one, the grounds and the architecture — must have.
__version__ = srs_parse.__version__

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
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

# annotation removed on install
# The grammar every tool reads in an identifier's middle segment, so that
# an area the configuration accepts is one an annotation can name.
RE_AREA_NAME = re.compile(r"^%s$" % srs_parse.AREA)
# annotation removed on install


# Every rule short of an error carries a name the project prices, in `rules` or in
# a requirement's `exempt`. Adding a name is compatible, renaming is not.
# annotation removed on install
RULES = ("unknown-key", "draft-with-code", "rests-on-draft",
         "rests-on-withdrawn", "test-missing", "unlinked",
         "annotation-unknown-area", "annotation-superseded",
         "annotation-unlisted", "annotation-unpaired", "annotation-absent",
         "baseline-without-row", "file-range", "annotation-end-unmatched",
         "annotation-unended", "annotation-empty")
# annotation removed on install

# What a rule costs unpriced: `warn`, except these. A rule added at `warn` fails `--strict`
# in every project on the upgrade that brings it, so one whose harm is in some cases and
# whose cure is a line in every file arrives at `report`.
DEFAULT_SEVERITY = {"annotation-unended": "report"}

# `warn` fails a --strict run, `report` is printed and fails nothing, `off`
# is not printed at all.
SEVERITIES = ("warn", "report", "off")


def _config_fail(message):
    sys.stderr.write("specs/srs-config.json: %s\n" % message)
    sys.exit(2)


# annotation removed on install
def load_config():
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
            _config_fail("area %r must be uppercase letters and digits, beginning with a "
                         "letter, its words joined by single underscores" % area)
        # annotation removed on install
        # An area grouped into a folder this checker skips would vanish whole.
        if area.lower() in SKIP_DIRS:
            _config_fail("area %r is named like a directory the checker skips under specs/ — "
                         "specs/%s/ — and grouped there it would vanish" % (area, area.lower()))
        # annotation removed on install
    # Validated by name: a silently ignored typo looks like a rule that never fires.
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
# annotation removed on install


CFG = load_config()
AREAS = CFG["areas"]
CODE_ROOTS = CFG["code_roots"]
TEST_ROOTS = CFG["test_roots"]
CODE_EXTENSIONS = CFG["code_extensions"]
RULE_SEVERITY = CFG["rules"]


# annotation removed on install
def rule_finding(warnings, reports, rule, text, req=None):
    """Route one rule's finding by what the project decided it costs: a requirement's
    own `exempt`, the project's `rules`, else a warning."""
    if req is not None and rule in (req.meta.get("exempt") or []):
        return
    severity = RULE_SEVERITY.get(rule, DEFAULT_SEVERITY.get(rule, "warn"))
    if severity == "off":
        return
    (warnings if severity == "warn" else reports).append(text)
# annotation removed on install

TYPES = ("FR", "NFR", "IF", "INV", "CON")

# Lifecycle order; also the row order of the status table in the matrix.
STATUSES = ("draft", "deferred", "partial", "implemented", "superseded",
            "withdrawn")
# annotation removed on install
# The two terminal states: a cancelled requirement is kept, not deleted, so its
# number is never free again, and the rules have nothing to say about it.
CANCELLED = ("superseded", "withdrawn")
# annotation removed on install
VERIFICATIONS = ("T", "D", "I", "A")

LINK_FIELDS = ("derives_from", "refines", "depends_on", "conflicts_with")
LIST_FIELDS = LINK_FIELDS + ("code", "tests", "exempt")
SCALAR_FIELDS = ("status", "verification", "superseded_by", "created")
KNOWN_FIELDS = set(LIST_FIELDS) | set(SCALAR_FIELDS)

# The keys a requirement must carry; one that is neither required nor optional is
# not an error, which is how a later version adds a key.
REQUIRED_FIELDS = ("status", "verification")


# Keys a later format renamed or withdrew, as {old: (replacement or None, version)}.
# Reported, never rewritten.
RETIRED_FIELDS = {}


def _alternation(words):
    return "|".join(re.escape(w) for w in words)


# Capture broadly, judge strictly: RE_HEADING takes anything ID-shaped, junk
# included, and RE_ID refuses it loudly — one is never skipped in silence.
# annotation removed on install
RE_HEADING = re.compile(
    r"^###\s+([A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9_]*-\d+"
    r"(?:-[A-Za-z0-9]+)*)\s*(?:[—–-]\s*)?(.*)$")
# annotation removed on install
# annotation removed on install
RE_ID = re.compile(r"^(%s)-(%s)-(%s)$" % ("|".join(TYPES), "|".join(AREAS), srs_parse.NUMBER))
# annotation removed on install


# Language-neutral: one bolded modal verb per statement, the negation word either
# side of it inside the bold markers, which are the word boundary.
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

# Traceability annotations. The examples end in "srs-ignore": copied into a target,
# they would otherwise read as real annotations.
#   implements: FR-CORE-010          -> the `code` field    srs-ignore
#   verifies: FR-CORE-010, FR-UI-020 -> the `tests` field   srs-ignore
# A line containing "srs-ignore" is exempt from annotation checking.
_ANNOT_ID = r"[A-Z]+-%s-%s(?!\d)" % (srs_parse.AREA, srs_parse.NUMBER)   # annotation removed on install
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
        # Captured for readers (srs-dd/tools/srs_view.py); the checker itself
        # judges the statement only.
        self.rationale = ""

    def links(self, field):
        return self.meta.get(field, [])

    @property
    def where(self):
        return "%s:%d" % (self.path, self.line)


def _split_body(lines):
    """Statement and rationale, split at the first lexicon marker — a question about
    language, not shape. Fenced blocks are dropped from the statement and kept whole in
    the rationale."""
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


# annotation removed on install
def parse_text(text, rel, errors):
    """One specification file already held in memory, so a caller with a past revision
    and no file goes through the same parser."""
    requirements = []
    for entry in srs_parse.parse_entries(text, rel, errors, RE_HEADING):
        req = Requirement(entry.id, entry.title, entry.path, entry.line)
        req.meta = entry.fields
        req.statement, req.rationale = _split_body(entry.body)
        requirements.append(req)
    return requirements
# annotation removed on install


def parse_file(path, rel, errors):
    with open(path, "r", encoding="utf-8") as handle:
        return parse_text(handle.read(), rel, errors)


# annotation removed on install
def collect_spec_files():
    # Every markdown file under specs/ at any depth, bar the decisions, the archive and
    # the reserved names; one file or a directory of them read alike.
    result = []
    for current, dirs, files in os.walk(SPECS):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(files):
            if not name.endswith(".md") or name in SKIP_FILES:
                continue
            full = os.path.join(current, name)
            result.append((full, os.path.relpath(full, ROOT)))
    return sorted(result, key=lambda pair: pair[1])
# annotation removed on install


CYCLE_FIELDS = ("derives_from", "refines")

# annotation removed on install
# Walked on its own: the pair above answers why a requirement exists, this answers
# what it is meaningless without, and a path alternating them is no circle.
DEPENDENCY_FIELDS = ("depends_on",)
# annotation removed on install


# annotation removed on install
def find_cycles(requirements, fields):
    """Loops in one link graph, as (cycle path, fields on it).

    One graph over both derivation fields, since a cycle alternating them is a cycle and
    two walks would see neither half; the fields travel so the message names them.
    """
    graph = dict((r.id, [(t, field) for field in fields
                         for t in r.links(field)])
                 for r in requirements)
    cycles = []
    state = {}   # 0 untouched, 1 in progress, 2 done
    stack = []
    # via[i] joins stack[i] to stack[i + 1], so a cycle at `start` was drawn with
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
# annotation removed on install


def normalize_meta(req, errors):
    """List fields must be bracketed, scalars single, coerced so later checks neither
    iterate a string nor crash on a list."""
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
# The map's own names — `10-fr-<area>.md`, `40-invariants.md` — begin with
# two digits and a hyphen, which no range name does.
RE_MAP_NAME = re.compile(r"^\d{2}-.+\.md$")


# annotation removed on install
def file_range_of(rel):
    """(low, high, kind) of the numbers a file's name holds: 000-999 ("plain") for a file
    under specs/ or named as the map names one, the stated range for `NNN-NNN.md` in a
    subdirectory, anything for the rest."""
    parts = rel.replace(os.sep, "/").split("/")
    if len(parts) == 2:
        return 0, 999, "plain"
    match = RE_RANGE_NAME.match(parts[-1])
    if match:
        return int(match.group(1)), int(match.group(2)), "named"
    if RE_MAP_NAME.match(parts[-1]):
        return 0, 999, "plain"
    return None, None, None
# annotation removed on install


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
        # annotation removed on install

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
            # annotation removed on install
            # annotation removed on install

        for name in req.meta.get("exempt") or []:
            if name not in RULES:
                errors.append("%s — exempt names an unknown rule %r; the "
                              "rules are %s"
                              % (req.where, name, ", ".join(RULES)))

        # A key absent is named absent: the value check would describe the symptom.
        # annotation removed on install
        missing = set(key for key in REQUIRED_FIELDS if key not in req.meta)
        for key in sorted(missing):
            errors.append("%s — required key %r is missing" % (req.where, key))
        # annotation removed on install

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
            # The mechanical half of the rule against a compound statement; one verb carrying a
            # list of objects is as compound and out of reach here, so the invariant is inspected.
            found = len(RE_MODAL.findall(req.statement))
            if found == 0:
                errors.append("%s — no bolded modal verb from the lexicon (%s)"
                              % (req.where, " / ".join(CFG["modal_verbs"])))
            elif found > 1:
                errors.append("%s — %d modal verbs, expected one: "
                              "this is two requirements, split them"
                              % (req.where, found))
            # annotation removed on install

        # Both realized statuses oblige the code field: they differ by how much is built.
        # annotation removed on install
        code = req.meta.get("code", [])
        if status in ("implemented", "partial") and not code:
            errors.append("%s — status %s but the code field is empty"
                          % (req.where, status))
        # annotation removed on install

        # Implementation ahead of approval.
        # annotation removed on install
        if status == "draft" and code:
            rule_finding(warnings, reports, "draft-with-code",
                         "%s — %s is draft but the code field is not "
                         "empty: implementation ahead of approval"
                         % (req.where, req.id), req)
        # annotation removed on install

        # annotation removed on install
        for field in ("code", "tests"):
            for rel in req.meta.get(field, []):
                if not os.path.exists(os.path.join(ROOT, rel)):
                    errors.append("%s — %s points to a nonexistent path %s"
                                  % (req.where, field, rel))
        # annotation removed on install

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
                # Every live status: a deferred requirement whose ground was withdrawn is approved
                # work with nothing under it. `conflicts_with` is out — it stood on nothing.
        # Only where the method is `T`, and read from this requirement: the loop rebinds
        # `req`, and the first loop's `verification` would judge all by the last one's.
        # annotation removed on install
        if status in ("implemented", "partial") \
                and req.meta.get("verification") == "T" \
                and not req.meta.get("tests"):
            rule_finding(warnings, reports, "test-missing",
                         "%s — %s says verification T and lists no test"
                         % (req.where, req.id), req)
        # annotation removed on install

        replacement = req.meta.get("superseded_by", "")
        if replacement:
            if replacement not in by_id:
                errors.append("%s — link to nonexistent requirement %s"
                              % (req.where, replacement))
            elif replacement == req.id:
                errors.append("%s — requirement links to itself" % req.where)
    # annotation removed on install

    # Total isolation is the one case a missing link shows: what is written can be proved
    # to resolve, never to be complete.
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
    # annotation removed on install

    for cycle, fields in find_cycles(requirements, CYCLE_FIELDS):
        errors.append("cycle in %s links: %s"
                      % ("/".join(fields), " → ".join(cycle)))

    # annotation removed on install
    # A number filed in the wrong file is a name that lies to whoever opens it by eye; the
    # warning carries the move, since past 999 the area becomes a directory.
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

    # annotation removed on install
    # A separate walk, so a path alternating the two graphs is reported by neither; the
    # message names the field it was drawn in.
    for cycle, fields in find_cycles(requirements, DEPENDENCY_FIELDS):
        errors.append("cycle in %s links: %s"
                      % ("/".join(fields), " → ".join(cycle)))
    # annotation removed on install

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


# annotation removed on install
def read_annotations(path):
    """Every annotation one file carries, as (line number, keyword, id).

    The whole annotation grammar lives here, read by this module's rules and by the
    viewer; written twice it would one day be two grammars. Triples, because a finding
    has to say where.
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
# annotation removed on install


def read_lines(path):
    """A file's lines split on newlines alone, as read_annotations iterates them — not
    str.splitlines(), which also breaks on a form feed."""
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        lines = handle.read().split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return lines


RE_END = re.compile(r"\bsrs-end:\s*(%s(?:\s*,\s*%s)*)" % (_ANNOT_ID, _ANNOT_ID))
RE_FILE_SCOPE = re.compile(r"\bfile\s+(?:implements|verifies):")
RE_CODE_BEFORE = re.compile(r"[A-Za-z0-9]")
# How far a region no end marker ends runs at most: long enough for a long function,
# short enough that one annotation does not print a file whole.
REGION_BOUND = 60


# annotation removed on install
def _scan_marks(lines):
    """One pass over the file: ([mark…], [(line, ids)…], [unmatched…]).

    A mark here carries `kind`, `lines`, `ids` and `end` (None); the region is filled later.
    Consecutive block annotations are one mark.
    """
    marks, ends, unmatched = [], [], []
    for lineno, line in enumerate(lines, 1):
        if "srs-ignore" in line:
            continue
        found = list(RE_ANNOTATION.finditer(line))
        if found and RE_END.search(line):
            # An end marker shares no line with an annotation: the annotation stands and the
            # marker is reported as ending nothing.
            for rid in RE_END.search(line).group(1).split(","):
                unmatched.append((lineno, rid.strip(), "shares its line with an annotation"))
        if found:
            ids = []
            for match in found:
                ids += [rid.strip() for rid in match.group(2).split(",") if rid.strip() not in ids]
            if RE_FILE_SCOPE.search(line):
                kind = "file"
            elif RE_CODE_BEFORE.search(line[:found[0].start()]):
                kind = "line"
            else:
                kind = "block"
            last = marks[-1] if marks else None
            if kind == "block" and last and last["kind"] == "block" and last["lines"][-1] == lineno - 1:
                last["lines"].append(lineno)
                last["ids"] += [rid for rid in ids if rid not in last["ids"]]
            else:
                marks.append({"kind": kind, "lines": [lineno], "ids": ids, "end": None})
            continue
        match = RE_END.search(line)
        if match:
            ends.append((lineno, [rid.strip() for rid in match.group(1).split(",")]))
    return marks, ends, unmatched


def _match_ends(marks, ends, unmatched):
    """Sets `end` on each block its marker closes, top down, so a nested block closes first."""
    open_blocks = []
    events = sorted([(m["lines"][0], 0, m) for m in marks if m["kind"] == "block"]
                    + [(n, 1, ids) for n, ids in ends], key=lambda e: (e[0], e[1]))
    for lineno, is_end, item in events:
        if not is_end:
            open_blocks.append(item)
            continue
        closed = []
        for rid in item:
            # One marker ends a block whole, so a number it spoke for never reaches a block
            # around it naming the same number.
            if any(rid in b["ids"] for b in closed):
                continue
            block = next((b for b in reversed(open_blocks) if rid in b["ids"]), None)
            if block is None:
                unmatched.append((lineno, rid, "no block above it names %s and is still open" % rid))
                continue
            block["end"] = lineno
            open_blocks.remove(block)
            closed.append(block)


def _fill_regions(marks, lines, bound):
    """Fills `first`, `last`, `how`, `stop` and `empty` on every mark."""
    total = len(lines)
    starts = sorted(m["lines"][0] for m in marks if m["kind"] == "block")
    for mark in marks:
        start = mark["lines"][0]
        mark["stop"] = None
        if mark["kind"] == "line":
            mark.update(first=start, last=start, how="line")
        elif mark["kind"] == "file":
            mark.update(first=1, last=min(total, bound), how="file")
        elif mark["end"] is not None:
            mark.update(first=start, last=mark["end"], how="end")
        else:
            following = [n for n in starts if n > mark["lines"][-1]]
            limit = min(total, start + bound - 1)
            if following and following[0] - 1 <= limit:
                last, how, mark["stop"] = following[0] - 1, "next", following[0]
            elif limit < total:
                last, how = limit, "bound"
            else:
                last, how = total, "eof"
            mark.update(first=start, last=last, how=how)
    for mark in marks:
        # A line marked `srs-ignore` is an example, not an annotation: a comment, and so content.
        mark["empty"] = mark["kind"] == "block" and not any(
            "srs-ignore" in lines[n - 1]
            or (lines[n - 1].strip() and not RE_ANNOTATION.search(lines[n - 1])
                and not RE_END.search(lines[n - 1]))
            for n in range(mark["first"], mark["last"] + 1))


def annotation_regions(path, bound=REGION_BOUND):
    """What each annotation in one file marks, and the end markers that end nothing, as
    (marks, unmatched). Nothing is parsed, so the reading holds in any language.

    Each mark is a dict:

        kind    "block", "line" or "file"
        lines   the lines carrying the annotation
        ids     the requirements it names
        first   the first line of the region, 1-based, inclusive
        last    the last line of the region, inclusive
        how     what ended it: "end", "next", "bound", "eof", "line", "file"
        stop    the line of the next block, where `how` is "next"
        empty   the region holds nothing but blank lines, annotations and end markers

    `unmatched` is (line, id, why) per identifier an `srs-end:` names that no open block
    above it does, or that stands on a line with an annotation.
    """
    lines = read_lines(path)
    marks, ends, unmatched = _scan_marks(lines)
    _match_ends(marks, ends, unmatched)
    _fill_regions(marks, lines, bound)
    return marks, unmatched
# annotation removed on install


def scan_annotations(by_id, errors, warnings, reports):
    """Cross-checks implements:/verifies: annotations against the spec, the fields being
    the truth and the annotation the mirror.

    Returns {field: {path: {id, …}}} plus "annotated", every file that carried an
    annotation at all; one naming a cancelled requirement claims nothing.
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
        marks, unmatched = annotation_regions(os.path.join(ROOT, rel))
        for lineno, rid, why in unmatched:
            rule_finding(
                warnings, reports, "annotation-end-unmatched",
                "%s:%d — `srs-end: %s` ends nothing: %s" % (rel, lineno, rid, why))
        for mark in marks:
            # annotation removed on install
            if mark["empty"] and not all(
                    "annotation-empty" in ((by_id[rid].meta.get("exempt") or []) if rid in by_id else [])
                    for rid in mark["ids"]):
                rule_finding(
                    warnings, reports, "annotation-empty",
                    "%s:%d — the block naming %s marks nothing: its region, lines %d–%d, "
                    "holds only blank lines, annotations and end markers"
                    % (rel, mark["lines"][0], ", ".join(mark["ids"]), mark["first"], mark["last"]))
            # annotation removed on install
            if mark["kind"] == "block" and mark["end"] is None:
                rule_finding(
                    warnings, reports, "annotation-unended",
                    "%s:%d — no `srs-end:` ends the block naming %s; a reader is "
                    "shown it down to %s and told it may be incomplete — end it "
                    "with `srs-end: %s` where what it marks ends"
                    % (rel, mark["lines"][0], ", ".join(mark["ids"]),
                       "line %d" % mark["last"], mark["ids"][0]))
    return claims


# annotation removed on install
def check_pairing(requirements, claims, warnings, reports):
    """Every file a requirement names says so — the half that decays, since only somebody
    at the file notices. Silent for a file the checker does not read."""
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
# annotation removed on install


# annotation removed on install
def check_unclaimed(requirements, claims, warnings, reports):
    """A file neither live end claims: behaviour with no requirement behind it, or a helper
    that will never have one, and the project says which by pricing the rule.

    A cancelled requirement counts for neither side, or a withdrawal would take its files
    out of sight with it.
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
            # What the file said about itself did not resolve, and the annotation check has
            # already reported that with the line and the identifier.
            continue
        rule_finding(warnings, reports, "annotation-absent",
                     "%s — no requirement names this file and it claims "
                     "none" % rel)
# annotation removed on install


# annotation removed on install
def check_baselines(warnings, reports):
    """A `spec/v*` tag the baseline log has no row for: a bookmark on nothing a reader can
    look up. Silent where there are no tags, loud where git could not be asked."""
    rel = os.path.join("specs", "92-baselines.md")
    try:
        with open(os.path.join(ROOT, rel), "r", encoding="utf-8") as handle:
            logged = set(re.findall(r"`(spec/v[^`]+)`", handle.read()))
    except OSError:
        # annotation removed on install
        # A log that is not there has a row for nothing — the most complete form of this
        # defect, once answered with silence.
        logged = set()
        # annotation removed on install
    # annotation removed on install
    # No tags is a successful run returning nothing, no repository a failure; reporting
    # the second keeps a green run from meaning "checked".
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
    # annotation removed on install
    for tag in sorted(tag for tag in listed if tag not in logged):
        rule_finding(warnings, reports, "baseline-without-row",
                     "%s — no row for baseline tag %s; the tag freezes a "
                     "state the log does not describe" % (rel, tag))
# annotation removed on install


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


# annotation removed on install
def build_traceability(requirements):
    # The matrix is compared byte-for-byte by the gate, so everything here stays
    # deterministic: sorted files and ids, LINK_FIELDS in its fixed order.
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
    # annotation removed on install

    lines = []
    lines.append("# Traceability matrix")
    lines.append("")
    lines.append("**Generated by `srs-dd/tools/srs_check.py`. Do not edit by hand —")
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
    # annotation removed on install
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
    # A cancelled requirement's `code` records what it pointed at, not a claim now:
    # counted in, a withdrawal would be the quietest way to drop a file from this list.
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
    # annotation removed on install

    return "\n".join(lines) + "\n"
# annotation removed on install


# annotation removed on install
def main():
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
# annotation removed on install


if __name__ == "__main__":
    sys.exit(main())
