#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.24.0 — the framework release this file came from
# annotation removed on install
# Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License
# annotation removed on install
"""The specification as a model: what it holds, what a query selects, and what changed.

Read through the checker's parser and answered as data — the model the viewer publishes, the
difference against a revision, the baseline row — so that the command and the page project the
same reading and the baseline command needs no second one. Renders nothing.

Standard library only, compatible with Python 3.9.
"""
# file annotation removed on install
import datetime
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import srs_check                                            # noqa: E402
import srs_parse                                            # noqa: E402

ROOT = srs_check.ROOT
SPECS = srs_check.SPECS
LINK_FIELDS = srs_check.LINK_FIELDS
STATUSES = srs_check.STATUSES

# How an incoming link reads from the target's side.
# annotation removed on install
INCOMING_LABEL = {
    "derives_from": "derived by",
    "refines": "refined by",
    "depends_on": "required by",
    "conflicts_with": "conflicted by",
    "superseded_by": "supersedes",
}
# annotation removed on install

# annotation removed on install
# What a text search skips beyond what the page skips: the framework's own standard,
# the three that record rather than state, and the open issues.
PROSE_EXCLUDED = ("README.md", "90-traceability.md", "91-open-issues.md",
                  "92-baselines.md")
# annotation removed on install

# annotation removed on install
# What the map names as prose, used only to say which a project lacks; the search
# itself takes whatever is there.
PROSE_EXPECTED = ("00-glossary.md", "01-introduction.md", "02-overview.md",
                  "50-verification.md", "constitution.md")
# annotation removed on install


# --------------------------------------------------------------------
# Model
# --------------------------------------------------------------------

