#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.20.1 — the framework release this file came from
"""Specification viewer: terminal queries and a self-contained HTML site.

Standard library only, compatible with Python 3.9. Read-only by
construction: it never rewrites specs/90-traceability.md and never acts
as a gate. The matrix stays the committed, byte-compared artifact; this
is a projection of the same data for people to read.

    srs_view.py                    summary: counts, areas, every requirement
    srs_view.py --areas            what the specification is divided into
    srs_view.py FR-CORE-020        one requirement in full
    srs_view.py --list [filters]   filtered list (see --help)
    srs_view.py --grep <text>      requirements and prose holding it
    srs_view.py --code src/a.py    which requirements describe this file
    srs_view.py --tree FR-CORE-010 what derives from it (--up for ancestors)
    srs_view.py --coverage         gaps: no tests, code outside the spec, …
    srs_view.py --diff spec/v0.1.0 working tree against a baseline revision
    srs_view.py --html [PATH]      self-contained page, default .srs-site/
    srs_view.py --json [PATH]      the model as JSON, for your own scripts

The parser lives in srs_check.py — one parser for the whole framework.
A broken specification is still worth reading, so parse errors and
duplicate identifiers are reported as a banner rather than a failure;
judging the specification remains the checker's job.
"""

# annotation removed on install

import sys

# An import writes __pycache__ next to the imported module — inside the
# *target* repository, which has no reason to gitignore it. This line
# must stay above the srs_check import; moving it below is what makes
# the mess reappear.
sys.dont_write_bytecode = True

import argparse                                            # noqa: E402
import datetime                                            # noqa: E402
import difflib                                             # noqa: E402
import hashlib                                             # noqa: E402
import html                                                # noqa: E402
import json                                                # noqa: E402
import os                                                  # noqa: E402
import pathlib                                             # noqa: E402
import re                                                  # noqa: E402
import subprocess                                          # noqa: E402
import webbrowser                                          # noqa: E402

from urllib.parse import quote                              # noqa: E402

import srs_check                                           # noqa: E402
import srs_parse                                           # noqa: E402

if not hasattr(srs_check, "parse_text"):
    sys.stderr.write("tools/srs_check.py predates this viewer — refresh "
                     "the tooling (re-run tools/srs_init.py from a "
                     "framework clone).\n")
    sys.exit(2)

ROOT = srs_check.ROOT
SPECS = srs_check.SPECS
DEFAULT_SITE = os.path.join(ROOT, ".srs-site")

LINK_FIELDS = srs_check.LINK_FIELDS
STATUSES = srs_check.STATUSES

# How an incoming link reads from the target's side.
INCOMING_LABEL = {
    "derives_from": "derived by",
    "refines": "refined by",
    "depends_on": "required by",
    "conflicts_with": "conflicted by",
    "superseded_by": "supersedes",
}

# annotation removed on install
# What a text search skips beyond what the page skips. The standard is the
# framework's own document and the same in every project that took it from
# here; the three that record rather than state answer an ordinary word
# with lines the requirement above them already answered; and the open
# issues hold sentences they have since retracted, which a search would
# return one line at a time.
PROSE_EXCLUDED = ("README.md", "90-traceability.md", "91-open-issues.md",
                  "92-baselines.md")

# annotation removed on install
# What the standard's map names as prose, used only to say which of them a
# project does not have. The search itself takes whatever is there, so a
# project's own prose file is read without being listed here.
PROSE_EXPECTED = ("00-glossary.md", "01-introduction.md", "02-overview.md",
                  "50-verification.md", "constitution.md")

# annotation removed on install
# Past this the answer stops being read. Same reading as the graph limit
# below: what is dropped is stated rather than silently cut.
PROSE_HIT_LIMIT = 40

# Beyond this the layered graph stops being readable; what is dropped is
# always stated on the page rather than silently cut.
GRAPH_NODE_LIMIT = 150


# --------------------------------------------------------------------
# Model
# --------------------------------------------------------------------

