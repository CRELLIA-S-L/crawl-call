#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.19.0 — the framework release this file came from
"""Freeze the specification: write the baseline row.

    python3 tools/srs_baseline.py 1.2.0 --dry-run
    python3 tools/srs_baseline.py 1.2.0

It writes the row into `specs/92-baselines.md` — version, date, and what
changed since the previous baseline — and stops. Committing is yours, with
whatever git client the project uses; a `spec/vX.Y.Z` tag is a bookmark you
may add afterwards or never, because the row is what makes the baseline.

Where such a tag was made first, the row describes that revision rather than
the working tree, so writing it late costs nothing in accuracy.

A baseline is not a release. It freezes what the system must do; a release
ships what it does. Neither implies the other, and the same number in both
places means nothing.

Exit codes: 0 written · 2 refused, having changed nothing.
"""

# annotation removed on install
# annotation removed on install

import argparse
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True                              # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import srs_view                                             # noqa: E402

CHECKER = os.path.join(ROOT, "tools", "srs_check.py")
BASELINES = os.path.join(srs_view.SPECS, "92-baselines.md")
MATRIX = os.path.join(srs_view.SPECS, "90-traceability.md")

EMPTY_NOTE = "*No baselines yet.*\n"


def fail(message):
    sys.stderr.write("srs-baseline: %s\n" % message)
    return 2


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def relative(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def main():
    parser = argparse.ArgumentParser(
        description="Write the row that freezes the specification.")
    parser.add_argument("version", help="the baseline, e.g. 1.2.0")
    parser.add_argument("--date", metavar="YYYY-MM-DD",
                        help="baseline date; today, or the tag's own date "
                             "where the tag was made first")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the row and write nothing")
    args = parser.parse_args()

    version = args.version.lstrip("v")
    if not re.match(r"^\d+\.\d+\.\d+$", version):
        return fail("%s is not a version of the form X.Y.Z" % version)

    try:
        baselines = read(BASELINES)
    except OSError as exc:
        return fail("there is no baseline log to write to: %s" % exc)
    if version in srs_view.logged_baselines():
        return fail("%s is already in %s; there is nothing to write"
                    % (version, relative(BASELINES)))

    # The checker also regenerates the matrix, which is why it runs before
    # the row is written: both files then go into the same commit. Its
    # output is captured so the refusal carries the reasons: the verdict
    # goes to stderr and the findings to stdout, and whoever redirects one
    # of the two is otherwise told that something is wrong without being
    # told what.
    probe = subprocess.Popen([sys.executable, CHECKER], cwd=ROOT,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT)
    output = probe.communicate()[0].decode("utf-8", "replace")
    if probe.returncode != 0:
        return fail("the checker does not pass; nothing was written\n%s"
                    % output.rstrip())
    sys.stdout.write(output)

    try:
        row = srs_view.baseline_row(version, args.date)
    except srs_view.ViewError as exc:
        return fail("%s" % exc)
    anchor = re.search(r"^\|---\|---\|---\|---\|$", baselines, re.M)
    if not anchor:
        return fail("%s has no table to add a row to" % relative(BASELINES))
    logged = baselines[:anchor.end()] + "\n" + row + baselines[anchor.end():]
    logged = logged.replace("\n" + EMPTY_NOTE, "\n", 1)

    sys.stdout.write("  %s\n" % row.strip())
    if args.dry_run:
        sys.stdout.write("\nDry run: nothing was written.\n")
        return 0
    write(BASELINES, logged)

    files = [relative(BASELINES)]
    if os.path.exists(MATRIX):
        files.append(relative(MATRIX))
    sys.stdout.write(
        "\nWritten. Commit %s — that commit is the baseline.\n"
        "A tag is optional; where you want one it is `spec/v%s`, on that "
        "same commit.\n" % (" and ".join(files), version))
    return 0


if __name__ == "__main__":
    sys.exit(main())
