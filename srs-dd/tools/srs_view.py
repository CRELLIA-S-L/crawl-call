#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.24.0 — the framework release this file came from
# annotation removed on install
# Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License
# annotation removed on install
"""Specification viewer: terminal queries and a self-contained HTML site.

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
    srs_view.py --html --link arch.html,grounds.html   with the pages beside it
    srs_view.py --json [PATH]      the model as JSON, for your own scripts

Read-only by construction: it never rewrites the matrix and never gates. A broken
specification is still worth reading, so parse errors come back as a banner.
Standard library only, compatible with Python 3.9.
"""

# file annotation removed on install

import sys

# An import writes __pycache__ inside the target repository. This line must stay
# above the srs_check import.
sys.dont_write_bytecode = True

import argparse                                            # noqa: E402
import json                                                # noqa: E402
import os                                                  # noqa: E402
import pathlib                                             # noqa: E402
import re                                                  # noqa: E402
import webbrowser                                          # noqa: E402

import srs_check                                           # noqa: E402
import srs_parse                                           # noqa: E402

if not hasattr(srs_check, "parse_text"):
    sys.stderr.write("srs-dd/tools/srs_check.py predates this viewer — refresh "
                     "the tooling (re-run tools/srs_init.py from a "
                     "framework clone).\n")
    sys.exit(2)

ROOT = srs_check.ROOT
SPECS = srs_check.SPECS
DEFAULT_SITE = os.path.join(ROOT, ".srs-site")

LINK_FIELDS = srs_check.LINK_FIELDS
STATUSES = srs_check.STATUSES

# The specification's model, read once and projected twice: this command and the
# page it writes take the same reading, and nothing here parses specs/ itself.
try:
    from srs_view_model import (                            # noqa: E402
        INCOMING_LABEL, RE_ADR_ID, ViewError, _format_value, _repo_relative, baseline_revision,
        baseline_row, baseline_snapshots, by_id, collect_prose, compute_diff, decisions,
        grep_prose, line_path, load_current, load_revision, logged_baselines,
        requirements_for_line, requirements_for_path, select, split_line_spec,
    )
except ImportError:
    sys.stderr.write("srs-dd/tools/srs_view_model.py is not beside this file; the viewer "
                     "reads the specification through it\n")
    sys.exit(2)


def page_module():
    """The renderer, imported where it is needed: a terminal answer is owed nothing by the
    page, and only --html and --svg are stopped by its absence."""
    try:
        import srs_view_page
    except ImportError:
        sys.stderr.write("srs-dd/tools/srs_view_page.py is not beside this file; the page "
                         "and the graph are rendered there\n")
        raise SystemExit(2)
    return srs_view_page

# annotation removed on install
# Past this the answer stops being read, and what is dropped is stated
# rather than silently cut — the same reading the page gives its graph.
PROSE_HIT_LIMIT = 40
# annotation removed on install


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
                "srs-dd/tools/srs_check.py for the full report:"
                % len(model["problems"])))
    for text in model["problems"][:10]:
        out("  %s" % text)
    if len(model["problems"]) > 10:
        out("  … %d more" % (len(model["problems"]) - 10))
    out()


# annotation removed on install
def print_counts(model, style):
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
# annotation removed on install


# annotation removed on install
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
# annotation removed on install


# annotation removed on install
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
# annotation removed on install


# annotation removed on install
def prose_path_hint(needle):
    """The text searched for, where it names a path the project carries.

    A path is not in what the search reads — it lives in the `code` and
    `tests` fields — so searching for one answers nothing while the mode
    beside it answers exactly.
    """
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
# annotation removed on install


# annotation removed on install
def print_prose(model, args, style):
    """The prose half of a text search, and what it left out.

    After the requirements rather than before: the cheap answer is read
    first, and a line of prose is as long as its meaning.
    """
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
# annotation removed on install


# annotation removed on install
def print_line(entry, style, statements=False):
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
        # annotation removed on install
# annotation removed on install


def print_list(entries, style, statements=False):
    if not entries:
        out(style.d("nothing matches"))
        return
    for entry in entries:
        print_line(entry, style, statements)


# annotation removed on install
def print_line_answer(model, path, line, style, listing, statements=False):
    """What a line of a file marks, and how many the whole file answers
    for — the second from the path mode, so the two never disagree about
    the file."""
    marked, mark = requirements_for_line(path, line)
    whole = requirements_for_path(model, path)
    if not listing:
        print_counts(model, style)
        out()
    if mark is not None:
        total = len(srs_check.read_lines(os.path.join(ROOT, line_path(path))))
        out(style.d("%s:%d is in the region of the annotation at line %d, %s"
                    % (path, line, mark["lines"][0], region_note(mark, total))))
    elif marked:
        out(style.d("%s:%d is in no region; the file carries these as a whole" % (path, line)))
    index = by_id(model)
    # annotation removed on install
    entries = [index[rid] for rid in sorted(marked, key=srs_parse.id_key) if rid in index]
    unknown = sorted((rid for rid in marked if rid not in index), key=srs_parse.id_key)
    # annotation removed on install
    if not entries and not unknown:
        out(style.d("no annotation covers %s:%d" % (path, line)))
    for entry in entries:
        print_line(entry, style, statements)
    for rid in unknown:
        out("%-15s %s" % (rid, style.d("annotated here, not in the "
                                       "specification")))
    out(style.d("the whole file answers for %d requirement(s) — "
                "--code %s without a line lists them" % (len(whole), path)))