def read_repo_url():
    # annotation removed on install
    """The blob-URL prefix used for links to code, e.g.
    https://gitlab.com/acme/app/-/blob/main — copied out of a browser,
    so no per-host URL shapes are guessed here.

    Viewer-only key: srs_check.load_config() iterates its own defaults
    and ignores anything else, so the checker never sees it.
    """
    try:
        with open(srs_check.CONFIG, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return ""
    value = data.get("repo_url", "") if isinstance(data, dict) else ""
    return value.rstrip("/") if isinstance(value, str) else ""


def _as_list(value):
    """Metadata shapes are validated by the checker, not here: a field
    that should be a list but is not simply reads as empty."""
    return [str(item) for item in value] if isinstance(value, list) else []


def _as_scalar(value):
    if isinstance(value, list):
        return str(value[0]) if value else ""
    return str(value) if value else ""


def _requirement_dict(req):
    # annotation removed on install
    parts = req.id.split("-")
    entry = {
        "id": req.id,
        "type": parts[0] if len(parts) > 2 else "",
        "area": parts[1] if len(parts) > 2 else "",
        "title": req.title,
        "path": req.path.replace(os.sep, "/"),
        "line": req.line,
        "status": _as_scalar(req.meta.get("status")),
        "verification": _as_scalar(req.meta.get("verification")),
        "statement": req.statement,
        "rationale": getattr(req, "rationale", ""),
        "superseded_by": _as_scalar(req.meta.get("superseded_by")),
    }
    for field in srs_check.LIST_FIELDS:
        entry[field] = _as_list(req.meta.get(field))
    # Every field of the block, not only the ones this viewer has heard of.
    # The format permits a key it declares neither required nor optional,
    # so blocks legitimately carry keys nothing here knows — and a model
    # that drops them is not "the fields of its block". Known fields keep
    # the normalized form above; the rest pass through as written.
    for key, value in sorted(req.meta.items()):
        if key not in entry:
            entry[key] = value
    return entry


def build_model(requirements, problems, with_code_scan=True):
    """Projects parsed requirements into the one structure the terminal
    renderers, the HTML generator and --json all consume."""
    entries = [_requirement_dict(req) for req in requirements]
    # annotation removed on install
    entries.sort(key=lambda e: (srs_parse.id_key(e["id"]), e["path"], e["line"]))

    seen = {}
    for entry in entries:
        seen[entry["id"]] = seen.get(entry["id"], 0) + 1
    for rid in sorted((k for k, n in seen.items() if n > 1), key=srs_parse.id_key):
        problems.append("duplicate identifier %s — the checker treats "
                        "this as an error" % rid)

    incoming = {}
    for entry in entries:
        for field in LINK_FIELDS:
            for target in entry[field]:
                incoming.setdefault(target, []).append([field, entry["id"]])
        if entry["superseded_by"]:
            incoming.setdefault(entry["superseded_by"], []).append(
                ["superseded_by", entry["id"]])
    for refs in incoming.values():
        refs.sort(key=lambda pair: (pair[1], pair[0]))

    # annotation removed on install
    # A cancelled requirement's `code` field records what it once pointed
    # at, not a claim on the file now — the same reading the checker
    # uses. Counted here, a withdrawal would quietly move its files out
    # of the gap list, and the two tools would describe one file
    # differently in the same run.
    covered = set()
    for entry in entries:
        if entry["status"] in srs_check.CANCELLED:
            continue
        covered.update(entry["code"])
    all_code = srs_check.collect_code_files() if with_code_scan else set()

    return {
        "outlived": outlived(entries, with_code_scan),
        "checker_version": srs_check.__version__,
        "repo_url": read_repo_url(),
        "areas": list(srs_check.AREAS),
        "types": list(srs_check.TYPES),
        "statuses": list(STATUSES),
        "requirements": entries,
        "incoming": incoming,
        "orphan_code": sorted(all_code - covered),
        "code_total": len(all_code),
        "documents": collect_documents(entries),
        "problems": problems,
    }


def outlived(entries, with_code_scan):
    # annotation removed on install
    """What still points at a cancelled requirement.

    Cancelling is the one edit whose consequences outlive it, and they lie
    in three places the checker reports one line at a time. Gathered here so
    the reader deciding a withdrawal sees the whole of it at once.

    The first kind needs no tree at all — it is fields and statuses — so it
    is computed even for a past revision, where `with_code_scan` is off
    because the working tree is not what that revision had.
    """
    dead = dict((e["id"], e) for e in entries
                if e["status"] in srs_check.CANCELLED)
    if not dead:
        # Nothing was cancelled, so nothing can have outlived it — and the
        # walk below would read every source file to prove it. Most
        # specifications are in this state most of the time, and this is on
        # the way to every terminal query.
        return {"links": [], "files": [], "annotations": []}
    live = [e for e in entries if e["status"] not in srs_check.CANCELLED]

    links = []
    for entry in live:
        for field in LINK_FIELDS:
            for target in entry[field]:
                if target in dead:
                    links.append({"id": entry["id"], "title": entry["title"],
                                  "field": field, "target": target})
    links.sort(key=lambda item: (item["id"], item["field"], item["target"]))

    files, annotations = [], []
    if with_code_scan:
        claimed = set()
        for entry in live:
            claimed.update(entry["code"])
            claimed.update(entry["tests"])
        left = set()
        for entry in dead.values():
            left.update(entry["code"])
            left.update(entry["tests"])
        for rel in sorted(left - claimed):
            if os.path.exists(os.path.join(ROOT, rel)):
                files.append(rel)
        for rel in sorted(srs_check.iter_source_files()):
            for _line, _kw, rid in srs_check.read_annotations(
                    os.path.join(ROOT, rel)):
                if rid in dead:
                    annotations.append({"path": rel, "target": rid})

    return {"links": links, "files": files, "annotations": annotations}


def collect_documents(entries):
    """Every file in specs/ that carries no requirements: the standard,
    the glossary, the introduction, the overview, the verification notes,
    the generated reports and the decision log — invisible to the parser,
    wanted by a reviewer, since requirements cite ART-* articles in their
    rationales.

    Derived from what the parse produced rather than listed by hand.
    The list that used to stand here was a copy of the checker's skipped
    set and fell behind it: three files the standard's own map names were
    offered nowhere, and a name added later would have gone the same way.
    The archive is out — not normative by that map, and a link is an
    invitation to read.
    """
    # annotation removed on install
    carrying = set(entry["path"] for entry in entries)
    result = []
    for current, dirs, files in os.walk(SPECS):
        dirs[:] = [name for name in dirs if name != "archive"]
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            rel = os.path.relpath(os.path.join(current, name), ROOT)
            rel = rel.replace(os.sep, "/")
            if rel not in carrying:
                result.append(rel)
    # The decision log after the documents rather than mixed in by name:
    # a run of ADRs between the constitution and the glossary is a sidebar
    # nobody reads to the end.
    result.sort(key=lambda path: ("/adr/" in path, path))
    return result


def collect_prose(entries):
    """What a text search reads, and what the map names and the project
    does not have.

    Filtered from the documents the page offers rather than walked again:
    the two sets differ by four files and nothing else, and a second walk
    is a second thing to keep true.
    The page and the search differ deliberately — a link costs nothing
    when it is the wrong document, and a line out of its document is what
    misleads.
    """
    # annotation removed on install
    # Compared as whole paths, not as names: an index of decisions is
    # commonly `adr/README.md`, and it is not the standard. Dropped by its
    # basename it would be dropped in silence, which is the one thing the
    # neighbouring obligation exists to prevent.
    excluded = set(_repo_relative(os.path.join(SPECS, name))
                   for name in PROSE_EXCLUDED)
    present = [path for path in collect_documents(entries)
               if path not in excluded]
    missing = [name for name in PROSE_EXPECTED
               if not os.path.exists(os.path.join(SPECS, name))]
    return present, missing


def grep_prose(needle, paths):
    """Every line of the prose holding the text, as (path, line, text).

    By the line, because a line of markdown written by hand breaks where
    the meaning breaks — which is what lets a glossary table and a
    page of prose come back in the same shape.
    Tolerant of an odd byte for the reason read_annotations is: one file
    the encoding trips over must not take the whole answer with it.
    """
    # annotation removed on install
    needle = needle.lower()
    hits = []
    for path in paths:
        try:
            handle = open(os.path.join(ROOT, path), "r",
                          encoding="utf-8", errors="replace")
        except IOError:
            continue
        with handle:
            for lineno, line in enumerate(handle, 1):
                if needle in line.lower():
                    hits.append((path, lineno, line.strip()))
    return hits


def load_current():
    problems = []
    requirements = []
    for full, rel in srs_check.collect_spec_files():
        # A file that is not readable UTF-8, or vanished between the
        # listing and the read, is one more problem to report — not a
        # reason to refuse to show the other 400 requirements.
        try:
            requirements.extend(srs_check.parse_file(full, rel, problems))
        except (OSError, UnicodeDecodeError) as exc:
            problems.append("%s — cannot read: %s" % (rel, exc))
    return build_model(requirements, problems)


def by_id(model):
    return dict((entry["id"], entry) for entry in model["requirements"])


RE_ADR_ID = re.compile(r"^ADR-\d{4}$")
RE_ADR_HEADING = re.compile(r"^# (ADR-\d{4}) — (.+?)\s*$")
RE_ADR_STATUS = re.compile(r"^- \*\*Status:\*\* (.+?)\s*$")


def decisions():
    # annotation removed on install
    """Every decision in specs/adr/ as {id: entry}, shaped like a
    requirement entry as far as a citation needs: id, title, path, status.

    Read from the heading and the status line, not the file name: a file is
    renamed, the number in the heading is what a plan cites. A file whose
    heading does not carry the form is not a decision to this reader and is
    left out, which is what an index or a template under adr/ wants.
    """
    found = {}
    root = os.path.join(SPECS, "adr")
    if not os.path.isdir(root):
        return found
    for name in sorted(os.listdir(root)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(root, name)
        try:
            with open(path, encoding="utf-8") as handle:
                lines = handle.read().splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        # A file may open with a front matter — `---`, `key: value` lines,
        # `---` — before its heading: the shape a project writing decisions
        # in its own language chose, and the status is then one of its
        # keys. Skipped to find the heading, read for the status.
        front = {}
        body = lines
        if lines and lines[0].strip() == "---":
            for index, line in enumerate(lines[1:], 1):
                if line.strip() == "---":
                    body = lines[index + 1:]
                    break
                key, _, value = line.partition(":")
                if _ and key.strip():
                    front[key.strip().lower()] = value.strip()
        # The first line that says anything: a file may open with a blank
        # line, and the heading is what makes it a decision, not its row.
        first = next((line for line in body if line.strip()), "")
        heading = RE_ADR_HEADING.match(first)
        if not heading:
            continue
        status = front.get("status", "?")
        for line in body[1:12]:
            matched = RE_ADR_STATUS.match(line)
            if matched:
                status = matched.group(1)
                break
        found[heading.group(1)] = {"id": heading.group(1),
                                   "title": heading.group(2),
                                   "path": _repo_relative(path),
                                   "status": status}
    return found


# --------------------------------------------------------------------
# Selection
# --------------------------------------------------------------------

def _matches_path(candidate, wanted):
    return candidate == wanted or candidate.startswith(wanted + "/")


def requirements_for_path(model, path):
    # annotation removed on install
    """Which requirements describe a file — the `code`/`tests` fields
    plus any implements:/verifies: annotation carried by the file
    itself. A directory prefix matches everything under it."""
    wanted = path.replace(os.sep, "/").strip()
    while wanted.startswith("./"):
        wanted = wanted[2:]
    wanted = wanted.rstrip("/")
    # Spec fields are relative to the repository root; a path typed from
    # somewhere else in the tree is translated rather than missed.
    if not os.path.exists(os.path.join(ROOT, wanted)) and os.path.exists(path):
        wanted = _repo_relative(path) or wanted
    found = set()
    for entry in model["requirements"]:
        for listed in entry["code"] + entry["tests"]:
            if _matches_path(listed, wanted):
                found.add(entry["id"])
    full = os.path.join(ROOT, wanted)
    if os.path.isfile(full):
        # The grammar is the checker's, read through its function rather
        # than reimplemented here: which lines are exempt and what counts
        # as an annotation must be one answer, not two that agree today.
        # Which keyword it was does not matter to this question — a file
        # named by a requirement is a file the requirement describes.
        found.update(rid for _line, _kw, rid
                     in srs_check.read_annotations(full))
    return found


def split_line_spec(spec):
    # annotation removed on install
    """`path:line` into (path, line), or (spec, None) when it is not one.

    A colon is not enough to say so: `C:\\src` and a path with a colon in
    its name both carry one and mean no line. Only a wholly numeric tail
    behind a head that exists as a file is read as a line, so a path that
    happens to end that way and exists as written is kept whole first.
    A directory before the colon is not a file with lines, and is left as
    the whole spec for the caller to say so.
    """
    head, sep, tail = spec.rpartition(":")
    if not sep or not tail.isdigit() or not head:
        return spec, None
    if os.path.exists(spec) or os.path.exists(os.path.join(ROOT, spec)):
        return spec, None
    if os.path.isfile(os.path.join(ROOT, head)) or os.path.isfile(head):
        return head, int(tail)
    return spec, None


def requirements_for_line(path, line):
    # annotation removed on install
    """The requirements the annotation covering a line marks — the one on
    the line itself, or the nearest above it — and nothing from the
    `code`/`tests` fields, which have no lines to be asked about.

    A line before any annotation is covered by none and answers with an
    empty set; the file-wide count the caller prints beside it is then the
    whole of the answer. The grammar is the checker's, as in
    requirements_for_path, and for the same reason.
    """
    wanted = path.replace(os.sep, "/").strip()
    if not os.path.exists(os.path.join(ROOT, wanted)) and os.path.exists(path):
        wanted = _repo_relative(path) or wanted
    full = os.path.join(ROOT, wanted)
    covering = None
    for lineno, _kw, rid in srs_check.read_annotations(full):
        if lineno > line:
            break
        if lineno != covering:
            covering, found = lineno, set()
        found.add(rid)
    return found if covering is not None else set()


def select(model, args):
    # annotation removed on install
    entries = model["requirements"]
    if args.status:
        entries = [e for e in entries if e["status"] == args.status]
    if args.area:
        entries = [e for e in entries if e["area"] == args.area.upper()]
    if args.type:
        entries = [e for e in entries if e["type"] == args.type.upper()]
    if args.verification:
        entries = [e for e in entries
                   if e["verification"] == args.verification.upper()]
    if args.grep:
        needle = args.grep.lower()
        entries = [e for e in entries
                   if needle in e["id"].lower()
                   or needle in e["title"].lower()
                   or needle in e["statement"].lower()
                   or needle in e["rationale"].lower()]
    if args.code:
        wanted = requirements_for_path(model, args.code)
        entries = [e for e in entries if e["id"] in wanted]
    return entries


# --------------------------------------------------------------------
# Terminal output
# --------------------------------------------------------------------

class Style(object):
    """Colour only on a terminal that asked for it."""

    def __init__(self, stream):
        enabled = (hasattr(stream, "isatty") and stream.isatty()
                   and not os.environ.get("NO_COLOR"))
        self.bold = "\033[1m" if enabled else ""
        self.dim = "\033[2m" if enabled else ""
        self.off = "\033[0m" if enabled else ""

    def b(self, text):
        return "%s%s%s" % (self.bold, text, self.off)

    def d(self, text):
        return "%s%s%s" % (self.dim, text, self.off)


def out(text=""):
    sys.stdout.write(text + "\n")


def print_problems(model, style):
    if not model["problems"]:
        return
    out(style.b("%d problem(s) in the specification — run "
                "tools/srs_check.py for the full report:"
                % len(model["problems"])))
    for text in model["problems"][:10]:
        out("  %s" % text)
    if len(model["problems"]) > 10:
        out("  … %d more" % (len(model["problems"]) - 10))
    out()


def print_counts(model, style):
    # annotation removed on install
    counts = {}
    for entry in model["requirements"]:
        counts[entry["status"]] = counts.get(entry["status"], 0) + 1
    parts = ["%s %d" % (status, counts.get(status, 0)) for status in STATUSES]
    unknown = sorted(set(counts) - set(STATUSES))
    parts.extend("%s %d" % (status or "?", counts[status])
                 for status in unknown)
    total = len(model["requirements"])
    out("%s %s   %s" % (style.b(str(total)),
                        "requirement" if total == 1 else "requirements",
                        style.d(" · ".join(parts))))
    print_areas(model, style)


def print_areas(model, style):
    """The partition every identifier carries, with what each holds.

    Printed beside the count, and separately on request: a reader who
    knows to ask for the areas did not need them, and the one this is for
    does not know the partition exists, so the unprompted line is the
    half the requirement binds and the flag is one spelling of asking.
    Declared areas rather than the ones in use, so an area a project drew
    and has not filled reads as empty instead of missing; one carrying
    requirements without being declared is appended rather than dropped,
    because the count is wrong if it is left out and the checker is the
    place that refuses it.
    In the order the project declared them, not alphabetical: the same
    reading STATUSES gets in the count above it.
    """
    # annotation removed on install
    held = {}
    for entry in model["requirements"]:
        held[entry["area"]] = held.get(entry["area"], 0) + 1
    areas = list(model["areas"])
    for area in sorted(set(held) - set(areas)):
        areas.append(area)
    parts = ["%s %d" % (area, held.get(area, 0)) for area in areas]
    out("%s %s   %s" % (style.b(str(len(areas))),
                        "area" if len(areas) == 1 else "areas",
                        style.d(" · ".join(parts))))


def print_vocabulary(style):
    """The words the checker accepts in a requirement's block, and nothing
    of what the standard says about them.

    Read off the checker's own constants and the project's configuration,
    never spelled here: the standard says what the words mean and when to
    use them, the checker refuses a block written outside them, and this
    prints the checker's list so that a procedure that needs a status or a
    field name asks for forty words instead of the standard.
    In the order the checker keeps them — the lifecycle for the statuses,
    the block's own order for the fields — which is the order a reader
    meets them in.
    """
    # annotation removed on install
    rows = (
        ("types", srs_check.TYPES),
        ("statuses", STATUSES),
        ("verification", srs_check.VERIFICATIONS),
        ("fields", srs_check.SCALAR_FIELDS + srs_check.LIST_FIELDS),
        ("required", srs_check.REQUIRED_FIELDS),
        ("areas", srs_check.AREAS),
        ("modal verbs", srs_check.CFG["modal_verbs"]),
    )
    for label, words in rows:
        out("%s %s" % (style.d("%-13s" % label), " ".join(words)))


def prose_path_hint(needle):
    """The text searched for, where it names a path the project carries.

    A path is not in what the search reads — it lives in the `code` and
    `tests` fields — so searching for one answers nothing while the mode
    beside it answers exactly.
    """
    # annotation removed on install
    candidate = needle.strip()
    if not candidate:
        return None
    # From the repository first, then from wherever the reader is standing
    # — and both translated the way the mode for paths translates them, so
    # what comes back is the path as the specification would write it.
    # Refused where it lands outside: a file in whatever directory the
    # reader happens to stand in, an absolute path anywhere on the machine,
    # or a climb through `..` is not a path this project carries, and the
    # mode named would answer nothing.
    for probe in (os.path.join(ROOT, candidate.replace("/", os.sep)),
                  candidate):
        if not os.path.exists(probe):
            continue
        inside = _repo_relative(probe)
        if inside:
            return inside
    return None


def print_prose(model, args, style):
    """The prose half of a text search, and what it left out.

    After the requirements rather than before: the cheap answer is read
    first, and a line of prose is as long as its meaning.
    """
    # annotation removed on install
    if not args.grep:
        return
    narrowed = [name for name in ("area", "status", "type", "verification",
                                  "code")
                if getattr(args, name, None)]
    hint = prose_path_hint(args.grep)
    present, missing = collect_prose(model["requirements"])

    if narrowed:
        # A filter is a statement that the question is about requirements.
        # Said out loud, because a reader never told concludes the prose
        # is not searched at all and stops asking.
        out(style.d("prose not searched: --%s asks about requirements"
                    % narrowed[0]))
    else:
        hits = grep_prose(args.grep, present)
        for path, lineno, text in hits[:PROSE_HIT_LIMIT]:
            out("%s  %s" % (style.b("%s:%d" % (path, lineno)), text))
        if len(hits) > PROSE_HIT_LIMIT:
            out(style.d("%d more line(s) in the prose are not shown"
                        % (len(hits) - PROSE_HIT_LIMIT)))
        if missing:
            out(style.d("not searched, the project has no %s"
                        % ", ".join(missing)))
    if hint:
        out(style.d("%s is a path — `--code %s` answers about it"
                    % (hint, hint)))


def print_line(entry, style, statements=False):
    # annotation removed on install
    # Identifier, status, title, file — the four parts of a citation, in
    # the order they are read; the file is the path alone, never the line.
    out("%s  %-12s %s  %s" % (style.b("%-14s" % entry["id"]),
                              entry["status"] or "?", entry["title"],
                              style.d(entry["path"])))
    if statements and entry["statement"]:
        # annotation removed on install
        # The statement beneath the line, on request: what the requirement
        # obliges, so that the reader chooses by it rather than by the
        # title — and never the rationale, which is read once the choice
        # is made, in the card.
        out(emphasize(wrap(entry["statement"], indent="    "), style))


def print_list(entries, style, statements=False):
    if not entries:
        out(style.d("nothing matches"))
        return
    for entry in entries:
        print_line(entry, style, statements)


def print_line_answer(model, path, line, style, listing, statements=False):
    # annotation removed on install
    """What a line of a file marks, and how many the whole file answers
    for — the second from the path mode, so the two never disagree about
    the file."""
    marked = requirements_for_line(path, line)
    whole = requirements_for_path(model, path)
    if not listing:
        print_counts(model, style)
        out()
    index = by_id(model)
    entries = [index[rid] for rid in sorted(marked, key=srs_parse.id_key) if rid in index]
    unknown = sorted((rid for rid in marked if rid not in index), key=srs_parse.id_key)
    if not entries and not unknown:
        out(style.d("no annotation covers %s:%d" % (path, line)))
    for entry in entries:
        print_line(entry, style, statements)
    for rid in unknown:
        out("%-15s %s" % (rid, style.d("annotated here, not in the "
                                       "specification")))
    out(style.d("the whole file answers for %d requirement(s) — "
                "--code %s without a line lists them" % (len(whole), path)))


def where_realized(entry):
    """Every annotation naming the requirement, and every file its fields
    name that carries none: [(path, line or None, keyword or None)], the
    annotated ones in file order, the unannotated files after them.

    Two sources, because the specification points at code on two levels:
    the fields name files, the annotations name lines, and a file the
    field claims that no line speaks for is part of the answer — it is
    the one the reader will have to open whole.
    """
    # annotation removed on install
    found = []
    seen = set()
    named = list(entry["code"]) + [p for p in entry["tests"] if p not in entry["code"]]
    candidates = []
    for rel in named:
        full = os.path.join(ROOT, rel)
        if os.path.isdir(full):
            for current, dirs, files in os.walk(full):
                dirs[:] = [d for d in dirs if not d.startswith(".")]
                for name in sorted(files):
                    candidates.append(os.path.relpath(os.path.join(current, name), ROOT)
                                      .replace(os.sep, "/"))
        else:
            candidates.append(rel)
    for rel in srs_check.iter_source_files():
        if rel not in candidates:
            candidates.append(rel)
    annotated_files = set()
    for rel in candidates:
        full = os.path.join(ROOT, rel)
        if rel in seen or not os.path.isfile(full):
            continue
        seen.add(rel)
        try:
            annotations = srs_check.read_annotations(full)
        except (OSError, UnicodeError):
            continue
        for lineno, keyword, rid in annotations:
            if rid == entry["id"]:
                found.append((rel, lineno, keyword))
                annotated_files.add(rel)
    for rel in named:
        full = os.path.join(ROOT, rel)
        if os.path.isfile(full) and rel not in annotated_files:
            found.append((rel, None, None))
        elif os.path.isdir(full) and not any(
                f.startswith(rel.rstrip("/") + "/") for f in annotated_files):
            found.append((rel, None, None))
    return found


def region_of(rel, lineno, bound=60):
    """The lines an annotation marks, as (first, last), 1-based inclusive.

    A Python file has a structure the standard library parses: the region
    is the innermost function or class whose span holds the line, or whose
    definition starts within three lines below it — an annotation sits
    on the line above `def`, or as the body's first comment. Any other
    file has none the tool can read: the region runs from the annotation
    to the line before the next one, or `bound` lines, whichever is first.
    """
    # annotation removed on install
    full = os.path.join(ROOT, rel)
    with open(full, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    # splitlines, not split: a file ending in a newline has no empty last
    # line, and a region bounded by the file's end must not print one.
    lines = text.splitlines()
    total = len(lines)
    if rel.endswith(".py"):
        import ast
        try:
            tree = ast.parse(text)
        except SyntaxError:
            tree = None
        if tree is not None:
            best = None
            for node in ast.walk(tree):
                if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                    continue
                start = min([node.lineno] + [d.lineno for d in node.decorator_list])
                end = node.end_lineno
                if start <= lineno <= end or lineno < start <= lineno + 3:
                    span = end - start
                    if best is None or span < best[2]:
                        best = (start, end, span)
            if best is not None:
                return min(best[0], lineno), best[1]
    last = min(total, lineno + bound - 1)
    for other, _kw, _rid in srs_check.read_annotations(full):
        if lineno < other <= last:
            last = other - 1
            break
    return lineno, last


def print_where(entry, style, source=False):
    # annotation removed on install
    places = where_realized(entry)
    if not places:
        out(style.d("%s names no file and no annotation names it" % entry["id"]))
        return
    # The files no line speaks for first: under --source the regions run
    # long, and the one fact the reader must not miss is which file they
    # will have to open whole.
    for rel, lineno, keyword in places:
        if lineno is None:
            out("%s  %s" % (rel, style.d("named in the fields, no annotation for %s" % entry["id"])))
    for rel, lineno, keyword in places:
        if lineno is None:
            continue
        out("%s:%d  %s" % (rel, lineno, keyword))
        if source:
            # annotation removed on install
            first, last = region_of(rel, lineno)
            with open(os.path.join(ROOT, rel), "r", encoding="utf-8", errors="replace") as handle:
                lines = handle.read().splitlines()
            width = len(str(last))
            for number in range(first, last + 1):
                out("  %s  %s" % (style.d(str(number).rjust(width)), lines[number - 1]))
            out()


def wrap(text, width=76, indent="  "):
    lines = []
    for paragraph in text.split("\n"):
        paragraph = paragraph.strip()
        if not paragraph:
            lines.append("")
            continue
        current = indent
        for word in paragraph.split():
            if len(current) + len(word) + 1 > width and current.strip():
                lines.append(current.rstrip())
                current = indent
            current += word + " "
        lines.append(current.rstrip())
    return "\n".join(lines).strip("\n")


def emphasize(text, style):
    """**bold** as the terminal's bold — and as plain text with the
    asterisks kept when there is no terminal to bold for."""
    if not style.bold:
        return text
    pieces = text.split("**")
    if len(pieces) < 3:
        return text
    return "".join(piece if index % 2 == 0 else style.b(piece)
                   for index, piece in enumerate(pieces))


def citation(entry):
    # annotation removed on install
    """The form a requirement is named in outside the specification.

    Assembled here and nowhere else: the identifier, the title, the file
    and the status, in the order they are read. No line number — it is
    right for the minute it is written and wrong after the next edit above
    it, and the card below prints the current one for whoever wants to
    open the file.
    """
    return "%s — %s (%s, %s)" % (entry["id"], entry["title"], entry["path"],
                                 entry["status"] or "?")


def print_card(entry, model, style):
    # annotation removed on install
    known = by_id(model)
    out("%s — %s" % (style.b(entry["id"]), entry["title"]))
    out("  status %s   verification %s   %s"
        % (entry["status"] or "?", entry["verification"] or "?",
           style.d("%s:%d" % (entry["path"], entry["line"]))))
    if entry["statement"]:
        out()
        out(emphasize(wrap(entry["statement"]), style))
    if entry["rationale"]:
        out()
        out(emphasize(wrap(entry["rationale"]), style))
    out()
    for field in LINK_FIELDS:
        for target in entry[field]:
            other = known.get(target)
            out("  %-14s -> %-14s %s"
                % (field, target,
                   style.d("(%s)" % other["status"]) if other
                   else style.d("(unknown)")))
    if entry["superseded_by"]:
        other = known.get(entry["superseded_by"])
        out("  %-14s -> %-14s %s"
            % ("superseded_by", entry["superseded_by"],
               style.d("(%s)" % other["status"]) if other
               else style.d("(unknown)")))
    for field, source in model["incoming"].get(entry["id"], []):
        other = known.get(source)
        out("  %-14s <- %-14s %s"
            % (INCOMING_LABEL.get(field, field), source,
               style.d("(%s)" % other["status"]) if other
               else style.d("(unknown)")))
    for field in ("code", "tests"):
        for path in entry[field]:
            out("  %-14s    %s" % (field, path))


def children_of(model, rid):
    """Down the tree is *incoming* derives_from/refines: those links
    point from the specific requirement up to the general one."""
    result = []
    for field, source in model["incoming"].get(rid, []):
        if field in ("derives_from", "refines"):
            result.append((source, field))
    return result


def parents_of(entry):
    result = []
    for field in ("derives_from", "refines"):
        for target in entry[field]:
            result.append((target, field))
    return result


def print_tree(model, rid, upwards, style):
    # annotation removed on install
    known = by_id(model)

    def walk(node, prefix, seen):
        if upwards:
            entry = known.get(node)
            edges = parents_of(entry) if entry else []
        else:
            edges = children_of(model, node)
        edges.sort()
        for index, (other, field) in enumerate(edges):
            last = index == len(edges) - 1
            branch = "└── " if last else "├── "
            entry = known.get(other)
            status = entry["status"] if entry else "unknown"
            title = entry["title"] if entry else ""
            out("%s%s%s  %-12s %s %s"
                % (prefix, branch, style.b("%-14s" % other), status,
                   title, style.d("(%s)" % field)))
            if other in seen:
                out("%s%s%s" % (prefix, "    " if last else "│   ",
                                style.d("… already shown (link cycle)")))
                continue
            walk(other, prefix + ("    " if last else "│   "),
                 seen | {other})

    root = known.get(rid)
    if root is None:
        return False
    out("%s  %-12s %s" % (style.b(rid), root["status"], root["title"]))
    walk(rid, "", {rid})
    return True


def print_coverage(model, style):
    # annotation removed on install
    known = by_id(model)
    print_counts(model, style)
    out()

    untested = [e for e in model["requirements"]
                if e["status"] in ("implemented", "partial") and not e["tests"]]
    out(style.b("Realized without listed tests: %d" % len(untested)))
    for entry in untested:
        out("  %-14s %-12s method %s  %s"
            % (entry["id"], entry["status"], entry["verification"] or "?",
               entry["title"]))

    ahead = [e for e in model["requirements"]
             if e["status"] == "draft" and e["code"]]
    out()
    out(style.b("Draft with code — implementation ahead of approval: %d"
                % len(ahead)))
    for entry in ahead:
        out("  %-14s %s" % (entry["id"], entry["title"]))

    resting = []
    for entry in model["requirements"]:
        if entry["status"] not in ("implemented", "partial"):
            continue
        for field in ("derives_from", "depends_on", "refines"):
            for target in entry[field]:
                other = known.get(target)
                if other and other["status"] == "draft":
                    resting.append((entry["id"], field, target))
    out()
    # Counted by requirement, which is what the summary names and what
    # the page already reported; listed by link, because which field
    # reaches which draft is what a reader acts on. One requirement resting on two
    # drafts is one in the count and two lines under it — counting the
    # lines instead inflated the number an audit starts from.
    out(style.b("Realized but resting on a draft: %d"
                % len({rid for rid, _, _ in resting})))
    for rid, field, target in resting:
        out("  %-14s %s %s" % (rid, field, target))

    out()
    out(style.b("Code files no requirement references: %d of %d"
                % (len(model["orphan_code"]), model["code_total"])))
    for path in model["orphan_code"]:
        out("  %s" % path)


# --------------------------------------------------------------------
# Diff against a baseline revision
# --------------------------------------------------------------------

class ViewError(Exception):
    """Something the user can fix; reported plainly with exit code 2."""


def git(args, cwd=ROOT):
    return subprocess.check_output(["git"] + args, cwd=cwd,
                                   stderr=subprocess.PIPE)


def load_revision(rev):
    # annotation removed on install
    """Parses the specification as of `rev`. Paths come from git, i.e.
    relative to the git root, which is not necessarily this script's
    ROOT — nested repositories exist."""
    try:
        top = git(["rev-parse", "--show-toplevel"]).decode("utf-8").strip()
    except (OSError, subprocess.CalledProcessError):
        raise ViewError("git is unavailable or this is not a git "
                        "repository — --diff needs both")
    # realpath on both sides: git reports the physical path, while ROOT
    # comes from __file__ and keeps whatever symlinks led here (/tmp on
    # macOS). A mismatched prefix would walk out of the repository.
    prefix = os.path.relpath(os.path.realpath(ROOT),
                             os.path.realpath(top)).replace(os.sep, "/")
    prefix = "" if prefix == "." else prefix + "/"
    # From here on git runs at the top of the repository: an ls-tree
    # pathspec is resolved against the current directory, so running it
    # from a nested ROOT would look for <prefix>/<prefix>/specs and
    # quietly report every requirement as new.
    #
    # -z, because a path outside ASCII comes back C-quoted otherwise
    # ("specs/10-\321\204.md") — and a specification in any language is
    # the point of this framework.
    try:
        listing = git(["ls-tree", "-r", "-z", "--name-only", rev, "--",
                       prefix + "specs"], cwd=top).decode("utf-8", "replace")
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.decode("utf-8", "replace").strip()
        raise ViewError("cannot read revision %s: %s" % (rev, detail))

    problems = []
    requirements = []
    for git_path in sorted(filter(None, listing.split("\0"))):
        rel = git_path[len(prefix):] if prefix else git_path
        name = os.path.basename(rel)
        parts = rel.split("/")
        if not name.endswith(".md") or name in srs_check.SKIP_FILES:
            continue
        if any(part in srs_check.SKIP_DIRS for part in parts):
            continue
        blob = git(["show", "%s:%s" % (rev, git_path)], cwd=top)
        requirements.extend(srs_check.parse_text(
            blob.decode("utf-8", "replace"), rel, problems))
    return build_model(requirements, problems, with_code_scan=False)


BASELINE_LOG = "92-baselines.md"


def version_key(version):
    parts = version.split(".")
    return tuple(int(p) if p.isdigit() else 0 for p in parts[:3])


def versions_in(text):
    """The versions a baseline log names, oldest first. Spacing inside the
    cells is the writer's business: a row typed by hand is as valid as one
    the tooling wrote."""
    seen = []
    for version in re.findall(r"^\|\s*(\d+(?:\.\d+)+)\s*\|", text, re.M):
        if version not in seen:
            seen.append(version)
    return sorted(seen, key=version_key)


def logged_baselines():
    # annotation removed on install
    """The versions the baseline log records, oldest first.

    The log is what defines a baseline: a `spec/v*` tag is a bookmark
    somebody may or may not have made, and requiring one would put the
    process at the mercy of whichever git client a project uses.
    """
    try:
        with open(os.path.join(SPECS, BASELINE_LOG), "r",
                  encoding="utf-8") as handle:
            return versions_in(handle.read())
    except OSError:
        return []


def has_tag(version):
    try:
        listed = git(["tag", "-l", "spec/v%s" % version])
    except (OSError, subprocess.CalledProcessError, ViewError):
        return False
    return bool(listed.decode("utf-8", "replace").strip())


def introduces(revision, path, version, top):
    """Whether this commit is where that version's row appeared.

    A commit that merely *contains* the row proves nothing: in a shallow
    checkout the oldest commit available contains every row there has ever
    been, and answering with it would date every baseline to the same
    revision and report that nothing ever changed.
    """
    try:
        parent = git(["rev-parse", "-q", "--verify", "%s^" % revision],
                     cwd=top).decode("utf-8").strip()
    except (OSError, subprocess.CalledProcessError):
        # No parent to compare against: a root commit, or the boundary of
        # a shallow one — and at a boundary the honest answer is that this
        # cannot be known.
        try:
            shallow = git(["rev-parse", "--is-shallow-repository"],
                          cwd=top).decode("utf-8").strip()
        except (OSError, subprocess.CalledProcessError):
            return False
        if shallow != "false":
            return False
        # A parentless commit brought its whole log in at once — history
        # that was squashed or imported looks exactly like this. Only the
        # newest version it names describes the tree it left behind; the
        # states the older rows froze are not in this repository at all.
        try:
            blob = git(["show", "%s:%s" % (revision, path)], cwd=top)
        except (OSError, subprocess.CalledProcessError):
            return False
        present = versions_in(blob.decode("utf-8", "replace"))
        return bool(present) and version == present[-1]
    try:
        blob = git(["show", "%s:%s" % (parent, path)], cwd=top)
    except (OSError, subprocess.CalledProcessError):
        return True                     # the log did not exist yet
    return version not in versions_in(blob.decode("utf-8", "replace"))


def baseline_revision(version):
    """The revision a baseline froze: its tag where one was made,
    otherwise the commit that added its row — and nothing at all where
    neither can be established.

    Both halves are needed. Rows have been written a release late for
    this project's whole history, so their commit is not what those tags
    froze; and a project that never tags still has baselines.
    """
    if has_tag(version):
        return "spec/v%s" % version
    try:
        top = git(["rev-parse", "--show-toplevel"]).decode("utf-8").strip()
        prefix = os.path.relpath(os.path.realpath(ROOT),
                                 os.path.realpath(top)).replace(os.sep, "/")
        prefix = "" if prefix == "." else prefix + "/"
        path = prefix + "specs/" + BASELINE_LOG
        # One call finds a row written the way the tooling writes it. A row
        # typed by hand may space its cells otherwise — and this reads such
        # a row perfectly well — so a miss falls back to the file's own
        # history rather than declaring the baseline lost.
        found = git(["log", "--reverse", "--format=%H",
                     "-S", "| %s |" % version, "--", path], cwd=top)
        candidates = found.decode("utf-8", "replace").split()
        if not candidates:
            candidates = []
            history = git(["log", "--reverse", "--format=%H", "--", path],
                          cwd=top).decode("utf-8", "replace").split()
            for revision in history:
                blob = git(["show", "%s:%s" % (revision, path)], cwd=top)
                if version in versions_in(blob.decode("utf-8", "replace")):
                    candidates = [revision]
                    break
        for revision in candidates:
            if introduces(revision, path, version, top):
                return revision
    except (OSError, subprocess.CalledProcessError, ViewError):
        return None
    return None


def fingerprint(text):
    """Enough of a statement to notice it was reworded, not enough to
    carry the whole specification into the page once per baseline."""
    return hashlib.sha1(" ".join(text.split()).encode("utf-8")).hexdigest()[:12]


def baseline_snapshots():
    # annotation removed on install
    """[{tag, version, requirements: {id: {fields…}}}], oldest first.

    A snapshot per baseline is what lets the page compare an arbitrary
    pair without a clone; statements travel as fingerprints.
    """
    snapshots = []
    for version in logged_baselines():
        revision = baseline_revision(version)
        if not revision:
            continue
        try:
            model = load_revision(revision)
        except ViewError:
            continue
        requirements = {}
        for entry in model["requirements"]:
            requirements[entry["id"]] = {
                "title": entry["title"],
                "status": entry["status"],
                "verification": entry["verification"],
                "code": entry["code"],
                "tests": entry["tests"],
                "derives_from": entry["derives_from"],
                "depends_on": entry["depends_on"],
                "refines": entry["refines"],
                "conflicts_with": entry["conflicts_with"],
                "superseded_by": entry["superseded_by"],
                "exempt": entry["exempt"],
                "statement": fingerprint(entry["statement"]),
            }
        snapshots.append({"tag": "spec/v%s" % version, "version": version,
                          "requirements": requirements})
    return as_deltas(snapshots)


def as_deltas(snapshots):
    """The first baseline in full, every later one as its change.

    A snapshot per baseline costs the size of the whole specification
    each time; the page is meant to be carried around, and ten baselines
    of a growing specification is not a page any more. The reader still
    compares an arbitrary pair — the page folds the deltas up to each
    end first.
    """
    out = []
    for index, snap in enumerate(snapshots):
        entry = {"tag": snap["tag"], "version": snap["version"]}
        if index == 0:
            entry["full"] = snap["requirements"]
        else:
            before = snapshots[index - 1]["requirements"]
            now = snap["requirements"]
            entry["put"] = dict((rid, fields) for rid, fields in now.items()
                                if before.get(rid) != fields)
            entry["drop"] = sorted((rid for rid in before if rid not in now), key=srs_parse.id_key)
        out.append(entry)
    return out


DIFF_FIELDS = ("status", "verification", "title", "superseded_by",
               "code", "tests", "exempt") + LINK_FIELDS


def statement_words(text):
    # annotation removed on install
    """A statement as its words, so that where its lines end is not a difference.

    A line break inside a markdown paragraph renders as a space and is invisible to every reader;
    only `git diff` sees it. Comparing the raw text made a reflow of the specification report every
    statement in it as changed, which is the reading this command exists to spare its reader.
    """
    return " ".join((text or "").split())


def compute_diff(old_model, new_model):
    """Working tree against the revision — not HEAD against it."""
    old = by_id(old_model)
    new = by_id(new_model)
    added = [new[rid] for rid in sorted(set(new) - set(old), key=srs_parse.id_key)]
    removed = [old[rid] for rid in sorted(set(old) - set(new), key=srs_parse.id_key)]
    changed = []
    for rid in sorted(set(old) & set(new), key=srs_parse.id_key):
        fields = []
        for field in DIFF_FIELDS:
            if old[rid][field] != new[rid][field]:
                fields.append((field, old[rid][field], new[rid][field]))
        statement = []
        if statement_words(old[rid]["statement"]) != statement_words(new[rid]["statement"]):
            statement = list(difflib.unified_diff(
                old[rid]["statement"].split("\n"),
                new[rid]["statement"].split("\n"),
                lineterm="", n=1))[2:]
        if fields or statement:
            changed.append({"entry": new[rid], "fields": fields,
                            "statement": statement})
    return {"rev": None, "added": added, "removed": removed,
            "changed": changed}


def _format_value(value):
    if isinstance(value, list):
        return "[%s]" % ", ".join(value) if value else "[]"
    return value or "—"


def _repo_relative(path):
    """A path as the specification would write it, or None when it
    points outside the repository."""
    inside = os.path.relpath(os.path.realpath(path),
                             os.path.realpath(ROOT)).replace(os.sep, "/")
    return None if inside.startswith("..") else inside


def print_diff(diff, style):
    out("%s  %s" % (style.b("Changes since %s" % diff["rev"]),
                    style.d("(working tree against the revision)")))
    out()
    out(style.b("added (%d)" % len(diff["added"])))
    for entry in diff["added"]:
        out("  + %-14s %-12s %s"
            % (entry["id"], entry["status"], entry["title"]))
    out()
    out(style.b("removed (%d)" % len(diff["removed"])))
    for entry in diff["removed"]:
        out("  - %-14s %-12s %s"
            % (entry["id"], entry["status"], entry["title"]))
    out()
    out(style.b("changed (%d)" % len(diff["changed"])))
    for item in diff["changed"]:
        out("  ~ %-14s %s" % (item["entry"]["id"], item["entry"]["title"]))
        for field, before, after in item["fields"]:
            out("      %-14s %s -> %s"
                % (field, _format_value(before), _format_value(after)))
        for line in item["statement"]:
            out("      %s" % line)


# --------------------------------------------------------------------
# HTML
# --------------------------------------------------------------------

CSS = """
:root {
  --bg: #ffffff; --fg: #1a1d21; --muted: #6b7280; --line: #e2e5e9;
  --panel: #f7f8fa; --accent: #2c5fd0; --mark: #fff3b0;
  --draft: #b45309; --deferred: #6d28d9; --partial: #0e7490;
  --implemented: #15803d; --superseded: #6b7280; --withdrawn: #9f1239;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #14171a; --fg: #e6e8ea; --muted: #9aa3ad; --line: #2a2f36;
    --panel: #1b1f24; --accent: #7aa2f7; --mark: #4a3f14;
    --draft: #f59e0b; --deferred: #a78bfa; --partial: #22d3ee;
    --implemented: #4ade80; --superseded: #9aa3ad; --withdrawn: #fb7185;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--bg); color: var(--fg);
  font: 15px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
        Helvetica, Arial, sans-serif;
}
code, pre { font-family: ui-monospace, SFMono-Regular, Menlo,
  Consolas, monospace; font-size: 0.9em; }
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
header {
  border-bottom: 1px solid var(--line); padding: 14px 20px;
  display: flex; flex-wrap: wrap; gap: 14px; align-items: baseline;
}
header h1 { font-size: 17px; margin: 0; }
header .counts { color: var(--muted); font-size: 13px; }
nav { margin-left: auto; display: flex; gap: 6px; }
nav button {
  font: inherit; font-size: 13px; padding: 4px 12px; cursor: pointer;
  background: var(--panel); color: var(--fg);
  border: 1px solid var(--line); border-radius: 6px;
}
nav button[aria-selected="true"] { background: var(--accent); color: #fff;
  border-color: var(--accent); }
.layout { display: flex; align-items: flex-start; }
aside {
  width: 250px; flex: none; padding: 16px; border-right: 1px solid var(--line);
  position: sticky; top: 0; max-height: 100vh; overflow-y: auto;
}
main { flex: 1; padding: 16px 20px; min-width: 0; }
#search {
  width: 100%; font: inherit; padding: 6px 8px; border-radius: 6px;
  border: 1px solid var(--line); background: var(--bg); color: var(--fg);
}
aside h2 {
  font-size: 11px; text-transform: uppercase; letter-spacing: .07em;
  color: var(--muted); margin: 18px 0 6px;
}
.chip {
  display: inline-block; font-size: 12px; padding: 2px 8px; margin: 2px 2px 2px 0;
  border: 1px solid var(--line); border-radius: 999px; cursor: pointer;
  background: var(--panel); color: var(--fg); user-select: none;
}
.chip[aria-pressed="true"] { background: var(--accent); color: #fff;
  border-color: var(--accent); }
.chip .n { color: var(--muted); }
.chip[aria-pressed="true"] .n { color: #dbe4f7; }
aside ul { list-style: none; margin: 0; padding: 0; }
aside li { font-size: 13px; margin: 3px 0; word-break: break-all; }
article {
  border: 1px solid var(--line); border-radius: 8px; padding: 12px 14px;
  margin-bottom: 12px; background: var(--panel);
}
article.superseded { opacity: .6; }
article h3 { margin: 0 0 6px; font-size: 15px; }
article h3 .id { font-family: ui-monospace, monospace; }
.badge {
  font-size: 11px; padding: 1px 7px; border-radius: 999px; margin-left: 6px;
  border: 1px solid currentColor; white-space: nowrap;
}
.st-draft { color: var(--draft); }
.st-deferred { color: var(--deferred); }
.st-partial { color: var(--partial); }
.st-implemented { color: var(--implemented); }
.st-superseded { color: var(--superseded); }
.st-withdrawn { color: var(--withdrawn); }
.badge.new { background: var(--implemented); color: #fff; border-color: transparent; }
.badge.changed { background: var(--draft); color: #fff; border-color: transparent; }
.notation { color: var(--muted); font-size: 12px; margin: 0 0 14px; max-width: 70ch; }
.notation b { color: var(--fg); font-weight: 600; }
.where { color: var(--muted); font-size: 12px; }
.statement { margin: 8px 0; }
.statement .modal { background: var(--mark); padding: 0 3px; border-radius: 3px; }
.rationale { color: var(--muted); font-size: 14px; margin: 8px 0; }
.links { display: grid; grid-template-columns: auto auto 1fr; gap: 2px 10px;
  font-size: 13px; margin-top: 8px; }
.links .rel { color: var(--muted); }
.banner {
  border: 1px solid var(--draft); color: var(--draft); border-radius: 8px;
  padding: 10px 14px; margin-bottom: 14px; font-size: 14px;
}
table { border-collapse: collapse; font-size: 14px; }
th, td { text-align: left; padding: 4px 14px 4px 0; }
th { color: var(--muted); font-weight: 600; font-size: 12px;
  text-transform: uppercase; letter-spacing: .05em; }
section h2 { font-size: 15px; margin: 22px 0 8px; }
.scroll { overflow-x: auto; max-width: 100%; }
.graph text { font-family: ui-monospace, monospace; font-size: 11px;
  fill: var(--fg); }
/* The status is the node's colour. `currentColor` picks it up from
   the st-* class the node already carries; a stroke named here would
   win against it, which is how the class sat on every node for two
   releases without colouring anything. */
.graph .node rect { fill: currentColor; fill-opacity: .13;
  stroke: currentColor; }
.graph .node.dim { opacity: .2; }
/* The backdrop is decoration and must not take the click: catching it
   folded a whole area away when the reader clicked between two boxes. */
.graph .lane-band { fill: var(--fg); fill-opacity: .045;
  pointer-events: none; }
.graph .lane-name { fill: var(--muted); font-size: 12px;
  pointer-events: none; }
.graph .lane-head { fill: var(--fg); fill-opacity: .08; cursor: pointer; }
.graph .lane-head:hover { fill-opacity: .16; }
.graph .lane.collapsed .lane-band { fill-opacity: .13; }
.graph .node.folded, .graph .edge.folded { display: none; }
/* The rail is beside the drawing, not on top of it: floated over the
   canvas both legends covered the first column and the reader panned the
   graph out from under them to read it. Stacked rather than in a row,
   because a legend is a list. */
.stage { display: flex; gap: 10px; align-items: stretch; }
#graph-svg { display: block; flex: 1 1 auto; min-width: 0; height: 70vh; min-height: 320px; cursor: grab; touch-action: none; user-select: none; -webkit-user-select: none; }
#graph-rail { flex: 0 0 170px; display: flex; flex-direction: column;
  gap: 10px; font-size: 12px; max-height: 70vh; overflow-y: auto; }
#graph-rail > div { background: var(--panel); border: 1px solid var(--line);
  border-radius: 4px; padding: 6px 8px; }
#graph-controls { display: flex; flex-direction: column;
  align-items: stretch; gap: 6px; }
#graph-controls label { display: flex; flex-direction: column; gap: 2px;
  color: var(--muted); }
#graph-controls select { font: inherit; font-size: 12px; width: 100%; }
#graph-legend { display: flex; flex-direction: column; gap: 3px; }
#graph-legend .legend-title { margin: 0 0 1px; color: var(--muted);
  text-transform: uppercase; letter-spacing: .05em; font-size: 10px; }
#graph-legend .key { display: flex; align-items: center; gap: 6px;
  white-space: nowrap; }
/* The swatch takes the status colour from the key's own class, the same
   way a node's box does — one palette, named in one place. */
#graph-legend .key .dot { width: 10px; height: 10px; border-radius: 2px;
  flex: none; background: currentColor; opacity: .85; }
#graph-legend .swatch { flex: none; }
.graph .node.out, .graph .edge.out { display: none; }
#graph-reset { font: inherit; font-size: 12px; padding: 3px 8px; cursor: pointer; background: var(--panel); color: var(--fg); border: 1px solid var(--line); border-radius: 4px; }
@media (max-width: 720px) {
  .stage { flex-direction: column; }
  #graph-rail { flex: none; max-height: none; flex-direction: row;
    flex-wrap: wrap; }
}
#graph-svg:active { cursor: grabbing; }
#graph-svg.focused .node, #graph-svg.focused .edge { opacity: .25; }
#graph-svg.focused .node.sel, #graph-svg.focused .node.lit,
#graph-svg.focused .edge.lit { opacity: 1; }
.graph .node.sel rect { stroke-width: 2.5; }
.graph .edge.lit { stroke: var(--fg); stroke-width: 2; }
.graph .edge { stroke: var(--muted); fill: none; }
.graph .edge.refines { stroke-dasharray: 6 3; }
.graph .edge.depends_on { stroke-dasharray: 2 3; }
.graph .edge.conflicts_with { stroke-dasharray: 8 3 2 3; }
footer { border-top: 1px solid var(--line); margin-top: 24px; padding: 12px 20px;
  color: var(--muted); font-size: 12px; }
[hidden] { display: none !important; }
@media print {
  aside, nav, .banner { display: none; }
  body { font-size: 11pt; }
  article { break-inside: avoid; border-color: #ccc; background: none; }
  #view-dash, #view-graph { display: block !important; }
}
.key.kind { cursor: pointer; user-select: none; border-radius: 4px; }
.key.kind[aria-pressed="false"] { opacity: .35; }
"""

# Leaving a kind out is a class on the drawing rather than a style on each
# edge: the script rebuilds an edge when an area folds, and a style set
# on the element would not survive that. Generated from LINK_FIELDS so a
# kind added later cannot arrive unhideable.
EDGE_HIDE_CSS = "".join(
    "#graph-svg.hide-%s .edge.%s { display: none; }\n" % (field, field)
    for field in LINK_FIELDS)

JS = """
(function () {
  var cards = Array.prototype.slice.call(
    document.querySelectorAll('article[data-id]'));
  var gsvg = document.getElementById('graph-svg');
  if (gsvg) {
    var stage = document.getElementById('graph-stage');
    var NW = +gsvg.dataset.nw, NH = +gsvg.dataset.nh;
    var view = { x: 0, y: 0, k: 1 };
    var edges = Array.prototype.slice.call(gsvg.querySelectorAll('path.edge'));
    var nodes = {};
    Array.prototype.forEach.call(gsvg.querySelectorAll('g.node'), function (g) {
      nodes[g.dataset.id] = g;
    });

    // applyView, not apply: the filters declare an `apply` of their own
    // at the top level of this script, and a function declared inside a
    // block is also assigned to the enclosing function's binding of the
    // same name (Annex B). Two functions named `apply` meant every filter
    // click moved the graph instead of filtering, silently, for as long
    // as both existed.
    function applyView() {
      stage.setAttribute('transform', 'translate(' + view.x + ',' + view.y
        + ') scale(' + view.k + ')');
    }

    // Screen pixels per viewBox unit. The canvas fills its panel, so this
    // is whatever the browser chose when fitting the viewBox — without it
    // a drag of ten pixels would move a node by ten user units, which is
    // only the same thing by accident.
    function unit() {
      var m = gsvg.getScreenCTM();
      return m && m.a ? m.a : 1;
    }

    // A point needs the whole inverse, not just the scale: the drawing is
    // centred in the panel, so there is a margin between the element's
    // corner and the viewBox origin — and it is most of the panel when a
    // wide graph sits in a tall one.
    function toDrawing(clientX, clientY) {
      var m = gsvg.getScreenCTM();
      if (!m) { return { x: 0, y: 0 }; }
      var i = m.inverse();
      return { x: clientX * i.a + clientY * i.c + i.e,
               y: clientX * i.b + clientY * i.d + i.f };
    }

    // The same three rules as edge_path() in the generator: within a lane
    // the two boxes share an x, so the edge leaves the right-hand side and
    // bows out past what sits between them; across lanes it leaves the
    // side facing the other lane. Both copies have to agree — collapsing
    // an area recomputes an edge, and one that changed shape while the
    // reader was watching would read as a different link.
    var BOW_MAX = 34;
    function edgePath(a, b) {
      var ax = +a.dataset.x, ay = +a.dataset.y;
      var bx = +b.dataset.x, by = +b.dataset.y;
      var am = ay + NH / 2, bm = by + NH / 2;
      if (a.dataset.area === b.dataset.area) {
        var side = ax + NW;
        var out = side + Math.min(BOW_MAX,
          14 + Math.floor(Math.abs(ay - by) / 5));
        return 'M ' + side + ' ' + am + ' Q ' + out + ' ' + ((am + bm) / 2)
          + ' ' + side + ' ' + bm;
      }
      if (bx > ax) {
        return 'M ' + (ax + NW) + ' ' + am + ' L ' + bx + ' ' + bm;
      }
      return 'M ' + ax + ' ' + am + ' L ' + (bx + NW) + ' ' + bm;
    }

    function redraw(id) {
      edges.forEach(function (path) {
        if (path.dataset.from !== id && path.dataset.to !== id) { return; }
        var a = nodes[path.dataset.from], b = nodes[path.dataset.to];
        if (!a || !b) { return; }
        path.setAttribute('d', edgePath(a, b));
      });
    }

    gsvg.addEventListener('wheel', function (e) {
      e.preventDefault();
      var at = toDrawing(e.clientX, e.clientY);
      var k = Math.min(4, Math.max(0.2, view.k * (e.deltaY < 0 ? 1.1 : 1 / 1.1)));
      view.x = at.x - (at.x - view.x) * (k / view.k);
      view.y = at.y - (at.y - view.y) * (k / view.k);
      view.k = k;
      applyView();
    }, { passive: false });

    // Pointer events, not mouse ones: the same code then works for a
    // finger and a pen, and the CSS turns native scrolling off in
    // exchange — which would leave a touch device with no way to move
    // the graph at all if only mice were handled.
    //
    // A drag is a movement past a threshold, not any movement at all:
    // pressing a mouse button nudges the pointer a pixel or two, and
    // counting that as a drag swallows the click it belongs to.
    //
    // The capture is taken when that threshold is crossed and not before,
    // and this is the whole reason a click ever reaches a node or a lane
    // header. While an element holds the pointer capture the browser
    // dispatches the click to *that* element rather than to the descendant
    // under the cursor — so capturing on pointerdown sent every click to
    // the canvas, and the handlers on the nodes and the headers, being
    // below it, were never reached. Nothing reported it: the click still
    // fired, at the wrong element, and no suite here exercises a gesture
    // (see specs/91-open-issues.md). The capture is only needed to keep a
    // drag alive once the pointer leaves the canvas, which cannot happen
    // before the pointer has moved.
    var DRAG_SLOP = 4;
    var held = null, last = null, from = null, moved = false;
    gsvg.addEventListener('pointerdown', function (e) {
      held = 'stage';
      last = { x: e.clientX, y: e.clientY };
      from = { x: e.clientX, y: e.clientY };
      moved = false;
      // No preventDefault here: cancelling pointerdown suppresses the
      // compatibility mouse events, and with them the click that opens a
      // requirement. Scrolling is held off by touch-action in the CSS,
      // and selection by user-select.
    });
    gsvg.addEventListener('pointermove', function (e) {
      if (!held) { return; }
      var dx = e.clientX - last.x, dy = e.clientY - last.y;
      if (!moved && Math.abs(e.clientX - from.x)
          + Math.abs(e.clientY - from.y) > DRAG_SLOP) {
        moved = true;
        if (gsvg.setPointerCapture) { gsvg.setPointerCapture(e.pointerId); }
      }
      last = { x: e.clientX, y: e.clientY };
      var px = unit();
      view.x += dx / px; view.y += dy / px; applyView();
    });
    function release(e) {
      held = null;
      if (e && e.pointerId !== undefined
          && gsvg.hasPointerCapture(e.pointerId)) {
        gsvg.releasePointerCapture(e.pointerId);
      }
    }
    gsvg.addEventListener('pointerup', release);
    gsvg.addEventListener('pointercancel', release);

    // Collapsing an area is what pulling a node aside used to be: with a
    // lane for an area, what stands in front of the thing being read is a
    // whole column, and moving one box out of nineteen achieves
    // nothing. The members fold onto the lane's header and their edges
    // are recomputed from where they now sit, so an area keeps
    // showing what it is attached to while its contents are out of the
    // way. An edge with both ends inside a folded lane has nothing left
    // to say and goes with them.
    function foldEdges() {
      edges.forEach(function (path) {
        var a = nodes[path.dataset.from], b = nodes[path.dataset.to];
        path.classList.toggle('folded', !!(a && b
          && a.classList.contains('folded')
          && b.classList.contains('folded')));
      });
    }
    // The band shrinks with the column: a lane that hid its members but
    // kept its full height would leave an empty stripe where the reader
    // asked for the space back, and "a single block" is what the
    // requirement says.
    var LANE_FOLD_H = 44;
    var laneList = Array.prototype.slice.call(gsvg.querySelectorAll('g.lane'));
    function setLane(lane, folded) {
      lane.classList.toggle('collapsed', folded);
      var band = lane.querySelector('.lane-band');
      if (band) {
        band.setAttribute('height', folded ? LANE_FOLD_H : lane.dataset.h);
      }
      var name = lane.dataset.area;
      Object.keys(nodes).forEach(function (id) {
        var g = nodes[id];
        if (g.dataset.area !== name) { return; }
        g.classList.toggle('folded', folded);
        g.dataset.x = folded ? lane.dataset.x : g.dataset.x0;
        g.dataset.y = folded ? lane.dataset.y : g.dataset.y0;
        redraw(id);
      });
    }
    laneList.forEach(function (lane) {
      lane.addEventListener('click', function () {
        // Same guard the nodes carry: a pan that happens to end over a
        // header must not fold the column the reader was dragging past.
        if (moved) { moved = false; return; }
        setLane(lane, !lane.classList.contains('collapsed'));
        foldEdges();
      });
    });

    // Narrowing to a root and a radius. A drawing of everything is the
    // one view a specification of any size cannot use; the tools that
    // solve this converge on the same answer, a root and a distance
    // from it.
    var rootSel = document.getElementById('graph-root');
    var depthSel = document.getElementById('graph-depth');
    var neighbours = {};
    edges.forEach(function (p) {
      var a = p.dataset.from, b = p.dataset.to;
      (neighbours[a] = neighbours[a] || []).push(b);
      (neighbours[b] = neighbours[b] || []).push(a);
    });

    function narrow() {
      var root = rootSel ? rootSel.value : '';
      if (!root) {
        Object.keys(nodes).forEach(function (id) {
          nodes[id].classList.remove('out');
        });
        edges.forEach(function (p) { p.classList.remove('out'); });
        return;
      }
      var limit = depthSel ? +depthSel.value : 2;
      var seen = {}, frontier = [root], step = 0;
      seen[root] = true;
      while (step < limit) {
        var next = [];
        frontier.forEach(function (id) {
          (neighbours[id] || []).forEach(function (other) {
            if (!seen[other]) { seen[other] = true; next.push(other); }
          });
        });
        frontier = next;
        step += 1;
      }
      Object.keys(nodes).forEach(function (id) {
        nodes[id].classList.toggle('out', !seen[id]);
      });
      edges.forEach(function (p) {
        p.classList.toggle('out',
          !(seen[p.dataset.from] && seen[p.dataset.to]));
      });
    }
    if (rootSel) { rootSel.addEventListener('change', narrow); }
    if (depthSel) { depthSel.addEventListener('change', narrow); }

    var reset = document.getElementById('graph-reset');
    if (reset) {
      reset.addEventListener('click', function () {
        view = { x: 0, y: 0, k: 1 };
        applyView();
        // Where it started includes the columns that were folded away: a
        // reader who has hidden four areas and cannot find the button that
        // brings them back is worse off than before they folded anything.
        laneList.forEach(function (lane) { setLane(lane, false); });
        // And the kinds of link left out, for the same reason and with the
        // same trap: a dimmed swatch is easy to miss.
        Array.prototype.forEach.call(
          document.querySelectorAll('.key.kind'), function (key) {
            key.setAttribute('aria-pressed', 'true');
            gsvg.classList.remove('hide-' + key.dataset.kind);
          });
        foldEdges();
      });
    }

    // Hovering a node lights what it links to and what links to it; the
    // rest dims, which is the whole reason to point at one rather than
    // squint. The click is left to open the requirement itself.
    function light(node) {
      gsvg.classList.toggle('focused', !!node);
      Object.keys(nodes).forEach(function (id) {
        nodes[id].classList.remove('sel', 'lit');
      });
      edges.forEach(function (p) { p.classList.remove('lit'); });
      if (!node) { return; }
      var id = node.dataset.id;
      node.classList.add('sel');
      edges.forEach(function (p) {
        if (p.dataset.from !== id && p.dataset.to !== id) { return; }
        p.classList.add('lit');
        var other = p.dataset.from === id ? p.dataset.to : p.dataset.from;
        if (nodes[other]) { nodes[other].classList.add('lit'); }
      });
    }

    Object.keys(nodes).forEach(function (id) {
      var g = nodes[id];
      // Not while a drag is under way: the pointer sweeps over half the
      // graph on its way, and the highlight would strobe.
      g.addEventListener('pointerenter', function () {
        if (!held) { light(g); }
      });
      g.addEventListener('pointerleave', function () {
        if (!held) { light(null); }
      });
      g.addEventListener('click', function () {
        if (moved) { moved = false; return; }
        location.hash = id;
        jump();        // hashchange stays silent when the hash repeats
      });
    });
  }

  var baseNode = document.getElementById('baselines-data');
  var baselines = baseNode ? JSON.parse(baseNode.textContent || '[]') : [];
  var LIST_FIELDS = ['code', 'tests', 'derives_from', 'depends_on', 'refines',
                     'conflicts_with', 'exempt'];
  var FLAT_FIELDS = ['title', 'status', 'verification', 'statement',
                     'superseded_by'];

  function snapshotAt(index) {
    var state = {};
    for (var i = 0; i <= index; i++) {
      var step = baselines[i];
      if (step.full) { Object.keys(step.full).forEach(function (id) {
        state[id] = step.full[id]; }); continue; }
      (step.drop || []).forEach(function (id) { delete state[id]; });
      Object.keys(step.put || {}).forEach(function (id) {
        state[id] = step.put[id]; });
    }
    return state;
  }

  function compareBaselines(from, to) {
    var a = snapshotAt(from), b = snapshotAt(to);
    var added = [], removed = [], changed = [];
    Object.keys(b).sort().forEach(function (id) {
      if (!(id in a)) { added.push([id, b[id].title]); return; }
      var fields = [];
      FLAT_FIELDS.forEach(function (f) {
        if (a[id][f] !== b[id][f]) fields.push(f);
      });
      LIST_FIELDS.forEach(function (f) {
        // JSON rather than a joined separator. The separator used to
        // be a unicode escape for NUL, written for JavaScript and
        // eaten by the Python string that carries this script, so the
        // page shipped with real NUL bytes in it — enough for grep,
        // diff and every editor to call it binary.
        if (JSON.stringify(a[id][f]) !== JSON.stringify(b[id][f])) {
          fields.push(f);
        }
      });
      if (fields.length) changed.push([id, b[id].title, fields]);
    });
    Object.keys(a).sort().forEach(function (id) {
      if (!(id in b)) removed.push([id, a[id].title]);
    });
    return { added: added, removed: removed, changed: changed };
  }

  function renderBaselines() {
    var fromSel = document.getElementById('base-from');
    var toSel = document.getElementById('base-to');
    var out = document.getElementById('base-result');
    if (!fromSel || !toSel || !out) { return; }
    var from = parseInt(fromSel.value, 10), to = parseInt(toSel.value, 10);
    var d = compareBaselines(from, to);
    var html = '<p>' + baselines[from].version + ' → ' + baselines[to].version
      + ': ' + d.added.length + ' added, ' + d.removed.length + ' removed, '
      + d.changed.length + ' changed.</p>';
    function block(title, rows, render) {
      if (!rows.length) { return ''; }
      return '<h3>' + title + '</h3><ul>'
        + rows.map(render).join('') + '</ul>';
    }
    html += block('Added', d.added, function (r) {
      return '<li><a href="#' + r[0] + '"><code>' + r[0] + '</code></a> '
        + r[1] + '</li>';
    });
    html += block('Removed', d.removed, function (r) {
      return '<li><code>' + r[0] + '</code> ' + r[1] + '</li>';
    });
    html += block('Changed', d.changed, function (r) {
      return '<li><a href="#' + r[0] + '"><code>' + r[0] + '</code></a> '
        + r[1] + ' — ' + r[2].join(', ') + '</li>';
    });
    out.innerHTML = html;
  }

  if (baselines.length > 1) {
    var fromSel = document.getElementById('base-from');
    var toSel = document.getElementById('base-to');
    fromSel.value = String(baselines.length - 2);
    toSel.value = String(baselines.length - 1);
    fromSel.addEventListener('change', renderBaselines);
    toSel.addEventListener('change', renderBaselines);
    renderBaselines();
  }

  var search = document.getElementById('search');
  var chips = Array.prototype.slice.call(document.querySelectorAll('.chip'));
  var shown = document.getElementById('shown');
  var active = {};

  function passes(card) {
    for (var key in active) {
      if (!active[key].size) continue;
      if (!active[key].has(card.dataset[key])) return false;
    }
    var q = search.value.trim().toLowerCase();
    return !q || card.dataset.search.indexOf(q) !== -1;
  }

  function apply() {
    var visible = 0, live = {};
    cards.forEach(function (card) {
      var ok = passes(card);
      card.hidden = !ok;
      if (ok) { visible++; live[card.dataset.id] = true; }
    });
    if (shown) shown.textContent = visible;
    document.querySelectorAll('.graph .node').forEach(function (node) {
      node.classList.toggle('dim', !live[node.dataset.id]);
    });
  }

  chips.forEach(function (chip) {
    var key = chip.dataset.key;
    active[key] = active[key] || new Set();
    chip.addEventListener('click', function () {
      var on = chip.getAttribute('aria-pressed') === 'true';
      chip.setAttribute('aria-pressed', on ? 'false' : 'true');
      if (on) active[key].delete(chip.dataset.value);
      else active[key].add(chip.dataset.value);
      apply();
    });
    chip.addEventListener('keydown', function (event) {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        chip.click();
      }
    });
  });

  // Leaving a kind of link out of the drawing. The class goes on the
  // svg, not on the edges: folding an area rebuilds them.
  Array.prototype.forEach.call(
    document.querySelectorAll('.key.kind'), function (key) {
      var kind = key.dataset.kind;
      key.addEventListener('click', function () {
        var drawn = key.getAttribute('aria-pressed') === 'true';
        key.setAttribute('aria-pressed', drawn ? 'false' : 'true');
        if (gsvg) gsvg.classList.toggle('hide-' + kind, drawn);
      });
      key.addEventListener('keydown', function (event) {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          key.click();
        }
      });
    });

  search.addEventListener('input', apply);

  var tabs = Array.prototype.slice.call(document.querySelectorAll('nav button'));
  function showView(name) {
    tabs.forEach(function (tab) {
      var on = tab.dataset.view === name;
      tab.setAttribute('aria-selected', on ? 'true' : 'false');
      document.getElementById(tab.dataset.view).hidden = !on;
    });
  }
  tabs.forEach(function (tab) {
    tab.addEventListener('click', function () { showView(tab.dataset.view); });
  });

  // Following links in both directions is the point of this page, and a
  // link is followed from wherever the reader happens to be. The card it
  // names lives in one view and may be hidden by a filter; both are this
  // function's business, whichever view the reader came from.
  function jump() {
    var id = location.hash.replace(/^#/, '');
    if (!id) return;
    var card = cards.filter(function (c) { return c.dataset.id === id; })[0];
    if (!card) return;
    showView('view-reqs');
    if (card.hidden) {
      search.value = '';
      chips.forEach(function (chip) {
        chip.setAttribute('aria-pressed', 'false');
        active[chip.dataset.key].delete(chip.dataset.value);
      });
      apply();
    }
    if (card.scrollIntoView) card.scrollIntoView();
  }
  window.addEventListener('hashchange', jump);

  apply();
  jump();
})();
"""


def esc(text):
    return html.escape(text or "", quote=True)


def render_inline(text, modal_pattern):
    """A deliberately partial Markdown renderer: escaping, the modal
    verb, **strong**, *em*, `code`, paragraphs. A full parser without
    dependencies is not worth its weight here; anything else in a
    statement shows up literally.

    The modal verb is substituted first — srs_check.RE_MODAL matches the
    asterisks along with the word, so after **strong** became <strong>
    it would never match again.
    """
    text = esc(text)
    if modal_pattern is not None:
        text = modal_pattern.sub(
            lambda m: '<strong class="modal">%s</strong>'
                      % m.group(0).strip("*"), text)
    text = "".join(
        part if index % 2 == 0 else "<code>%s</code>" % part
        for index, part in enumerate(text.split("`")))
    text = _pair(text, "**", "strong")
    text = _pair(text, "*", "em")
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    return "".join("<p>%s</p>" % p.replace("\n", " ") for p in paragraphs)


def _pair(text, marker, tag):
    pieces = text.split(marker)
    if len(pieces) < 3:
        return text
    result = []
    for index, piece in enumerate(pieces):
        if index % 2 == 1 and index != len(pieces) - 1:
            result.append("<%s>%s</%s>" % (tag, piece, tag))
        else:
            result.append(piece)
    return "".join(result)


class Links(object):
    # annotation removed on install
    """Paths become links twice over: relative ones so the page works
    from file://, and repository ones when repo_url is configured.

    A page written outside the repository gets absolute file:// URLs
    instead — a relative path out of, say, /tmp is correct only for as
    long as nobody moves the page.
    """

    def __init__(self, model, out_dir):
        self.repo_url = model["repo_url"]
        # One resolved pair for both the decision and the path: mixing
        # resolved and unresolved sides is how a symlinked root produces
        # links that walk out of the repository.
        root, here = os.path.realpath(ROOT), os.path.realpath(out_dir)
        if os.path.relpath(here, root).startswith(".."):
            self.prefix = "file://" + quote(root)
        else:
            self.prefix = os.path.relpath(root, here).replace(os.sep, "/")

    def local(self, path):
        return "%s/%s" % (self.prefix, quote(path))

    def href(self, path, line=None):
        if self.repo_url:
            anchor = "#L%d" % line if line else ""
            return "%s/%s%s" % (self.repo_url, quote(path), anchor)
        return self.local(path)


# annotation removed on install
# The verification letters the page draws, in the words `specs/README.md`
# gives them, and in its order rather than alphabetical. A letter is not a
# word, and this page is the one that reaches a reader who has neither that
# file nor `specs/50-verification.md` to look it up in.
METHODS = (("T", "test"), ("D", "demonstration"),
           ("I", "inspection"), ("A", "analysis"))
METHOD_WORD = dict(METHODS)


def notation_legend():
    # annotation removed on install
    """What every mark on a requirement card stands for."""
    letters = "".join("<b>%s</b> %s, " % (key, word) for key, word in METHODS)
    return ('<p class="notation">Each requirement below carries its status, '
            'and how conformance is checked as a single letter — %s'
            '<b>?</b> where none is declared. Every other badge spells '
            'itself: a status says its own name, and a change badge says '
            'what changed.</p>' % letters)


def render_card(entry, model, known, links, diff_state):
    # annotation removed on install
    classes = ["superseded"] if entry["status"] == "superseded" else []
    badge = ""
    state = diff_state.get(entry["id"])
    if state:
        badge = '<span class="badge %s">%s</span>' % (state, state)
    rows = []
    for field in LINK_FIELDS:
        for target in entry[field]:
            rows.append((field, target, "→"))
    if entry["superseded_by"]:
        rows.append(("superseded_by", entry["superseded_by"], "→"))
    for field, source in model["incoming"].get(entry["id"], []):
        rows.append((INCOMING_LABEL.get(field, field), source, "←"))

    link_html = []
    for label, other, arrow in rows:
        target = known.get(other)
        status = target["status"] if target else "unknown"
        link_html.append(
            '<span class="rel">%s</span><span>%s</span>'
            '<span><a href="#%s">%s</a> <span class="rel">(%s)</span></span>'
            % (esc(label), arrow, esc(other), esc(other), esc(status)))
    for field in ("code", "tests"):
        for path in entry[field]:
            link_html.append(
                '<span class="rel">%s</span><span></span>'
                '<span><a href="%s"><code>%s</code></a></span>'
                % (field, esc(links.href(path)), esc(path)))
    # annotation removed on install
    # An exemption is a claim about this requirement, so it is shown beside
    # it: an excuse nobody can see is an excuse nobody revisits (ADR-0008).
    for name in entry.get("exempt", []):
        link_html.append(
            '<span class="rel">exempt</span><span></span>'
            '<span><code>%s</code></span>' % esc(name))

    parts = ['<article id="%s" data-id="%s" data-status="%s" data-type="%s" '
             'data-area="%s" data-file="%s" data-search="%s"%s>'
             % (esc(entry["id"]), esc(entry["id"]), esc(entry["status"]),
                esc(entry["type"]), esc(entry["area"]),
                esc(os.path.basename(entry["path"])),
                esc(" ".join([entry["id"], entry["title"], entry["statement"],
                              entry["rationale"]]).lower()),
                ' class="%s"' % " ".join(classes) if classes else "")]
    parts.append('<h3><span class="id">%s</span> — %s'
                 '<span class="badge st-%s">%s</span>'
                 '<span class="badge" title="%s">%s</span>%s</h3>'
                 % (esc(entry["id"]), esc(entry["title"]),
                    esc(entry["status"] or "unknown"),
                    esc(entry["status"] or "unknown"),
                    esc(METHOD_WORD.get(entry["verification"],
                                        "no method declared")),
                    esc(entry["verification"] or "?"), badge))
    parts.append('<div class="where"><a href="%s">%s:%d</a></div>'
                 % (esc(links.href(entry["path"], entry["line"])),
                    esc(entry["path"]), entry["line"]))
    parts.append('<div class="statement">%s</div>'
                 % render_inline(entry["statement"], srs_check.RE_MODAL))
    if entry["rationale"]:
        parts.append('<div class="rationale">%s</div>'
                     % render_inline(entry["rationale"], None))
    if link_html:
        parts.append('<div class="links">%s</div>' % "".join(link_html))
    parts.append("</article>")
    return "".join(parts)


def render_chips(key, values, counts):
    chips = []
    for value in values:
        if not counts.get(value):
            continue
        chips.append('<span class="chip" role="button" tabindex="0" '
                     'aria-pressed="false" data-key="%s" data-value="%s">%s '
                     '<span class="n">%d</span></span>'
                     % (key, esc(value), esc(value), counts[value]))
    return "".join(chips)


def render_dashboard(model, links):
    # annotation removed on install
    known = by_id(model)
    counts = {}
    for entry in model["requirements"]:
        counts[entry["status"]] = counts.get(entry["status"], 0) + 1
    rows = "".join("<tr><td><span class=\"badge st-%s\">%s</span></td>"
                   "<td>%d</td></tr>" % (esc(status), esc(status),
                                         counts.get(status, 0))
                   for status in STATUSES)

    def listing(entries, note):
        if not entries:
            return "<p>None.</p>"
        items = "".join('<li><a href="#%s">%s</a> %s</li>'
                        % (esc(e["id"]), esc(e["id"]), esc(e["title"]))
                        for e in entries)
        return "<p>%s</p><ul>%s</ul>" % (esc(note), items)

    untested = [e for e in model["requirements"]
                if e["status"] in ("implemented", "partial") and not e["tests"]]
    ahead = [e for e in model["requirements"]
             if e["status"] == "draft" and e["code"]]
    resting, seen_resting = [], set()
    for entry in model["requirements"]:
        if entry["status"] not in ("implemented", "partial"):
            continue
        for field in ("derives_from", "depends_on", "refines"):
            for target in entry[field]:
                other = known.get(target)
                if (other and other["status"] == "draft"
                        and entry["id"] not in seen_resting):
                    seen_resting.add(entry["id"])
                    resting.append(entry)
    orphans = "".join('<li><a href="%s"><code>%s</code></a></li>'
                      % (esc(links.href(path)), esc(path))
                      for path in model["orphan_code"])

    # annotation removed on install
    # Requirement identifiers go out as `href="#<id>"` so that following
    # one from here reaches its card like every other view. `left` rather
    # than `outlived`: the name belongs to the function that
    # computes this, and a local shadowing it here is how somebody later
    # calls the dict.
    left = model["outlived"]
    parts = []
    for item in left["links"]:
        parts.append('<li><a href="#%s">%s</a> %s — <code>%s</code> '
                     '<a href="#%s">%s</a></li>'
                     % (esc(item["id"]), esc(item["id"]), esc(item["title"]),
                        esc(item["field"]), esc(item["target"]),
                        esc(item["target"])))
    for path in left["files"]:
        parts.append('<li><a href="%s"><code>%s</code></a> — left by a '
                     'cancelled requirement, claimed by nothing live</li>'
                     % (esc(links.href(path)), esc(path)))
    for item in left["annotations"]:
        parts.append('<li><a href="%s"><code>%s</code></a> — annotated '
                     '<a href="#%s">%s</a></li>'
                     % (esc(links.href(item["path"])), esc(item["path"]),
                        esc(item["target"]), esc(item["target"])))
    outlived_html = ("<p>Cancelling is the one edit whose consequences "
                     "outlive it.</p><ul>%s</ul>" % "".join(parts)
                     if parts else "<p>None.</p>")

    return ("<h2>Status</h2><table><tr><th>Status</th><th>Requirements</th>"
            "</tr>%s</table>"
            "<h2>Realized without listed tests</h2>%s"
            "<h2>Draft with code — implementation ahead of approval</h2>%s"
            "<h2>Realized but resting on a draft</h2>%s"
            "<h2>Still pointing at a cancelled requirement</h2>%s"
            "<h2>Code files no requirement references (%d of %d)</h2>"
            "<ul>%s</ul>"
            % (rows,
               listing(untested, "Verified by other means, or not yet set up."),
               listing(ahead, "Code exists before approval (ART-020)."),
               listing(resting, "Approve the parent or revisit the child."),
               outlived_html,
               len(model["orphan_code"]), model["code_total"],
               orphans or "<li>None.</li>"))


def render_diff_section(diff):
    def block(title, entries, sign):
        if not entries:
            return "<h2>%s (0)</h2><p>None.</p>" % title
        items = "".join('<li>%s <a href="#%s">%s</a> %s</li>'
                        % (sign, esc(e["id"]), esc(e["id"]), esc(e["title"]))
                        for e in entries)
        return "<h2>%s (%d)</h2><ul>%s</ul>" % (title, len(entries), items)

    changed = []
    for item in diff["changed"]:
        rows = "".join("<li><code>%s</code>: %s → %s</li>"
                       % (esc(field), esc(_format_value(before)),
                          esc(_format_value(after)))
                       for field, before, after in item["fields"])
        statement = ""
        if item["statement"]:
            statement = "<pre class=\"scroll\">%s</pre>" % esc(
                "\n".join(item["statement"]))
        changed.append('<li><a href="#%s">%s</a> %s<ul>%s</ul>%s</li>'
                       % (esc(item["entry"]["id"]), esc(item["entry"]["id"]),
                          esc(item["entry"]["title"]), rows, statement))
    return ("<h2>Changes since %s</h2>"
            "<p>The working tree against the revision.</p>%s%s"
            "<h2>Changed (%d)</h2>%s"
            % (esc(diff["rev"]),
               block("Added", diff["added"], "+"),
               block("Removed", diff["removed"], "−"),
               len(diff["changed"]),
               ("<ul>%s</ul>" % "".join(changed)) if changed
               else "<p>None.</p>"))


# --------------------------------------------------------------------
# Graph
# --------------------------------------------------------------------

NODE_W, NODE_H, GAP_X, GAP_Y = 118, 28, 18, 22
# Room above the first row for the lane's name, and how far an intra-lane
# edge may swing out. The header is also the control that folds its column
# away, so it is sized as a target a person can hit: at 26 it came to some
# thirteen screen pixels once the drawing was fitted into a panel. The
# stride has to hold the widest bow, or an edge would be drawn across the
# neighbouring column.
HEADER_H, BOW_MAX = 34, 34
# What a collapsed lane shrinks to, and where its members' edges land while
# they are folded away: at the bottom of that block, clear of the lane's
# name rather than through it. The page's script carries the height too —
# it is what does the folding — so the two have to agree.
LANE_FOLD_H = 44
LANE_FOLD_Y = LANE_FOLD_H - NODE_H
LANE_STRIDE = NODE_W + GAP_X + BOW_MAX
# The band is drawn wider than its column, so the first one needs room to
# its left or the canvas clips its edge.
LANE_PAD = 8


def svg_escape(text):
    """SVG is XML: an unescaped & in a title breaks the whole document,
    and the HTML text escaper is not the same thing."""
    return (text.replace("&", "&amp;").replace("<", "&lt;")
                .replace(">", "&gt;").replace('"', "&quot;"))


def _area_of(node):
    """The middle segment of `<TYPE>-<AREA>-<NNN>`. The checker has already
    rejected anything shaped otherwise, but the graph is drawn from a model
    and must not lose a node to a surprise."""
    parts = node.split("-")
    return parts[1] if len(parts) > 2 else ""


def _row_key(node):
    """Within a lane: by number, then by identifier. Sorting by the whole
    string would sort by type first and interleave the numbering — SPEC
    would read 010, 030, 040, 020 because two of them are `IF` and one is
    `CON`."""
    parts = node.split("-")
    try:
        return (int(parts[-1]), node)
    except ValueError:
        return (0, node)


def _bow(y_from, y_to):
    """How far an intra-lane edge swings out to clear the boxes between its
    ends. The page's script carries this expression too — it recomputes an
    edge when an area is collapsed, and an edge that changed shape at that
    moment would read as a different link."""
    return min(BOW_MAX, 14 + int(abs(y_from - y_to) / 5))


def edge_path(ax, ay, bx, by, same_lane):
    """The `d` of one edge, from the child's box to the parent's.

    Within a lane the two boxes share an x, so a straight line would run
    underneath everything between them: the edge leaves the right-hand
    side and bows out. Across lanes it leaves the side facing the other
    lane and runs straight. Both rules live in the page's script as well
    (see `_bow`).
    """
    a_mid, b_mid = ay + NODE_H / 2, by + NODE_H / 2
    if same_lane:
        side = ax + NODE_W
        out = side + _bow(ay, by)
        return ("M %d %d Q %d %d %d %d"
                % (side, a_mid, out, (a_mid + b_mid) / 2, side, b_mid))
    if bx > ax:
        return "M %d %d L %d %d" % (ax + NODE_W, a_mid, bx, b_mid)
    return "M %d %d L %d %d" % (ax, a_mid, bx + NODE_W, b_mid)


def build_graph(model):
    # annotation removed on install
    # annotation removed on install
    """Every link drawn; a lane per area, a row per requirement.

    Position is arithmetic — a lane index from the area, a row index from
    the number — so the drawing comes out identical on every run without
    a heuristic having to be kept stable for it.
    """
    known = by_id(model)
    edges = []
    for entry in model["requirements"]:
        for field in LINK_FIELDS:
            for target in entry[field]:
                if target in known:
                    edges.append((entry["id"], target, field))
    nodes = sorted({rid for edge in edges for rid in edge[:2]}, key=srs_parse.id_key)
    # The identifiers rather than their number: the page has to say what
    # was left out, and a count says how many. Sorted order means the cut
    # falls at one place in the alphabet, so whole families go at once —
    # which is the fact worth carrying out of here.
    dropped = []
    if len(nodes) > GRAPH_NODE_LIMIT:
        dropped = nodes[GRAPH_NODE_LIMIT:]
        nodes = nodes[:GRAPH_NODE_LIMIT]
        keep = set(nodes)
        edges = [e for e in edges if e[0] in keep and e[1] in keep]
    if not nodes:
        return "", []

    area = dict((node, _area_of(node)) for node in nodes)
    present = set(area.values())
    # The configured order first — it is the maintainer's and it is
    # committed — then whatever the configuration does not name, so a node
    # can never fall out of the drawing by being in an unexpected area.
    lanes = ([a for a in model["areas"] if a in present]
             + sorted(present - set(model["areas"])))

    position, members = {}, {}
    for index, lane in enumerate(lanes):
        rows = sorted([n for n in nodes if area[n] == lane], key=_row_key)
        members[lane] = rows
        x = LANE_PAD + index * LANE_STRIDE
        for row, node in enumerate(rows):
            position[node] = (x, HEADER_H + row * (NODE_H + GAP_Y))
    width = max(x for x, _y in position.values()) + NODE_W + BOW_MAX + 2
    height = max(y for _x, y in position.values()) + NODE_H + 2

    parts = ['<div class="stage"><svg id="graph-svg" class="graph" '
             'viewBox="0 0 %d %d" preserveAspectRatio="xMidYMid meet" '
             'data-nw="%d" data-nh="%d" '
             'xmlns="http://www.w3.org/2000/svg">'
             % (width, height, NODE_W, NODE_H)]
    parts.append('<g id="graph-stage">')
    parts.append('<defs><marker id="a" viewBox="0 0 8 8" refX="7" refY="4" '
                 'markerWidth="6" markerHeight="6" orient="auto-start-reverse">'
                 '<path d="M0 0 L8 4 L0 8 z" fill="currentColor"/>'
                 '</marker></defs>')
    # Lanes first so the band sits behind everything; the header is the
    # control that folds the column away.
    for index, lane in enumerate(lanes):
        x = LANE_PAD + index * LANE_STRIDE
        # Two rectangles, not one: the band is the column's backdrop and
        # takes no clicks — catching them meant a click in the gap between
        # two boxes folded the whole area away. The head is the control,
        # and it is the size of the block the column folds into.
        parts.append('<g class="lane" data-area="%s" data-x="%d" data-y="%d" '
                     'data-h="%d">'
                     '<rect class="lane-band" x="%d" y="0" width="%d" '
                     'height="%d" rx="7"/>'
                     '<rect class="lane-head" x="%d" y="0" width="%d" '
                     'height="%d" rx="7"><title>%s</title></rect>'
                     '<text class="lane-name" x="%d" y="%d" '
                     'text-anchor="middle">%s · %d</text></g>'
                     % (svg_escape(lane), x, LANE_FOLD_Y, height,
                        x - 7, NODE_W + 14, height,
                        x - 7, NODE_W + 14, HEADER_H,
                        svg_escape("%s — click to fold this column away"
                                   % lane),
                        x + NODE_W / 2, HEADER_H / 2 + 4,
                        svg_escape(lane), len(members[lane])))
    for child, parent, field in edges:
        if child not in position or parent not in position:
            continue
        cx, cy = position[child]
        px, py = position[parent]
        # The kind is always on the edge: a form that tells one relation
        # from another is the requirement. Nothing marks an edge as
        # running backwards any more — with a lane for an area and a row
        # for a number, no direction claims to be forward.
        parts.append('<path class="edge %s" data-from="%s" data-to="%s" '
                     'd="%s" marker-end="url(#a)"/>'
                     % (field, svg_escape(child), svg_escape(parent),
                        edge_path(cx, cy, px, py,
                                  area[child] == area[parent])))
    for node in nodes:
        x, y = position[node]
        entry = known.get(node, {})
        # x0/y0 is where the node belongs: collapsing an area moves it onto
        # the lane's header and it has to find its way back.
        parts.append('<g class="node st-%s" data-id="%s" data-area="%s" '
                     'data-x="%d" data-y="%d" data-x0="%d" data-y0="%d">'
                     '<title>%s</title>'
                     '<rect x="%d" y="%d" width="%d" height="%d" rx="5"/>'
                     '<text x="%d" y="%d" text-anchor="middle">%s</text></g>'
                     % (svg_escape(entry.get("status", "")), svg_escape(node),
                        svg_escape(area[node]), x, y, x, y,
                        svg_escape("%s — %s (%s)"
                                   % (node, entry.get("title", ""),
                                      entry.get("status", ""))),
                        x, y, NODE_W, NODE_H,
                        x + NODE_W / 2, y + NODE_H / 2 + 4, svg_escape(node)))
    options = "".join('<option value="%s">%s</option>'
                      % (svg_escape(node), svg_escape(node)) for node in nodes)
    # Both legends are lists, so both read down the rail rather than
    # across. The link swatch is a line carrying the very class the edge
    # carries, so the dash pattern cannot drift from the drawing; the
    # status swatch takes its colour from the same st-* class a node does.
    # Colour is not the only channel: every key is named, and a node's
    # tooltip says its status in words.
    # Pressed means drawn: every kind starts on, and a click subtracts
    # it. That is the direction the requirement argues for — a link that
    # is drawn and unwanted is one click away, a link never drawn is
    # invisible.
    link_keys = "".join(
        '<span class="key kind" role="button" tabindex="0" '
        'aria-pressed="true" data-kind="%s">'
        '<svg class="graph swatch" width="26" height="9" '
        'aria-hidden="true"><line class="edge %s" x1="1" y1="4.5" x2="25" '
        'y2="4.5"/></svg>%s</span>' % (esc(field), esc(field), esc(field))
        for field in LINK_FIELDS)
    status_keys = "".join(
        '<span class="key st-%s"><span class="dot"></span>%s</span>'
        % (esc(status), esc(status)) for status in STATUSES)
    parts.append(
        '</g></svg><div id="graph-rail"><div id="graph-controls">'
        '<label>around <select id="graph-root">'
        '<option value="">everything</option>%s</select></label>'
        '<label>within <select id="graph-depth">'
        '<option value="1">1 link</option>'
        '<option value="2" selected>2 links</option>'
        '<option value="3">3 links</option></select></label>'
        '<button id="graph-reset" type="button">reset view</button>'
        '</div><div id="graph-legend">'
        '<p class="legend-title">link</p>%s'
        '<p class="legend-title">status</p>%s'
        '</div></div></div>' % (options, link_keys, status_keys))
    return "".join(parts), dropped


# --------------------------------------------------------------------
# Page
# --------------------------------------------------------------------

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__</title>
<style>__CSS__</style>
</head>
<body>
<header>
  <h1>__TITLE__</h1>
  <div class="counts"><span id="shown">__COUNT__</span> of __COUNT__ \
requirements · __VERSIONS__</div>
  <nav>
    <button data-view="view-reqs" aria-selected="true">Requirements</button>
    <button data-view="view-dash" aria-selected="false">Dashboard</button>
    <button data-view="view-graph" aria-selected="false">Graph</button>
    <button data-view="view-base" aria-selected="false">Baselines</button>
  </nav>
</header>
<div class="layout">
<aside>
  <input id="search" type="search" placeholder="search" autocomplete="off">
  __FILTERS__
  <h2>Documents</h2>
  <ul>__DOCUMENTS__</ul>
</aside>
<main>
  __BANNER__
  <section id="view-reqs">__NOTATION____DIFF____CARDS__</section>
  <section id="view-dash" hidden>__DASHBOARD__</section>
  <section id="view-graph" hidden>__GRAPH__</section>
  <section id="view-base" hidden>__BASELINES__</section>
</main>
</div>
<footer>__FOOTER__</footer>
<script id="baselines-data" type="application/json">__BASEDATA__</script>
<script>__JS__</script>
</body>
</html>
"""


RE_CSS_RULE = re.compile(r"([^{}]+)\{([^{}]*)\}")


def graph_stylesheet():
    # annotation removed on install
    """The rules the drawing needs and the background colour, taken from
    the page's own stylesheet rather than kept as a second copy: every rule
    addressed to `.graph` and the status colours the nodes carry, with the
    light theme's variables resolved into them.

    Light and only light, on an opaque background. An SVG shown as an
    image is not told what theme the page around it uses, and a drawing
    that is legible on one background is worth more than one that guesses.
    """
    # Comments out first: a rule written after one would otherwise carry
    # the comment inside its selector and match nothing.
    rules = RE_CSS_RULE.findall(re.sub(r"/\*.*?\*/", "", CSS, flags=re.S))
    root = next(body for selector, body in rules if selector.strip() == ":root")
    values = dict(re.findall(r"(--[\w-]+):\s*([^;]+);", root))
    # Resolved to literal colours: an SVG rendered as an image is not
    # promised custom properties by every renderer, and a variable it does
    # not resolve is a node drawn in black on black.
    def resolve(body):
        return re.sub(r"var\((--[\w-]+)\)",
                      lambda m: values.get(m.group(1), m.group(0)), body)
    kept = []
    for selector, body in rules:
        selector = selector.strip()
        if selector.startswith(".graph") or selector.startswith(".st-"):
            kept.append("%s {%s}" % (selector, resolve(body.strip())))
    return "\n".join(kept), values["--bg"]


def neighbourhood(model, chosen):
    # annotation removed on install
    """The selection and every requirement one link away from it, in either
    direction — what it names in a link field and what names it. One step,
    because the picture is of the selection's place in the specification,
    and two steps from anything is most of it."""
    known = by_id(model)
    core = set(entry["id"] for entry in chosen)
    wanted = set(core)
    for entry in model["requirements"]:
        targets = set(t for field in LINK_FIELDS for t in entry[field])
        if entry["id"] in core:
            wanted.update(t for t in targets if t in known)
        elif targets & core:
            wanted.add(entry["id"])
    return [entry for entry in model["requirements"] if entry["id"] in wanted]


def graph_image(model):
    # annotation removed on install
    """The graph of `model` as one self-contained SVG document, or "" where
    the selection has no edges to draw. The drawing is the page's — the
    same function, the same arithmetic — lifted out of the stage it sits in
    on the page and given the styles it needs to stand alone."""
    stage, _dropped = build_graph(model)
    if not stage:
        return ""
    start = stage.index("<svg ")
    end = stage.index("</svg>", start) + len("</svg>")
    drawing = stage[start:end]
    # A backdrop the page gives the drawing through CSS and an image has
    # to carry itself; inserted first so that everything draws over it.
    head_end = drawing.index(">") + 1
    stylesheet, background = graph_stylesheet()
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            + drawing[:head_end]
            + "<style>" + stylesheet + "</style>"
            + '<rect width="100%%" height="100%%" fill="%s"/>' % background
            + drawing[head_end:] + "\n")


def baseline_row(version, date=None):
    # annotation removed on install
    """The row for `92-baselines.md`, ready to paste.

    Normally computed from the working tree against the newest existing
    baseline, because the row is written before its own tag exists — that
    order is what keeps the tag from ever pointing at a state the log does
    not describe.

    Where the tag is already there — somebody tagged by hand — the row is
    computed from that revision against the baseline before it, and dated
    from its commit. A row written late then says what it would have said
    on time, instead of describing whatever the working tree holds now.
    """
    earlier = [logged for logged in logged_baselines()
               if version_key(logged) < version_key(version)]
    previous = earlier[-1] if earlier else None
    own = "spec/v%s" % version
    if has_tag(version):
        # Tagged before its row was written. The row then describes the
        # tagged revision, not a working tree that has moved on since.
        model = load_revision(own)
        if not date:
            try:
                date = git(["log", "-1", "--format=%cd", "--date=short",
                            own]).decode("utf-8").strip()
            except (OSError, subprocess.CalledProcessError):
                date = None
    else:
        model = load_current()

    counts = {}
    total = 0
    for entry in model["requirements"]:
        counts[entry["status"]] = counts.get(entry["status"], 0) + 1
        total += 1
    shape = ", ".join("%d `%s`" % (counts[s], s)
                      for s in STATUSES if counts.get(s))

    if previous is None:
        changed = "The first baseline."
    else:
        revision = baseline_revision(previous)
        if not revision:
            raise ViewError("baseline %s is in the log but nothing in git "
                            "history holds it — no tag, and no commit that "
                            "added its row" % previous)
        diff = compute_diff(load_revision(revision), model)
        parts = []
        if diff["added"]:
            parts.append("added %s"
                         % ", ".join(e["id"] for e in diff["added"]))
        if diff["removed"]:
            parts.append("removed %s"
                         % ", ".join(e["id"] for e in diff["removed"]))
        if diff["changed"]:
            parts.append("changed %s"
                         % ", ".join(c["entry"]["id"]
                                     for c in diff["changed"]))
        changed = ("Since %s: %s." % (previous, "; ".join(parts))
                   if parts else
                   "No requirement added, removed or changed since %s."
                   % previous)

    return "| %s | %s | `spec/v%s` | %s %d %s: %s. |" % (
        version, date or datetime.date.today().isoformat(), version,
        changed, total, "requirement" if total == 1 else "requirements",
        shape)


def render_baselines(snapshots, logged=()):
    """The picker and the legend; the comparison itself happens in the
    page, from the snapshots embedded beside it."""
    if not snapshots:
        if logged:
            # The log is a file and reads anywhere; the states it names
            # live in commits, and a shallow checkout has none of them.
            # Saying nothing here would show a page that quietly claims
            # this specification has never been frozen.
            return ("<p><strong>%d baselines are recorded</strong> in "
                    "<code>92-baselines.md</code>, and none of them could be "
                    "read here: comparing them needs the repository's "
                    "history, and this page was rendered without it. Check "
                    "out the full history — <code>fetch-depth: 0</code> on "
                    "GitHub Actions, <code>GIT_DEPTH: 0</code> on GitLab "
                    "CI.</p>" % len(logged))
        return ("<p>No baselines yet. A baseline is a row in "
                "<code>92-baselines.md</code> and the commit that adds it; "
                "see the Baselines section of the standard.</p>")
    missing = len(logged) - len(snapshots)
    short = ("<p class=\"hint\">%d of the %d baselines in the log could not "
             "be read from this checkout's history.</p>"
             % (missing, len(logged)) if missing > 0 else "")
    options = "".join('<option value="%d">%s</option>' % (index, esc(snap["version"]))
                      for index, snap in enumerate(snapshots))
    if len(snapshots) < 2:
        return ("<p>One baseline so far (<strong>%s</strong>) — nothing to "
                "compare it against yet.</p>%s"
                % (esc(snapshots[-1]["version"]), short))
    return (short + '<div class="pickers">'
            '<label>from <select id="base-from">%s</select></label> '
            '<label>to <select id="base-to">%s</select></label>'
            '</div>'
            '<div id="base-result"></div>'
            '<p class="hint">Statements are compared by fingerprint: a '
            'reworded statement shows as a change, its text is not carried '
            'into the page.</p>' % (options, options))


def render_page(model, links, diff=None, baselines=None):
    # annotation removed on install
    # From the log, not from the snapshots: which baselines exist is a
    # question the log answers on its own, and it answers it in a checkout
    # too shallow to hold the states they name.
    logged = logged_baselines()
    entries = model["requirements"]
    known = by_id(model)
    diff_state = {}
    if diff:
        for entry in diff["added"]:
            diff_state[entry["id"]] = "new"
        for item in diff["changed"]:
            diff_state[item["entry"]["id"]] = "changed"

    counts = {"status": {}, "type": {}, "area": {}, "file": {}}
    for entry in entries:
        counts["status"][entry["status"]] = \
            counts["status"].get(entry["status"], 0) + 1
        counts["type"][entry["type"]] = counts["type"].get(entry["type"], 0) + 1
        counts["area"][entry["area"]] = counts["area"].get(entry["area"], 0) + 1
        name = os.path.basename(entry["path"])
        counts["file"][name] = counts["file"].get(name, 0) + 1

    filters = []
    for key, values in (("status", list(STATUSES)),
                        ("type", list(model["types"])),
                        ("area", list(model["areas"])),
                        ("file", sorted(counts["file"]))):
        extra = [v for v in sorted(counts[key]) if v not in values]
        chips = render_chips(key, values + extra, counts[key])
        if chips:
            filters.append("<h2>%s</h2>%s" % (key, chips))

    banner = ""
    if model["problems"]:
        items = "".join("<li>%s</li>" % esc(text)
                        for text in model["problems"][:10])
        banner = ('<div class="banner"><strong>%d problem(s) in the '
                  'specification.</strong> Run <code>tools/srs_check.py</code> '
                  'for the full report.<ul>%s</ul></div>'
                  % (len(model["problems"]), items))

    graph_svg, dropped = build_graph(model)
    if not graph_svg:
        graph = "<p>No links between requirements yet.</p>"
    else:
        note = ""
        if dropped:
            families = {}
            for node in dropped:
                # Everything before the number: the family the reader
                # would go looking for, not the bare type.
                families.setdefault(node.rsplit("-", 1)[0], []).append(node)
            named = ", ".join("%s %d" % (name, len(families[name]))
                              for name in sorted(families))
            note = ("<p>%d node(s) beyond the first %d are not drawn — %s — "
                    "the layout stops being readable past that.</p>"
                    % (len(dropped), GRAPH_NODE_LIMIT, esc(named)))
        graph = ("<p>A column is an area and a row is a requirement’s "
                 "number, so a line crossing columns is a link that "
                 "leaves its area. A column folds away when its name "
                 "is clicked, and the reset button brings them all "
                 "back. Filters dim the nodes; the layout itself is "
                 "fixed. The rail names the kinds of link and the "
                 "statuses.</p>"
                 "%s%s" % (note, graph_svg))

    documents = "".join('<li><a href="%s">%s</a></li>'
                        % (esc(links.href(path)),
                           esc(path[len("specs/"):]))
                        for path in model["documents"])

    # One pass over the template, not one pass per token: a requirement
    # whose text happens to contain __GRAPH__ (this tool's own
    # specification, for one) must not have it substituted after the
    # cards are already in place.
    filled = dict((
            ("__TITLE__", esc(project_title())),
            ("__CSS__", CSS + EDGE_HIDE_CSS),
            ("__JS__", JS),
            ("__COUNT__", str(len(entries))),
            ("__NOTATION__", notation_legend()),
            ("__FILTERS__", "".join(filters)),
            ("__DOCUMENTS__", documents),
            ("__BANNER__", banner),
            ("__DIFF__", render_diff_section(diff) if diff else ""),
            ("__CARDS__", "".join(render_card(e, model, known, links,
                                              diff_state)
                                  for e in entries)),
            ("__DASHBOARD__", render_dashboard(model, links)),
            ("__GRAPH__", graph),
            ("__BASELINES__", render_baselines(baselines or [], logged)),
            ("__BASEDATA__", json.dumps(baselines or [], sort_keys=True,
                                        separators=(",", ":"))
             .replace("</", "<\\/")),
            ("__VERSIONS__", esc(
                ("baseline %s" % logged[-1]) if logged else "no baseline")
             + esc(" · srs_check %s" % model["checker_version"])),
            # No wall-clock stamp on purpose: two runs of the generator
            # must produce byte-identical output.
            ("__FOOTER__", "Generated by tools/srs_view.py from srs_check %s. "
                           "Requirements are rendered; the glossary, the "
                           "constitution and the ADRs are linked, not "
                           "rendered." % esc(model["checker_version"]))))
    pattern = re.compile("|".join(re.escape(token) for token in filled))
    return pattern.sub(lambda match: filled[match.group(0)], PAGE)


def project_title():
    """The project's name, borrowed from the agent guide's heading
    ("# Acme — agent guide"). The specification's own §1 heading would
    only ever say "Introduction", and the directory name is the last
    thing left to fall back on."""
    for name in ("AGENTS.md", "CLAUDE.md"):
        try:
            with open(os.path.join(ROOT, name), "r",
                      encoding="utf-8") as handle:
                for line in handle:
                    if not line.startswith("# "):
                        continue
                    title = line[2:].strip()
                    for dash in (" — ", " – ", " - "):
                        title = title.split(dash)[0]
                    if title and not title.startswith("<"):
                        return "%s — specification" % title
                    break
        except OSError:
            continue
    return "%s — specification" % os.path.basename(ROOT)


def ensure_parent(target):
    out_dir = os.path.dirname(os.path.abspath(target)) or ROOT
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    return out_dir


def write_site(model, target, diff=None):
    # annotation removed on install
    out_dir = ensure_parent(target)
    links = Links(model, out_dir)
    # Only here: build_model runs inside load_revision too, and a model
    # that collected baselines would load a revision to build a model.
    baselines = baseline_snapshots()
    with open(target, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(render_page(model, links, diff, baselines))
    # Only the default directory ignores itself: writing a .gitignore
    # into a path the user named would be presumptuous.
    if os.path.realpath(out_dir) == os.path.realpath(DEFAULT_SITE):
        with open(os.path.join(out_dir, ".gitignore"), "w",
                  encoding="utf-8", newline="\n") as handle:
            handle.write("*\n")
    return os.path.abspath(target)


# --------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------

def parse_args(argv):
    parser = argparse.ArgumentParser(
        prog="srs_view.py",
        description="Read the specification: terminal queries and a "
                    "self-contained HTML page. Never writes to specs/.")
    parser.add_argument("requirement", nargs="?",
                        help="identifier to show in full, e.g. FR-CORE-020")
    parser.add_argument("--list", action="store_true",
                        help="list requirements (with the filters below)")
    parser.add_argument("--status", help="filter by status")
    parser.add_argument("--area", help="filter by area")
    parser.add_argument("--areas", action="store_true",
                        help="the areas this project is divided into, "
                             "with how many requirements each holds")
    parser.add_argument("--vocabulary", action="store_true",
                        help="the words the checker accepts in a requirement's "
                             "block — types, statuses, verification methods, "
                             "fields and which are required — with the areas "
                             "and modal verbs this project declares")
    parser.add_argument("--type", help="filter by type (FR, NFR, IF, …)")
    parser.add_argument("--verification", help="filter by method (T, D, I, A)")
    parser.add_argument("--grep",
                        help="text in id/title/statement/rationale, "
                             "and in the prose beside them")
    parser.add_argument("--code", metavar="PATH[:LINE]",
                        help="requirements describing this file or directory, "
                             "by code/tests fields and by the file's own "
                             "implements:/verifies: annotations; with :LINE, "
                             "only what the annotation covering that line "
                             "marks, and how many the whole file answers for")
    parser.add_argument("--where", action="store_true",
                        help="with a requirement: where it is realized — every "
                             "annotation naming it as path:line, and each file "
                             "its fields name that carries none")
    parser.add_argument("--source", action="store_true",
                        help="with --where: print the region under each "
                             "annotation — a Python function or class whole, "
                             "otherwise up to the next annotation or 60 lines")
    parser.add_argument("--statements", action="store_true",
                        help="with a listing: print each requirement's "
                             "statement beneath its line — what it obliges, "
                             "to choose by; the rationale stays in the "
                             "single-requirement view")
    parser.add_argument("--tree", metavar="ID",
                        help="what derives from this requirement")
    parser.add_argument("--up", action="store_true",
                        help="with --tree: walk to the ancestors instead")
    parser.add_argument("--coverage", action="store_true",
                        help="requirements without tests, code outside the "
                             "specification, drafts with code")
    parser.add_argument("--diff", metavar="REV",
                        help="compare the working tree against a revision, "
                             "or against a baseline by version (1.2.0)")
    parser.add_argument("--html", nargs="?", const=os.path.join(
        DEFAULT_SITE, "index.html"), metavar="PATH",
        help="write a self-contained page (default .srs-site/index.html)")
    parser.add_argument("--open", action="store_true",
                        help="open the rendered page in a browser; implies "
                             "--html when no path is given")
    parser.add_argument("--baseline", metavar="X.Y.Z",
                        help="print the row for specs/92-baselines.md, "
                             "computed against the previous baseline")
    parser.add_argument("--date", metavar="YYYY-MM-DD",
                        help="the date for --baseline; today by default")
    parser.add_argument("--svg", metavar="PATH",
                        help="write the graph of the selected requirements as a "
                             "self-contained SVG image; the filters narrow it")
    parser.add_argument("--around", action="store_true",
                        help="with --svg: widen the selection to every requirement "
                             "it links to or that links to it, one step")
    parser.add_argument("--json", nargs="?", const="-", metavar="PATH",
                        help="write the model as JSON (default stdout); with "
                             "--diff it carries the comparison too")
    parser.add_argument("--cite", nargs="+", metavar="ID",
                        help="print each requirement or decision (ADR-NNNN) as a "
                             "citation ready to paste: identifier, title, file "
                             "and status")
    parser.add_argument("--repo-url", dest="repo_url", metavar="URL",
                        help="blob-URL prefix for links to code, overriding "
                             "repo_url in specs/srs-config.json; in CI the "
                             "revision is usually known, e.g. "
                             "$CI_PROJECT_URL/-/blob/$CI_COMMIT_SHA")
    # annotation removed on install
    # One requirement at a time is what the card shows, and two identifiers
    # on the line are the commonest way of asking for more: answered with a
    # sentence rather than the usage block, so that whoever asked — an
    # agent chaining calls, a person at the terminal — knows what to do
    # next without a second attempt.
    args, extra = parser.parse_known_args(argv)
    if extra:
        # annotation removed on install
        stray = [a for a in extra if re.match(r"^[A-Z]+-[A-Z0-9]+-%s$" % srs_parse.NUMBER, a)]
        if args.requirement and stray and len(stray) == len(extra):
            parser.exit(2, "srs_view.py shows one requirement at a time — %s is %d; call it "
                           "once per identifier, or --cite %s for the citations\n"
                        % (" ".join([args.requirement] + stray), 1 + len(stray),
                           " ".join([args.requirement] + stray)))
        parser.error("unrecognized arguments: %s" % " ".join(extra))
    return args


def main(argv=None):
    if hasattr(sys.stdout, "reconfigure"):
        # A specification may be written in any language; a C locale
        # must not turn reading it into a UnicodeEncodeError.
        sys.stdout.reconfigure(errors="replace")
    args = parse_args(argv)
    if args.open and args.html is None:
        args.html = os.path.join(DEFAULT_SITE, "index.html")
    style = Style(sys.stdout)

    if not os.path.isdir(SPECS):
        sys.stderr.write("specs/ directory not found: %s\n" % SPECS)
        return 2

    model = load_current()
    if args.repo_url:
        model["repo_url"] = args.repo_url.rstrip("/")
    if args.cite:
        known = by_id(model)
        # annotation removed on install
        # Decisions are read only when one is asked for: a citation of ten
        # requirements does not open the decision log.
        if any(RE_ADR_ID.match(rid) for rid in args.cite):
            known = dict(known, **decisions())
        missing = [rid for rid in args.cite if rid not in known]
        for rid in args.cite:
            if rid in known:
                sys.stdout.write("%s\n" % citation(known[rid]))
        for rid in missing:
            sys.stderr.write("no %s %s\n"
                             % ("decision" if RE_ADR_ID.match(rid)
                                else "requirement", rid))
        return 1 if missing else 0

    if args.baseline:
        try:
            sys.stdout.write("%s\n" % baseline_row(args.baseline, args.date))
        except ViewError as exc:
            sys.stderr.write("%s\n" % exc)
            return 2
        return 0

    diff = None
    if args.diff:
        # A bare version names a baseline, which may have no tag: the log
        # says which ones exist and git history says where they are.
        revision = args.diff
        if re.match(r"^\d+\.\d+\.\d+$", args.diff) \
                and args.diff in logged_baselines():
            revision = baseline_revision(args.diff) or args.diff
        try:
            diff = compute_diff(load_revision(revision), model)
        except ViewError as exc:
            sys.stderr.write("%s\n" % exc)
            return 2
        diff["rev"] = args.diff

    # A mistyped output path deserves a sentence, not a traceback. Both
    # outputs may be asked for at once; neither silently wins.
    try:
        if args.svg is not None:
            # annotation removed on install
            chosen = select(model, args)
            if args.around:
                chosen = neighbourhood(model, chosen)
            image = graph_image(dict(model, requirements=chosen))
            if not image:
                sys.stderr.write("nothing to draw: %d requirement(s) selected and no "
                                 "link among them\n" % len(chosen))
                return 1
            ensure_parent(args.svg)
            with open(args.svg, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(image)
            out("Graph written: %s (%d requirements)" % (args.svg, len(chosen)))
            return 0
        if args.json is not None:
            payload = dict(model)
            if diff:
                payload["diff"] = diff
            text = json.dumps(payload, ensure_ascii=False, indent=2,
                              sort_keys=True) + "\n"
            if args.json == "-":
                sys.stdout.write(text)
            else:
                ensure_parent(args.json)
                with open(args.json, "w", encoding="utf-8",
                          newline="\n") as handle:
                    handle.write(text)
                out("JSON written: %s" % os.path.abspath(args.json))

        if args.html is not None:
            written = write_site(model, args.html, diff)
            out("Page written: %s" % written)
            if args.open:
                # annotation removed on install
                # Rendering and opening are one act for a reader, and the
                # command that opens differs by platform; the standard
                # library knows which, so the tool carries it once instead
                # of every reader carrying it forever.
                # as_uri rather than "file://" + path: a Windows path
                # concatenated onto the scheme is not a URL, and the
                # standard library already knows the difference.
                webbrowser.open(pathlib.Path(written).as_uri())

        if args.json is not None or args.html is not None:
            return 0
    except OSError as exc:
        sys.stderr.write("cannot write the output: %s\n" % exc)
        return 2

    print_problems(model, style)

    if args.requirement:
        entry = by_id(model).get(args.requirement)
        if entry is None:
            sys.stderr.write("no requirement %s\n" % args.requirement)
            return 1
        if args.where:
            print_where(entry, style, args.source)
            return 0
        print_card(entry, model, style)
        return 0

    if args.tree:
        if not print_tree(model, args.tree, args.up, style):
            sys.stderr.write("no requirement %s\n" % args.tree)
            return 1
        return 0

    if args.coverage:
        print_coverage(model, style)
        return 0

    # annotation removed on install
    # Before the diff branch: --areas --diff would otherwise print a diff
    # and never mention an area.
    if args.areas:
        print_areas(model, style)
        return 0

    if args.vocabulary:
        print_vocabulary(style)
        return 0

    if diff:
        print_diff(diff, style)
        return 0

    # annotation removed on install
    # Its own branch rather than a narrowing of select(): the mode for a
    # path answers from three sources and this one from the annotations
    # alone, and the count beside the answer is the path mode's, so the
    # reader handed one requirement knows it is one of thirty.
    if args.code:
        path, line = split_line_spec(args.code)
        if line is not None:
            print_line_answer(model, path, line, style, args.list,
                              args.statements)
            return 0
        head, sep, tail = args.code.rpartition(":")
        if sep and tail.isdigit() and os.path.isdir(os.path.join(ROOT, head)):
            out(style.d("%s is a directory; a line belongs to a file"
                        % head))
            return 0

    entries = select(model, args)
    if not args.list:
        print_counts(model, style)
        out()
    print_list(entries, style, args.statements)
    print_prose(model, args, style)
    return 0


if __name__ == "__main__":
    sys.exit(main())