# annotation removed on install
def read_repo_url():
    """The blob-URL prefix for links to code, copied out of a browser so no per-host URL
    shape is guessed. A viewer-only key the checker never sees."""
    try:
        with open(srs_check.CONFIG, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return ""
    value = data.get("repo_url", "") if isinstance(data, dict) else ""
    return value.rstrip("/") if isinstance(value, str) else ""
# annotation removed on install


def _as_list(value):
    """Metadata shapes are validated by the checker, not here: a field
    that should be a list but is not simply reads as empty."""
    return [str(item) for item in value] if isinstance(value, list) else []


def _as_scalar(value):
    if isinstance(value, list):
        return str(value[0]) if value else ""
    return str(value) if value else ""


# annotation removed on install
def _requirement_dict(req):
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
    # Every field of the block, not only the known ones: the format permits a key it
    # declares neither required nor optional, and the rest pass through as written.
    for key, value in sorted(req.meta.items()):
        if key not in entry:
            entry[key] = value
    return entry
# annotation removed on install


def build_model(requirements, problems, with_code_scan=True):
    """Projects parsed requirements into the one structure the terminal
    renderers, the HTML generator and --json all consume."""
    entries = [_requirement_dict(req) for req in requirements]
    # annotation removed on install
    entries.sort(key=lambda e: (srs_parse.id_key(e["id"]), e["path"], e["line"]))
    # annotation removed on install

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
    # A cancelled requirement's `code` records what it pointed at, not a claim now — the
    # checker's reading, so one file is not described two ways in one run.
    covered = set()
    for entry in entries:
        if entry["status"] in srs_check.CANCELLED:
            continue
        covered.update(entry["code"])
    all_code = srs_check.collect_code_files() if with_code_scan else set()
    # annotation removed on install

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


# annotation removed on install
def outlived(entries, with_code_scan):
    """What still points at a cancelled requirement, in the three places the checker reports
    one line at a time, so whoever decides a withdrawal sees all of it.

    The first kind is fields and statuses, so it is computed for a past revision too.
    """
    dead = dict((e["id"], e) for e in entries
                if e["status"] in srs_check.CANCELLED)
    if not dead:
        # Nothing cancelled, nothing outliving it, and the walk below would read every source
        # file to prove it — on the way to every terminal query.
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
# annotation removed on install


# annotation removed on install
def collect_documents(entries):
    """Every file in specs/ that carries no requirements — the standard, the glossary, the
    introduction, the overview, the verification notes, the generated reports, the
    decisions — derived from what the parse produced rather than listed by hand, since the
    list kept here fell behind the checker's. The archive is out."""
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
    # The decisions after the documents, not mixed in by name: a run of them between the
    # constitution and the glossary is a sidebar nobody finishes.
    result.sort(key=lambda path: ("/adr/" in path, path))
    return result
# annotation removed on install


# annotation removed on install
def collect_prose(entries):
    """What a text search reads, and what the map names and the project does not have,
    filtered from the documents the page offers rather than walked again.

    The page and the search differ deliberately: a link costs nothing when it is the wrong
    document, and a line out of its document is what misleads.
    """
    # Whole paths, not names: an index of decisions is commonly `adr/README.md`, and
    # dropping it by basename would drop it in silence.
    excluded = set(_repo_relative(os.path.join(SPECS, name))
                   for name in PROSE_EXCLUDED)
    present = [path for path in collect_documents(entries)
               if path not in excluded]
    missing = [name for name in PROSE_EXPECTED
               if not os.path.exists(os.path.join(SPECS, name))]
    return present, missing
# annotation removed on install


# annotation removed on install
def grep_prose(needle, paths):
    """Every line of the prose holding the text, as (path, line, text) — by the line, since
    markdown written by hand breaks where the meaning breaks. Tolerant of an odd byte."""
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
# annotation removed on install


def load_current():
    problems = []
    requirements = []
    for full, rel in srs_check.collect_spec_files():
        # An unreadable file is one more problem to report, not a reason to refuse the other
        # four hundred requirements.
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


# annotation removed on install
def decisions():
    """Every decision in specs/adr/ as {id: entry} — id, title, path, status — read from the
    heading and not the file name, since a plan cites the number in the heading. A file
    without that heading is no decision here."""
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
        # A file may open with a front matter before its heading, the status then being one of
        # its keys: skipped to find the heading, read for the status.
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
# annotation removed on install
# --------------------------------------------------------------------
# Selection
# --------------------------------------------------------------------

def _matches_path(candidate, wanted):
    return candidate == wanted or candidate.startswith(wanted + "/")


# annotation removed on install
def requirements_for_path(model, path):
    """Which requirements describe a file: the `code`/`tests` fields plus any annotation the
    file carries. A directory prefix matches everything under it."""
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
        # The annotation grammar is the checker's, read through its function: which lines are
        # exempt must be one answer, not two that agree today.
        found.update(rid for _line, _kw, rid
                     in srs_check.read_annotations(full))
    return found
# annotation removed on install


# annotation removed on install
def split_line_spec(spec):
    """`path:line` into (path, line), or (spec, None) when it is not one.

    A colon is not enough: only a numeric tail behind a head that exists as a file reads
    as a line, so `C:\\src` and a path with a colon keep their shape.
    """
    head, sep, tail = spec.rpartition(":")
    if not sep or not tail.isdigit() or not head:
        return spec, None
    if os.path.exists(spec) or os.path.exists(os.path.join(ROOT, spec)):
        return spec, None
    if os.path.isfile(os.path.join(ROOT, head)) or os.path.isfile(head):
        return head, int(tail)
    return spec, None
# annotation removed on install


def line_path(path):
    """The repository path of the file a `path:line` names — given from the
    repository root or from wherever the command was run."""
    wanted = path.replace(os.sep, "/").strip()
    if not os.path.exists(os.path.join(ROOT, wanted)) and os.path.exists(path):
        wanted = _repo_relative(path) or wanted
    return wanted


# annotation removed on install
def requirements_for_line(path, line):
    """The requirements of the narrowest region holding a line, with that
    region's mark — or, failing any, those the file carries as a whole,
    with no mark — and nothing from the `code`/`tests` fields, which have
    no lines to be asked about.

    The regions are `srs_check.annotation_regions`', the ones `--where
    --source` prints, so a line and the source shown for it never
    disagree. The narrowest, because what is nested belongs to what
    encloses it and a line inside both is what the inner one marks.
    """
    marks, _unmatched = srs_check.annotation_regions(os.path.join(ROOT, line_path(path)))
    holding = [m for m in marks if m["kind"] != "file" and m["first"] <= line <= m["last"]]
    if holding:
        mark = min(holding, key=lambda m: (m["last"] - m["first"], -m["first"]))
        return set(mark["ids"]), mark
    whole = set()
    for mark in marks:
        if mark["kind"] == "file":
            whole.update(mark["ids"])
    return whole, None
# annotation removed on install


# annotation removed on install
def select(model, args):
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
# annotation removed on install
# --------------------------------------------------------------------
# Diff against a baseline revision
# --------------------------------------------------------------------

class ViewError(Exception):
    """Something the user can fix; reported plainly with exit code 2."""


def git(args, cwd=ROOT):
    return subprocess.check_output(["git"] + args, cwd=cwd,
                                   stderr=subprocess.PIPE)


# annotation removed on install
def load_revision(rev):
    """The specification as of `rev`; paths come from git, relative to the git root, which
    is not necessarily this script's ROOT."""
    try:
        top = git(["rev-parse", "--show-toplevel"]).decode("utf-8").strip()
    except (OSError, subprocess.CalledProcessError):
        raise ViewError("git is unavailable or this is not a git "
                        "repository — --diff needs both")
    # realpath on both sides: git reports the physical path, ROOT keeps the symlinks that
    # led here, and a mismatched prefix would walk out of the repository.
    prefix = os.path.relpath(os.path.realpath(ROOT),
                             os.path.realpath(top)).replace(os.sep, "/")
    prefix = "" if prefix == "." else prefix + "/"
    # git runs at the top of the repository: a pathspec resolved against a nested ROOT
    # would report every requirement as new. -z, because a path outside ASCII comes back
    # C-quoted otherwise.
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
# annotation removed on install


BASELINE_LOG = "92-baselines.md"


def version_key(version):
    parts = version.split(".")
    return tuple(int(p) if p.isdigit() else 0 for p in parts[:3])


def versions_in(text):
    """The versions a baseline log names, oldest first; a row typed by hand is as valid as
    one the tooling wrote."""
    seen = []
    for version in re.findall(r"^\|\s*(\d+(?:\.\d+)+)\s*\|", text, re.M):
        if version not in seen:
            seen.append(version)
    return sorted(seen, key=version_key)


# annotation removed on install
def logged_baselines():
    """The versions the baseline log records, oldest first: the log defines a baseline, and
    a `spec/v*` tag is a bookmark somebody may not have made."""
    try:
        with open(os.path.join(SPECS, BASELINE_LOG), "r",
                  encoding="utf-8") as handle:
            return versions_in(handle.read())
    except OSError:
        return []
# annotation removed on install


def has_tag(version):
    try:
        listed = git(["tag", "-l", "spec/v%s" % version])
    except (OSError, subprocess.CalledProcessError, ViewError):
        return False
    return bool(listed.decode("utf-8", "replace").strip())


def introduces(revision, path, version, top):
    """Whether this commit is where that version's row appeared — containing it proves
    nothing, since a shallow checkout's oldest commit contains every row there has ever
    been."""
    try:
        parent = git(["rev-parse", "-q", "--verify", "%s^" % revision],
                     cwd=top).decode("utf-8").strip()
    except (OSError, subprocess.CalledProcessError):
        # No parent: a root commit, or a shallow boundary, where the honest answer is that
        # this cannot be known.
        try:
            shallow = git(["rev-parse", "--is-shallow-repository"],
                          cwd=top).decode("utf-8").strip()
        except (OSError, subprocess.CalledProcessError):
            return False
        if shallow != "false":
            return False
        # A parentless commit brought its whole log in at once, so only the newest version it
        # names describes the tree it left behind.
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
    """The revision a baseline froze: its tag where one was made, else the commit that added
    its row, else nothing. Both halves are needed — rows have been written a release late,
    and a project that never tags still has baselines."""
    if has_tag(version):
        return "spec/v%s" % version
    try:
        top = git(["rev-parse", "--show-toplevel"]).decode("utf-8").strip()
        prefix = os.path.relpath(os.path.realpath(ROOT),
                                 os.path.realpath(top)).replace(os.sep, "/")
        prefix = "" if prefix == "." else prefix + "/"
        path = prefix + "specs/" + BASELINE_LOG
        # One call finds a row written the way the tooling writes it; a miss falls back to the
        # file's history rather than declaring the baseline lost.
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


# annotation removed on install
def baseline_snapshots():
    """[{tag, version, requirements: {id: {fields…}}}], oldest first: a snapshot per baseline
    is what lets the page compare any pair without a clone."""
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
            requirements[entry["id"]] = dict(
                [(field, entry[field]) for field in DIFF_FIELDS]
                + [("statement", fingerprint(entry["statement"]))])
        snapshots.append({"tag": "spec/v%s" % version, "version": version,
                          "requirements": requirements})
    return as_deltas(snapshots)
# annotation removed on install


def as_deltas(snapshots):
    """The first baseline in full, every later one as its change: a snapshot each would cost
    the whole specification per baseline, and the page is meant to be carried around."""
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


# Every field and the title, except `created`: written once, so never a difference.
DIFF_FIELDS = ("status", "verification", "title", "superseded_by",
               "code", "tests", "exempt") + LINK_FIELDS


# annotation removed on install
def statement_words(text):
    """A statement as its words, so where its lines end is not a difference: a break inside a
    paragraph renders as a space, and comparing raw text reported every reflowed statement
    as changed."""
    return " ".join((text or "").split())
# annotation removed on install


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


# annotation removed on install
def baseline_row(version, date=None):
    """The row for `92-baselines.md`, ready to paste.

    Normally the working tree against the newest baseline, since the row is written before
    its tag exists. Where the tag is already there, the row is computed from that revision
    and dated from its commit, so a row written late says what it would have said on time.
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
# annotation removed on install
