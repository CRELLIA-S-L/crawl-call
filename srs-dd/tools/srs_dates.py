#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.24.0 — the framework release this file came from
# annotation removed on install
# Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License
# annotation removed on install
"""Write into each requirement the date its identifier first appeared.

    python3 srs-dd/tools/srs_dates.py             date what is undated
    python3 srs-dd/tools/srs_dates.py --dry-run   say what would be written

The date git already holds, written into the block once so later readings come off
the file. A requirement that carries `created` is left alone, so a second run costs
nothing. The one command that writes requirement blocks, run by a person and never
by a gate, a hook or an installer.

Standard library only, compatible with Python 3.9.
"""

# file annotation removed on install

import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import srs_check                                            # noqa: E402
import srs_parse                                            # noqa: E402

ROOT = srs_check.ROOT
RE_ADDED = re.compile(r"^\+### ([A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9_]*-\d+)\s")   # annotation removed on install
RE_HEADING = srs_check.RE_HEADING
RE_FENCE_OPEN = re.compile(r"^\s*```+\s*yaml\s*$")
RE_FENCE_CLOSE = re.compile(r"^\s*```+\s*$")
RE_ANY_HEADING = srs_parse.RE_ANY_HEADING
RE_CREATED = re.compile(r"^\s*created\s*:")


def first_seen(paths):
    """{identifier: date} from one pass over the history, or a problem: one subprocess and
    one stream, where a revision-by-revision walk costs a `git show` per file per
    revision."""
    def git(*args):
        return subprocess.check_output(
            ["git", "-C", ROOT] + list(args),
            stderr=subprocess.DEVNULL).decode("utf-8", "replace")

    try:
        if git("rev-parse", "--is-shallow-repository").strip() == "true":
            return {}, "the clone is shallow, so the earlier revisions are absent"
        stream = git("log", "--reverse", "--format=%x00%ad", "--date=short",
                     "-p", "--diff-filter=AM", "--", *paths)
    except (OSError, subprocess.CalledProcessError):
        return {}, "this is not a repository, or git could not read it"

    born, date = {}, None
    for line in stream.split("\n"):
        if line.startswith("\x00"):
            date = line[1:].strip()
        else:
            match = RE_ADDED.match(line)
            if match and match.group(1) not in born:
                born[match.group(1)] = date
    return born, None


def date_file(path, born, dry_run):
    """Writes `created` into every undated block; returns what it dated.

    Fenced blocks are stepped over whole at both levels: an example inside a fence is
    documentation, and the checker reads it the same way.
    """
    with open(path, "r", encoding="utf-8") as handle:
        lines = handle.read().split("\n")

    out, dated, index, total = [], [], 0, len(lines)
    while index < total:
        line = lines[index]
        if srs_parse.RE_FENCE.match(line):
            end = srs_parse.skip_fence(lines, index)
            out.extend(lines[index:end])
            index = end
            continue
        out.append(line)
        if not RE_HEADING.match(line):
            index += 1
            continue
        rid = RE_HEADING.match(line).group(1)
        index += 1

        # The metadata block is the first ```yaml fence under the heading.
        # Anything else fenced before it is somebody's example.
        seen_created = False
        while index < total:
            line = lines[index]
            if RE_ANY_HEADING.match(line):
                break                       # no block; nothing to date
            if RE_FENCE_OPEN.match(line):
                out.append(line)
                index += 1
                while index < total:
                    line = lines[index]
                    if RE_CREATED.match(line):
                        seen_created = True
                    if RE_FENCE_CLOSE.match(line):
                        if not seen_created and rid in born:
                            out.append("created: %s" % born[rid])
                            dated.append((rid, born[rid]))
                        out.append(line)
                        index += 1
                        break
                    out.append(line)
                    index += 1
                break
            if srs_parse.RE_FENCE.match(line):
                end = srs_parse.skip_fence(lines, index)
                out.extend(lines[index:end])
                index = end
                continue
            out.append(line)
            index += 1

    if dated and not dry_run:
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("\n".join(out))
    return dated


def main():
    flags = set(sys.argv[1:])
    unknown = sorted(flags - {"--dry-run"})
    if unknown:
        sys.stderr.write("unknown flag(s): %s\nusage: srs_dates.py "
                         "[--dry-run]\n" % " ".join(unknown))
        return 2
    files = srs_check.collect_spec_files()
    if not files:
        sys.stderr.write("no specification files under specs/.\n")
        return 2

    paths = [rel for _full, rel in files]
    born, problem = first_seen(paths)
    if problem:
        sys.stderr.write(
            "the history could not be read (%s), and a date invented from "
            "today would be wrong in the direction that makes every "
            "requirement look new. Nothing was written.\n" % problem)
        return 2

    dated = []
    for full, rel in files:
        for rid, date in date_file(full, born, "--dry-run" in flags):
            dated.append((rel, rid, date))
            sys.stdout.write("%s — %s created %s\n" % (rel, rid, date))

    undated = [rid for _full, rel in files
               for rid in [r.id for r in srs_check.parse_file(_full, rel, [])]
               if rid not in born]
    # annotation removed on install
    if undated:
        sys.stdout.write(
            "\nNot in the history and therefore not dated: %s. A requirement "
            "that has never been committed has no first appearance to "
            "read.\n" % ", ".join(sorted(set(undated), key=srs_parse.id_key)))
    # annotation removed on install

    verb = "would be dated" if "--dry-run" in flags else "dated"
    sys.stdout.write("\n%d requirement(s) %s. (srs_dates %s)\n"
                     % (len(dated), verb, srs_check.__version__))
    return 0


if __name__ == "__main__":
    sys.exit(main())