# annotation removed on install


# annotation removed on install
def where_realized(entry):
    """Every annotation naming the requirement, and every file its fields
    name that carries none: [(path, line or None, keyword or None)], the
    annotated ones in file order, the unannotated files after them.

    Two sources, because the specification points at code on two levels:
    the fields name files, the annotations name lines, and a file the
    field claims that no line speaks for is part of the answer — it is
    the one the reader will have to open whole.
    """
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
# annotation removed on install


# annotation removed on install
def mark_at(rel, lineno):
    """The mark whose annotation stands on `lineno` of `rel`, read through the checker's
    grammar so the region printed and the region a line is answered from are one."""
    marks, _unmatched = srs_check.annotation_regions(os.path.join(ROOT, rel))
    for mark in marks:
        if lineno in mark["lines"]:
            return mark
    return None
# annotation removed on install


# annotation removed on install
def region_note(mark, total):
    """What the viewer says of a region: its lines, and where no `srs-end:` ends it, where
    it stopped instead. Never among the file's numbered lines."""
    text = "lines %d–%d" % (mark["first"], mark["last"])
    if mark["how"] == "next":
        text += " — no srs-end: stops at the next annotation, line %d; may be incomplete" % mark["stop"]
    elif mark["how"] == "bound":
        text += " — no srs-end: cut at %d lines; may be incomplete" % srs_check.REGION_BOUND
    elif mark["how"] == "eof":
        text += " — no srs-end: runs to the end of the file"
    elif mark["how"] == "file":
        text = "the whole file, %d lines" % total
        if mark["last"] < total:
            text += "; the first %d shown" % mark["last"]
    return text
# annotation removed on install


# annotation removed on install
def print_where(entry, style, source=False):
    places = where_realized(entry)
    if not places:
        out(style.d("%s names no file and no annotation names it" % entry["id"]))
        return
    # The files no line speaks for come first: under --source the regions run long, and
    # which file must be opened whole is the fact not to miss.
    for rel, lineno, keyword in places:
        if lineno is None:
            out("%s  %s" % (rel, style.d("named in the fields, no annotation for %s" % entry["id"])))
    for rel, lineno, keyword in places:
        if lineno is None:
            continue
        if not source:
            out("%s:%d  %s" % (rel, lineno, keyword))
            continue
        # annotation removed on install
        lines = srs_check.read_lines(os.path.join(ROOT, rel))
        mark = mark_at(rel, lineno)
        if mark is None:
            out("%s:%d  %s" % (rel, lineno, keyword))
            out()
            continue
        out("%s:%d  %s  %s" % (rel, lineno, keyword, style.d(region_note(mark, len(lines)))))
        first, last = mark["first"], mark["last"]
        width = len(str(last))
        for number in range(first, last + 1):
            out("  %s  %s" % (style.d(str(number).rjust(width)), lines[number - 1]))
        out()
        # annotation removed on install
# annotation removed on install


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


# annotation removed on install
def citation(entry):
    """The form a requirement is named in outside the specification — identifier, title, file,
    status — assembled here and nowhere else. No line number: it is wrong after the next
    edit above it."""
    return "%s — %s (%s, %s)" % (entry["id"], entry["title"], entry["path"],
                                 entry["status"] or "?")
# annotation removed on install


# annotation removed on install
def print_card(entry, model, style):
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
# annotation removed on install


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


# annotation removed on install
def print_tree(model, rid, upwards, style):
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
# annotation removed on install


# annotation removed on install
def print_coverage(model, style):
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
    # Counted by requirement, listed by link: which field reaches which draft is what a
    # reader acts on, and counting lines inflated the number an audit starts from.
    out(style.b("Realized but resting on a draft: %d"
                % len({rid for rid, _, _ in resting})))
    for rid, field, target in resting:
        out("  %-14s %s %s" % (rid, field, target))

    out()
    out(style.b("Code files no requirement references: %d of %d"
                % (len(model["orphan_code"]), model["code_total"])))
    for path in model["orphan_code"]:
        out("  %s" % path)
# annotation removed on install


# annotation removed on install
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
# annotation removed on install


def ensure_parent(target):
    out_dir = os.path.dirname(os.path.abspath(target)) or ROOT
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    return out_dir


# annotation removed on install
def write_site(model, target, diff=None, named=()):
    page = page_module()
    out_dir = ensure_parent(target)
    # Only here: build_model runs inside load_revision too, and a model
    # that collected baselines would load a revision to build a model.
    baselines = baseline_snapshots()
    with open(target, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(page.render_site(model, out_dir, diff, baselines, named))
    # Only the default directory ignores itself: writing a .gitignore
    # into a path the user named would be presumptuous.
    if os.path.realpath(out_dir) == os.path.realpath(DEFAULT_SITE):
        with open(os.path.join(out_dir, ".gitignore"), "w",
                  encoding="utf-8", newline="\n") as handle:
            handle.write("*\n")
    return os.path.abspath(target)
# annotation removed on install


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
                        help="with --where: print the region each annotation "
                             "marks — down to its srs-end:, or without one to the "
                             "next annotation or 60 lines, said in its header")
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
    # annotation removed on install
    parser.add_argument("--link", metavar="PAGE,…",
                        help="the published pages beside this one, linked from it: "
                             "arch.html, grounds.html (with --html)")
    # annotation removed on install
    parser.add_argument("--repo-url", dest="repo_url", metavar="URL",
                        help="blob-URL prefix for links to code, overriding "
                             "repo_url in specs/srs-config.json; in CI the "
                             "revision is usually known, e.g. "
                             "$CI_PROJECT_URL/-/blob/$CI_COMMIT_SHA")
    # annotation removed on install
    # Two identifiers on the line are the commonest way of asking for more, answered with a
    # sentence rather than the usage block.
    args, extra = parser.parse_known_args(argv)
    if extra:
        # annotation removed on install
        stray = [a for a in extra
                 if re.match(r"^[A-Z]+-%s-%s$" % (srs_parse.AREA, srs_parse.NUMBER), a)]
        # annotation removed on install
        if args.requirement and stray and len(stray) == len(extra):
            parser.exit(2, "srs_view.py shows one requirement at a time — %s is %d; call it "
                           "once per identifier, or --cite %s for the citations\n"
                        % (" ".join([args.requirement] + stray), 1 + len(stray),
                           " ".join([args.requirement] + stray)))
        parser.error("unrecognized arguments: %s" % " ".join(extra))
    return args
    # annotation removed on install


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
        # annotation removed on install
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
        # annotation removed on install
        try:
            sys.stdout.write("%s\n" % baseline_row(args.baseline, args.date))
        except ViewError as exc:
            sys.stderr.write("%s\n" % exc)
            return 2
        return 0
        # annotation removed on install

    # annotation removed on install
    if args.link and args.html is None:
        sys.stderr.write("--link belongs to --html: there is no page to link from\n")
        return 2
    # annotation removed on install

    diff = None
    if args.diff:
        # A bare version names a baseline, which may have no tag: the log
        # says which ones exist and git history says where they are.
        revision = args.diff
        if re.match(r"^\d+\.\d+\.\d+$", args.diff) \
                and args.diff in logged_baselines():
            revision = baseline_revision(args.diff)
            if revision is None:
                # The row is written and the commit carrying it is not made yet, or the
                # history holding it is not in this checkout. Git's own message for the
                # bare version says none of that.
                sys.stderr.write("baseline %s is in the log and nothing in git history "
                                 "holds it — no tag, and no commit that added its row\n"
                                 % args.diff)
                return 2
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
            page = page_module()
            chosen = select(model, args)
            if args.around:
                chosen = page.neighbourhood(model, chosen)
            image = page.graph_image(dict(model, requirements=chosen))
            if not image:
                sys.stderr.write("nothing to draw: %d requirement(s) selected and no "
                                 "link among them\n" % len(chosen))
                return 1
            ensure_parent(args.svg)
            with open(args.svg, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(image)
            out("Graph written: %s (%d requirements)" % (args.svg, len(chosen)))
            return 0
            # annotation removed on install
        if args.json is not None:
            # annotation removed on install
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
            # annotation removed on install

        if args.html is not None:
            # annotation removed on install
            named = []
            if args.link:
                named, problem = page_module().read_links(args.link)
                if problem:
                    sys.stderr.write("%s\n" % problem)
                    return 2
            # annotation removed on install
            written = write_site(model, args.html, diff, named)
            out("Page written: %s" % written)
            if args.open:
                # annotation removed on install
                # Rendering and opening are one act for a reader, and the standard library knows which
                # command opens; as_uri, since a Windows path concatenated onto a scheme is not a URL.
                webbrowser.open(pathlib.Path(written).as_uri())
                # annotation removed on install

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
    # annotation removed on install

    if args.vocabulary:
        print_vocabulary(style)
        return 0

    if diff:
        print_diff(diff, style)
        return 0

    # annotation removed on install
    # Its own branch: the path mode answers from three sources and this from annotations
    # alone, and the count beside the answer is the path mode's.
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
    # annotation removed on install

    entries = select(model, args)
    if not args.list:
        print_counts(model, style)
        out()
    print_list(entries, style, args.statements)
    print_prose(model, args, style)
    return 0


if __name__ == "__main__":
    sys.exit(main())
